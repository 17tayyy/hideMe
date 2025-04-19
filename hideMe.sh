#!/bin/bash

green="\e[32m"
red="\e[31m"
blue="\e[34m"
yellow="\e[33m"
reset="\e[0m"

ascii() {
echo -e "${green}"
cat << "EOF"

888      d8b      888          888b     d888          
888      Y8P      888          8888b   d8888          
888               888          88888b.d88888          
88888b.  888  .d88888  .d88b.  888Y88888P888  .d88b.  
888 "88b 888 d88" 888 d8P  Y8b 888 Y888P 888 d8P  Y8b   [by tay]
888  888 888 888  888 88888888 888  Y8P  888 88888888   
888  888 888 Y88b 888 Y8b.     888   "   888 Y8b.     
888  888 888  "Y88888  "Y8888  888       888  "Y8888  
                                                                
EOF
echo -e "${reset}"
}

if [[ $EUID -ne 0 ]]; then
    echo -e "${red}[!] Execute the script as root${reset}"
    exit 1
fi

connectVpn() {
    clear
    ascii
    echo -e "${yellow}[*] Checking if OpenVPN is installed...${reset}"
    sleep 1

    if ! command -v openvpn &> /dev/null; then
        echo -e "${yellow}[!] OpenVPN isn't installed. Do you want to install it? (s/n)${reset}"
        read -p "> " instalar
        if [[ $instalar == "s" ]]; then
            apt update --fix-missing && apt install openvpn -y || {
                echo -e "${red}[!] Error while trying to install OpenVPN${reset}"
                exit 1
            }
        else
            echo -e "${red}[-] Exiting...${reset}"
            exit 1
        fi
    else
        echo -e "${green}[+] OpenVPN is installed${reset}"
        sleep 1
    fi

    if pgrep -x openvpn &>/dev/null; then
        echo -e "${yellow}[!] It seems OpenVPN is already running. Do you want to kill it and reconnect? (s/n)${reset}"
        read -p "> " killvpn
        if [[ $killvpn == "s" ]]; then
            sudo killall openvpn
            sleep 1
        else
            echo -e "${red}[-] Skipping VPN connection...${reset}"
            return
        fi
    fi

    echo -e "${blue}[~] Searching for .ovpn files...${reset}"
    ovpn_files=( *.ovpn )

    if [[ ${#ovpn_files[@]} -eq 0 ]]; then
        echo -e "${red}[!] No .ovpn files found in the current directory${reset}"
        return
    fi

    if [[ ! -f creds.txt ]]; then
        echo -e "${red}[!] creds.txt not found. It must contain your ProtonVPN username and password.${reset}"
        return
    fi

    selected_ovpn=${ovpn_files[RANDOM % ${#ovpn_files[@]}]}
    echo -e "${green}[+] Connecting to VPN with ${selected_ovpn}...${reset}"
    
    sudo openvpn --config "$selected_ovpn" --auth-user-pass creds.txt --daemon
    sleep 3

    if pgrep -x openvpn &>/dev/null; then
        echo -e "${green}[✓] VPN connection initiated successfully (running in background)${reset}"
    else
        echo -e "${red}[✗] Failed to start OpenVPN. Check your config or creds.txt${reset}"
    fi
}

verifyTor() {
    clear
    ascii
    echo -e "${yellow}[*] Checking if tor is installed...${reset}"
    sleep 1
    if ! command -v tor &> /dev/null; then
        echo -e "${yellow}[!] Tor isn't installed . ¿Do you wan't to install it? (s/n)${reset}"
        read -p "> " instalar
        if [[ $instalar == "s" ]]; then
            apt update --fix-missing && apt install tor torsocks -y || {
                echo -e "${red}[!] Error while trying to install tor${reset}"
                exit 1
            }
        else
            echo -e "${red}[-] Exiting...${reset}"
            exit 1
        fi
    else
        echo -e "${green}[+] Tor is installed${reset}"
        sleep 1
    fi
}

activateTor() {
    clear
    ascii
    verifyTor

    TORRC="/etc/tor/torrc"
    if [ ! -f "$TORRC" ]; then
        echo -e "${yellow}[*] Creating torrc file...${reset}"
        mkdir -p /etc/tor
        touch "$TORRC"
    fi

    grep -q "TransPort 9040" "$TORRC" || cat <<EOF >> "$TORRC"

# Config for transparent proxy
VirtualAddrNetworkIPv4 10.192.0.0/10
AutomapHostsSuffixes .onion,.exit
AutomapHostsOnResolve 1
TransPort 9040
DNSPort 5353
EOF

    systemctl restart tor || {
        echo -e "${red}[!] Tor can't be inizialized${reset}"
        exit 1
    }

    echo -e "${green}[*] Aplying iptables rules...${reset}"

    TOR_UID=$(id -u debian-tor)

    iptables -F
    iptables -t nat -F
    iptables -t mangle -F
    iptables -X

    iptables -t nat -A OUTPUT -m owner --uid-owner $TOR_UID -j RETURN
    iptables -t nat -A OUTPUT -d 127.0.0.1/8 -j RETURN
    iptables -t nat -A OUTPUT -d 192.168.0.0/16 -j RETURN
    iptables -t nat -A OUTPUT -d 10.0.0.0/8 -j RETURN

    iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports 5353
    iptables -t nat -A OUTPUT -p tcp --syn -j REDIRECT --to-ports 9040
    sleep 5
    echo -e "${green}[+] All traffic now goes through Tor${reset}"
}

disableTor() {
    clear
    ascii
    echo -e "${red}[*] Disabling tor and cleaning rules...${reset}"

    iptables -F
    iptables -t nat -F
    iptables -t mangle -F
    iptables -X

    systemctl stop tor &>/dev/null
    systemctl restart networking
    sleep 5
    echo -e "${red}[+] Network restored ${reset}"
}

desconnectVpn() {
    clear
    ascii
    echo -e "${red}[*] Searching for OpenVPN process...${reset}"
    sleep 1

    pid=$(pgrep openvpn)

    if [[ -z "$pid" ]]; then
        echo -e "${yellow}[!] No OpenVPN connection found${reset}"
    else
        kill "$pid"
        sleep 2
        echo -e "${green}[✓] VPN disconnected${reset}"
    fi
}

lookIP() {
    clear
    ascii
    echo -e "${blue}[*] Getting current public IP information...${reset}"
    sleep 2

    response=$(curl -s http://ip-api.com/json)

    ip=$(echo "$response" | jq -r '.query')
    isp=$(echo "$response" | jq -r '.isp')
    country=$(echo "$response" | jq -r '.country')
    region=$(echo "$response" | jq -r '.regionName')
    city=$(echo "$response" | jq -r '.city')
    org=$(echo "$response" | jq -r '.org')

    echo -e "${green}[✓] IP: ${blue}$ip${reset}"
    sleep 0.4
    echo -e "${green}[✓] ISP: ${blue}$isp${reset}"
    sleep 0.4
    echo -e "${green}[✓] Organization: ${blue}$org${reset}"
    sleep 0.4
    echo -e "${green}[✓] Location: ${blue}$city, $region, $country${reset}"
    sleep 1

    echo -e "\n${yellow}[*] Checking Tor status...${reset}"
    sleep 1
    if curl -s https://check.torproject.org | grep -q "Congratulations"; then
        echo -e "${green}[✓] You are using Tor${reset}"
    else
        echo -e "${red}[✗] You are NOT using Tor${reset}"
    fi
}

clear
ascii
while true; do
    echo -e "\n${green}[1] Activate Tor${reset}"
    echo -e "${green}[2] Connect to VPN${reset}"
    echo -e "${green}[3] Deactivate Tor${reset}"
    echo -e "${green}[4] Deactivate VPN${reset}"
    echo -e "${green}[5] Check IP${reset}"
    echo -e "${yellow}[0] Exit${reset}"
    echo ""
    read -p "$(echo -e "${green}[+] Choose an option: ${reset}")" op

    case $op in
        1) activateTor ;;
        2) connectVpn ;;
        3) disableTor ;;
        4) desconnectVpn ;;
        5) lookIP ;;
        0) echo -e "${yellow}[*] Exiting...${reset}"; exit ;;
        *) echo -e "${red}[!] Invalid option${reset}" ;;
    esac
done
