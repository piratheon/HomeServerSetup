#!/bin/bash
#
# Client-side Connection Helper for Headless Server
#
# This script provides a menu-driven interface to manage the network
# configuration on a client machine (laptop) for connecting directly
# to a server, and to launch SSH and VNC connections.
#

# --- Configuration Constants ---
# Edit these variables to match your server's configuration.
SERVER_IP="192.168.10.1"
LAPTOP_IP="192.168.10.2"
SUBNET_MASK="255.255.255.0"
SUBNET_CIDR="24"
SERVER_USER="piratheon"
VNC_PORT="5901"

# --- OS Detection ---
OS_TYPE=""
case "$(uname -s)" in
    Linux*)     OS_TYPE="Linux";;
    Darwin*)    OS_TYPE="macOS";;
    *)          OS_TYPE="Unsupported";;
esac

# --- Helper Functions ---

# Function to get the primary wired interface/service name
get_wired_interface() {
    case "$OS_TYPE" in
        Linux)
            # Find the first available 'ethernet' device reported by NetworkManager
            nmcli -t -f DEVICE,TYPE device status | grep ':ethernet' | cut -d: -f1 | head -n 1
            ;;
        macOS)
            # Find a service associated with a hardware port like Ethernet or USB LAN
            networksetup -listnetworkserviceorder | grep -E '(Hardware Port: (Ethernet|USB.*LAN))' -B 1 | head -n 1 | sed -E 's/^\(.*\)\s*//'
            ;;
    esac
}

# --- Core Functions ---

# 1. Configure the laptop's network with a static IP
configure_static_ip() {
    echo "[*] Configuring network for direct connection..."
    local interface
    interface=$(get_wired_interface)

    if [ -z "$interface" ]; then
        echo "ERROR: Could not find a wired Ethernet interface." >&2
        echo "Please ensure your Ethernet adapter is connected." >&2
        return 1
    fi

    echo "    - Using interface: $interface"

    case "$OS_TYPE" in
        Linux)
            echo "    - Detected Linux. Using nmcli..."
            # Check if the connection profile already exists
            if nmcli connection show "Direct-Server" > /dev/null 2>&1; then
                echo "    - 'Direct-Server' profile already exists. Re-activating..."
            else
                echo "    - Creating 'Direct-Server' profile..."
                sudo nmcli connection add type ethernet con-name "Direct-Server" ifname "$interface" ip4 "$LAPTOP_IP/$SUBNET_CIDR"
                if [ $? -ne 0 ]; then
                    echo "ERROR: Failed to create network connection. Do you have sudo privileges?" >&2
                    return 1
                fi
            fi
            sudo nmcli connection up "Direct-Server"
            ;;
        macOS)
            echo "    - Detected macOS. Using networksetup..."
            sudo networksetup -setmanual "$interface" "$LAPTOP_IP" "$SUBNET_MASK" ""
            if [ $? -ne 0 ]; then
                echo "ERROR: Failed to set manual IP. Do you have sudo privileges?" >&2
                return 1
            fi
            echo "    - Static IP has been set on '$interface'."
            ;;
        *)
            echo "-----------------------------------------------------------------"
            echo "MANUAL INSTRUCTIONS FOR WINDOWS / UNSUPPORTED OS:"
            echo "1. Open 'Control Panel' -> 'Network and Internet' -> 'Network and Sharing Center'."
            echo "2. Click 'Change adapter settings'."
            echo "3. Right-click your 'Ethernet' adapter and select 'Properties'."
            echo "4. Select 'Internet Protocol Version 4 (TCP/IPv4)' and click 'Properties'."
            echo "5. Select 'Use the following IP address:' and enter:"
            echo "   - IP address:     $LAPTOP_IP"
            echo "   - Subnet mask:    $SUBNET_MASK"
            echo "   - Default gateway: (leave blank)"
            echo "6. Click 'OK' to save."
            echo "-----------------------------------------------------------------"
            ;;
    esac
    echo "[+] Network configured."
}

# 2. Connect to the server via SSH
connect_ssh() {
    echo "[*] Launching SSH session to $SERVER_USER@$SERVER_IP..."
    ssh "$SERVER_USER@$SERVER_IP"
}

# 3. Connect to the server via VNC
connect_vnc() {
    echo "[*] Attempting to launch VNC connection..."
    case "$OS_TYPE" in
        macOS)
            echo "    - Using macOS built-in Screen Sharing..."
            open "vnc://$SERVER_IP:$VNC_PORT"
            ;;
        Linux)
            local vnc_client
            vnc_client=$(command -v xtigervncviewer || command -v vncviewer || command -v realvnc-viewer)
            if [ -n "$vnc_client" ]; then
                echo "    - Found VNC client: $vnc_client"
                "$vnc_client" "$SERVER_IP:$VNC_PORT" &
            else
                echo "ERROR: No VNC client found." >&2
                echo "Please install a client like TigerVNC ('xtigervncviewer') or RealVNC Viewer." >&2
                return 1
            fi
            ;;
        *)
            echo "-----------------------------------------------------------------"
            echo "MANUAL INSTRUCTIONS FOR VNC:"
            echo "1. Open your preferred VNC client (e.g., RealVNC Viewer, TigerVNC)."
            echo "2. Create a new connection."
            echo "3. Enter the server address: $SERVER_IP:$VNC_PORT"
            echo "4. Connect and enter the password you set with 'vncpasswd'."
            echo "-----------------------------------------------------------------"
            ;;
    esac
}

# 4. Reset the laptop's network configuration to DHCP
reset_to_dhcp() {
    echo "[*] Resetting network configuration to DHCP..."
    local interface
    interface=$(get_wired_interface)

    if [ -z "$interface" ]; then
        echo "ERROR: Could not find a wired Ethernet interface." >&2
        return 1
    fi

    echo "    - Using interface: $interface"

    case "$OS_TYPE" in
        Linux)
            echo "    - Detected Linux. Using nmcli..."
            if nmcli connection show "Direct-Server" > /dev/null 2>&1; then
                sudo nmcli connection down "Direct-Server"
                sudo nmcli connection delete "Direct-Server"
                echo "    - 'Direct-Server' profile removed."
            else
                echo "    - 'Direct-Server' profile not found, nothing to do."
            fi
            echo "    - Your system should now revert to its default DHCP-enabled connections."
            ;;
        macOS)
            echo "    - Detected macOS. Using networksetup..."
            sudo networksetup -setdhcp "$interface"
            if [ $? -ne 0 ]; then
                echo "ERROR: Failed to set DHCP. Do you have sudo privileges?" >&2
                return 1
            fi
            echo "    - Network interface '$interface' set to DHCP."
            ;;
        *)
            echo "-----------------------------------------------------------------"
            echo "MANUAL INSTRUCTIONS FOR WINDOWS / UNSUPPORTED OS:"
            echo "1. Follow the same steps as for setting a static IP."
            echo "2. In the 'Internet Protocol Version 4 (TCP/IPv4)' properties,"
            echo "   select 'Obtain an IP address automatically'."
            echo "3. Select 'Obtain DNS server address automatically'."
            echo "4. Click 'OK' to save."
            echo "-----------------------------------------------------------------"
            ;;
    esac
    echo "[+] Network reset to DHCP."
}

# --- Main Menu Loop ---
main_menu() {
    echo "--- Headless Server Connection Helper (OS: $OS_TYPE) ---"
    PS3="Please enter your choice: "
    options=(
        "Configure Network (Static IP: $LAPTOP_IP)"
        "Connect via SSH"
        "Connect via VNC"
        "Reset Network (DHCP)"
        "Quit"
    )
    select opt in "${options[@]}"; do
        case "$opt" in
            "${options[0]}")
                configure_static_ip
                break
                ;;
            "${options[1]}")
                connect_ssh
                break
                ;;
            "${options[2]}")
                connect_vnc
                break
                ;;
            "${options[3]}")
                reset_to_dhcp
                break
                ;;
            "${options[4]}")
                exit 0
                ;;
            *) echo "Invalid option $REPLY";;
        esac
    done
}

# Loop indefinitely to show the menu after each action
while true; do
    main_menu
    echo # Add a newline for better readability
    read -p "Press Enter to return to the menu..."
    echo
done
