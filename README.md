# hideMe 🛜

**hideMe** is a bash tool designed to route all your system's traffic through the [Tor](https://www.torproject.org/) network and optionally connect to a ProtonVPN server if the proper credentials are available.

## Images

![image](https://github.com/user-attachments/assets/c3f7798a-5737-4143-83c6-6fef26370a45)

## Features

- Route all traffic transparently through Tor using `iptables`.
- Connect to ProtonVPN automatically using `.ovpn` config and a `creds.txt` file.
- Show your current public IP and verify if you're using Tor.
- Cleanly deactivate Tor routing and disconnect from the VPN.
- ASCII art and colorized CLI interface.

## Usage

1. Clone or download the script.
2. Make it executable:
   ```bash
   chmod +x hideMe.sh
   ```
3. Run as root:
   ```bash
   sudo ./hideMe.sh
   ```

## File Structure

To connect to ProtonVPN, the following files are needed in the same directory:

- `creds.txt` with your credentials:
  ```
  your_username
  your_password
  ```

- A ProtonVPN `.ovpn` configuration file.

## Menu Options

```
[1] Activate Tor         → Routes all traffic through Tor
[2] Connect to VPN       → Connects to ProtonVPN with .ovpn + creds.txt
[3] Deactivate Tor       → Resets iptables and stops Tor
[4] Deactivate VPN       → Kills any OpenVPN connection
[5] Check IP             → Shows current public IP and Tor status
[0] Exit                 → Close the program
```

## How It Works

### Tor Routing

When you activate Tor:

- The script modifies `/etc/tor/torrc` with transparent proxy settings.
- Starts the Tor service.
- Applies `iptables` rules to redirect TCP and DNS traffic through Tor.

### VPN Connection

If `openvpn` is installed and valid credentials + config are present, the script:

- Picks a random `.ovpn` file from the directory.
- Connects to ProtonVPN in the background using `openvpn`.

### IP Check

Uses `ip-api.com` to fetch current IP info and checks [check.torproject.org](https://check.torproject.org) to see if you're using Tor.

## Dependencies

- `tor`
- `torsocks`
- `openvpn`
- `jq`
- `curl`

You’ll be prompted to install missing packages.

## Note

- Make sure no firewall or network policy is interfering with Tor or VPN.
- Use responsibly and legally.