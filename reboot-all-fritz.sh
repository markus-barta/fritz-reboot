#!/bin/bash

# Help function
show_help() {
    cat << EOF
FritzBox and Repeater Reboot Script
===================================

This script reboots a FritzBox router and up to three FritzBox repeaters using the TR-064 protocol.
It then monitors the devices for 1 minute to ensure they come back online.

Usage:
  ./$(basename "$0") [OPTIONS]

Options:
  -n, --dry-run    Run the script without actually rebooting the devices
  -s, --silent     Run in silent mode (minimal output)
  --log FILENAME   Specify a custom log file (default: ./$(basename "$0" .sh).log)
  -h, --help       Display this help message and exit

Exit codes:
  0   All devices are reachable after reboot
  -1  One device is unreachable after reboot
  -2  Two devices are unreachable after reboot
  -3  Three devices are unreachable after reboot
  -4  All devices are unreachable after reboot

The script requires a .env file located at \$HOME/env/fritz.env with the following content:
  USERNAME=your_username
  PASSWORD=your_password

Device IP addresses are hardcoded in the script:
  Router:    192.168.1.5
  Repeater1: 192.168.1.6
  Repeater2: 192.168.1.7
  Repeater3: 192.168.1.8

Note: Ensure that the TR-064 protocol is enabled on your FritzBox devices.
EOF
}

# Function for logging
log() {
    if [ "$SILENT" = false ]; then
        echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
    fi
}

# Devices to reboot
ROUTER=192.168.1.5
REPEATER1=192.168.1.6
REPEATER2=192.168.1.7
REPEATER3=192.168.1.8

# Script name without path and extension
SCRIPT_NAME=$(basename "$0" .sh)

# Default log file in the current directory
DEFAULT_LOG_FILE="./${SCRIPT_NAME}.log"

# Process parameters
DRY_RUN=false
SILENT=false
LOG_FILE=""

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -n|--dry-run)
        DRY_RUN=true
        shift
        ;;
        -s|--silent)
        SILENT=true
        shift
        ;;
        --log)
        LOG_FILE="$2"
        shift
        shift
        ;;
        -h|--help)
        show_help
        exit 0
        ;;
        *)
        echo "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
done

# If no log file is specified, use the default log file
if [ -z "$LOG_FILE" ]; then
    LOG_FILE=$DEFAULT_LOG_FILE
fi

# Load .env file
env_file="$HOME/env/fritz.env"
if [ -f "$env_file" ]; then
  export $(cat "$env_file" | grep -v '^#' | xargs)
else
  echo ".env file not found: $env_file"
  exit 1
fi

# Function to check device status
check_device_status() {
  DEVICE=$1
  if ping -c 1 -W 2 ${DEVICE} &> /dev/null; then
    echo 1
  else
    echo 0
  fi
}

# Function to reboot a device using TR-064
reboot_device_tr064() {
    local DEVICE=$1
    local USERNAME=$2
    local PASSWORD=$3

    log "Attempting to reboot ${DEVICE} via TR-064..."

    RESPONSE=$(curl -s -k -m 5 \
        --anyauth \
        -u "${USERNAME}:${PASSWORD}" \
        "http://${DEVICE}:49000/upnp/control/deviceconfig" \
        -H 'Content-Type: text/xml; charset="utf-8"' \
        -H 'SoapAction: urn:dslforum-org:service:DeviceConfig:1#Reboot' \
        -d '<?xml version="1.0" encoding="utf-8"?>
        <s:Envelope s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
          <s:Body>
            <u:Reboot xmlns:u="urn:dslforum-org:service:DeviceConfig:1" />
          </s:Body>
        </s:Envelope>')

    if [[ $RESPONSE == *"<u:RebootResponse"* ]]; then
        log "Reboot of ${DEVICE} successfully initiated."
    else
        log "Error rebooting ${DEVICE}. Response: $RESPONSE"
    fi
}


# Reboot all devices
DEVICE_LIST=($REPEATER3 $REPEATER2 $REPEATER1 $ROUTER)

if [ "$DRY_RUN" == true ]; then
    for DEVICE in "${DEVICE_LIST[@]}"; do
        log "Dry Run: Would reboot ${DEVICE}."
    done
else
    # Reboot repeaters
    for REPEATER in "${DEVICE_LIST[@]:0:3}"; do
        reboot_device_tr064 $REPEATER $USERNAME $PASSWORD
    done

    # Wait 1 second
    sleep 1

    # Reboot router
    reboot_device_tr064 $ROUTER $USERNAME $PASSWORD
fi

# Status check loop
log "Starting status check for 1 minute..."
UNREACHABLE_COUNT=0
for i in {1..20}; do  # 20 * 3 seconds = 1 minute
    STATUS_LINE="| "
    UNREACHABLE_COUNT=0
    for DEVICE in "${DEVICE_LIST[@]}"; do
        STATUS=$(check_device_status $DEVICE)
        if [ $STATUS -eq 0 ]; then
            ((UNREACHABLE_COUNT++))
            STATUS_SYMBOL="❌"
        else
            STATUS_SYMBOL="✅"
        fi
        STATUS_LINE+="$DEVICE:$STATUS_SYMBOL | "
    done
    log "$STATUS_LINE"
    sleep 3
done

if [ $UNREACHABLE_COUNT -eq 0 ]; then
    echo "All devices are reachable."
    exit 0
else
    echo "$UNREACHABLE_COUNT device(s) are unreachable."
    exit -$UNREACHABLE_COUNT
fi