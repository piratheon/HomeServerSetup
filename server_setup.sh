#!/bin/bash
#
# Headless Server Configuration Script for Debian 12 (Bookworm)
#
# This script automates the post-installation configuration for a headless
# server. It sets up a static IP address, a VNC server with XFCE,
# enables necessary services, and configures the firewall.
#
# IMPORTANT: This script must be run with root privileges (e.g., using sudo).
#

# --- Script Configuration ---
# The user for whom the VNC service will be configured.
# This user must already exist on the system.
VNC_USER="piratheon"

# The desired screen resolution for the VNC session.
VNC_GEOMETRY="1920x1080"

# --- Sanity Checks ---
# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: This script must be run as root. Please use sudo." >&2
  exit 1
fi

echo "--- Starting Headless Server Configuration ---"

# --- 1. Network Configuration ---
echo "[*] Configuring static IP address..."

# Identify the primary wired Ethernet interface.
# This command looks for devices of type "ether" that are not virtual.
INTERFACE=$(ls -1 /sys/class/net | grep -vE 'lo|docker|veth|br-' | head -n 1)

if [ -z "$INTERFACE" ]; then
    echo "ERROR: Could not automatically determine the wired Ethernet interface." >&2
    echo "Please set it manually in this script." >&2
    exit 1
fi

echo "    - Detected interface: $INTERFACE"

# Create the /etc/network/interfaces file.
# This will overwrite any existing configuration.
cat > /etc/network/interfaces << EOF
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto $INTERFACE
iface $INTERFACE inet static
    address 192.168.10.1
    netmask 255.255.255.0
    # No gateway is configured as this is a direct connection.
EOF

echo "    - Successfully created /etc/network/interfaces."

# --- 2. VNC Server Configuration ---
echo "[*] Configuring TigerVNC systemd service..."

# Create the systemd service file for the VNC server.
# The '@' in the filename allows passing an argument (the display number) to the service.
cat > /etc/systemd/system/vncserver@.service << EOF
[Unit]
Description=Start TigerVNC server at startup
After=syslog.target network.target

[Service]
Type=forking
User=${VNC_USER}
PAMName=login
PIDFile=/home/${VNC_USER}/.vnc/%H:%i.pid
ExecStartPre=-/usr/bin/vncserver -kill :%i > /dev/null 2>&1
ExecStart=/usr/bin/vncserver -depth 24 -geometry ${VNC_GEOMETRY} :%i
ExecStop=/usr/bin/vncserver -kill :%i

[Install]
WantedBy=multi-user.target
EOF

echo "    - Successfully created /etc/systemd/system/vncserver@.service."

# --- 3. Enable Services ---
echo "[*] Enabling systemd services..."

# Reload the systemd daemon to make it aware of the new service file.
systemctl daemon-reload
echo "    - Reloaded systemd daemon."

# Enable the VNC service to start on boot for display :1.
systemctl enable vncserver@1.service
echo "    - Enabled vncserver@1.service."

# Ensure the SSH service is enabled to start on boot.
systemctl enable ssh
echo "    - Enabled ssh.service."

# --- 4. Firewall Configuration ---
echo "[*] Configuring UFW (Uncomplicated Firewall)..."

# Set default policies.
ufw default deny incoming
ufw default allow outgoing
echo "    - Set default policies (deny incoming, allow outgoing)."

# Allow SSH and VNC traffic.
ufw allow 22/tcp comment 'Allow SSH'
ufw allow 5901/tcp comment 'Allow VNC display :1'
echo "    - Allowed incoming traffic on port 22 (SSH) and 5901 (VNC)."

# Enable the firewall non-interactively.
ufw --force enable
echo "    - Firewall is now active."

# --- 5. Completion and User Instructions ---
echo
echo "--- Configuration Complete! ---"
echo
echo "Please review the following manual steps:"
echo
echo "  1. IMPORTANT: If you have not already done so, run the 'vncpasswd' command"
echo "     as the '${VNC_USER}' user to set the VNC server password."
echo "     Example: sudo -u ${VNC_USER} vncpasswd"
echo
echo "  2. Shut down this machine and move the hard drive back to the ThinkCentre server."
echo
echo "  3. Connect the ThinkCentre to your laptop using an Ethernet cable."
echo
echo "  4. On your LAPTOP, manually configure its Ethernet adapter with the following"
echo "     static IP address to connect to the server:"
echo "       - IP Address: 192.168.10.2"
echo "       - Netmask:    255.255.255.0"
echo "       - Gateway:    (leave blank)"
echo
echo "  5. Once booted, you can connect via SSH (ssh ${VNC_USER}@192.168.10.1) or a"
echo "     VNC client (vncviewer 192.168.10.1:1)."
echo
