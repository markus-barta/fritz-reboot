# FritzBox and Repeater Soft Reboot Script

This script reboots a FritzBox router and up to three FritzBox repeaters using the TR-064 protocol. It then monitors the devices for 1 minute to ensure they come back online.

## Usage

`./reboot_fritzbox.sh [OPTIONS]`

## Options

- `-n, --dry-run`: Run the script without actually rebooting the devices
- `-s, --silent`: Run in silent mode (minimal output)
- `--log FILENAME`: Specify a custom log file (default: ./reboot_fritzbox.log)
- `-h, --help`: Display this help message and exit

## Exit Codes

- `0`: All devices are reachable after reboot
- `-1`: One device is unreachable after reboot
- `-2`: Two devices are unreachable after reboot
- `-3`: Three devices are unreachable after reboot
- `-4`: All devices are unreachable after reboot

## Requirements

The script requires a `.env` file located at `$HOME/env/fritz.env` with the following content:
```
USERNAME=your_username
PASSWORD=your_password
```

## Device Configuration

Device IP addresses are hardcoded in the script - change them to your needs.

- Router: 192.168.1.5
- Repeater1: 192.168.1.6
- Repeater2: 192.168.1.7
- Repeater3: 192.168.1.8

## Note

Ensure that the TR-064 protocol is enabled on your FritzBox devices.

## License

[MIT License](LICENSE)

