#!/bin/bash
# ===============================================
# Arch Home Server Full Setup Script
# Modes: Headless + On-demand GUI (OpenBox + VNC)
# Author: ChatGPT + Chafiq Elibrahimi (Piratheon xD)
# ===============================================

# -------- Variables --------
USERNAME="piratheon"           
USERPASS="toor"  #Default password, you can change it       
HOSTNAME="TC-Server"
STATIC_IP="192.168.1.10/24"
GATEWAY="192.168.1.1"
DNS="1.1.1.1"
NIC="eth0"                  # Ethernet Interface
VNC_DISPLAY=":1"
VNC_GEOMETRY="1280x800"
VNC_DEPTH="24"

# -------- Update & Base Tools --------
echo "[*] Updating system & installing base tools..."
pacman -Sy --noconfirm grub networkmanager net-tools sudo nano curl wget tigervnc openbox xorg-xinit

# -------- Hostname --------
echo "[*] Setting hostname..."
echo "$HOSTNAME" > /etc/hostname

# -------- User --------
echo "[*] Adding user..."
useradd -m -G wheel -s /bin/bash "$USERNAME"
echo "$USERNAME:$USERPASS" | chpasswd
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# -------- Network Config --------
echo "[*] Configuring NetworkManager with static IP..."
systemctl enable NetworkManager
nmcli con add type ethernet ifname "$NIC" con-name static-ip ipv4.addresses "$STATIC_IP" ipv4.gateway "$GATEWAY" ipv4.dns "$DNS" ipv4.method manual

# -------- SSH --------
echo "[*] Enabling SSH..."
systemctl enable sshd

# -------- Auto-login TTY --------
echo "[*] Enabling auto-login for $USERNAME..."
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USERNAME --noclear %I \$TERM
EOF

# -------- CasaOS --------
echo "[*] Installing CasaOS..."
curl -fsSL https://get.casaos.io | bash

# -------- GUI On-demand Scripts --------
echo "[*] Creating GUI on-demand scripts..."
sudo -u "$USERNAME" bash -c "cat > /home/$USERNAME/start-gui.sh <<EOF
#!/bin/bash
export DISPLAY=$VNC_DISPLAY
openbox &
tigervncserver $VNC_DISPLAY -geometry $VNC_GEOMETRY -depth $VNC_DEPTH
echo 'OpenBox + VNC started on $VNC_DISPLAY'
EOF"

sudo -u "$USERNAME" bash -c "cat > /home/$USERNAME/stop-gui.sh <<EOF
#!/bin/bash
tigervncserver -kill $VNC_DISPLAY
pkill openbox
echo 'OpenBox + VNC stopped'
EOF"

chmod +x /home/$USERNAME/start-gui.sh
chmod +x /home/$USERNAME/stop-gui.sh

# -------- Done --------
echo "[*] Setup complete!"
echo "After moving HDD to ThinkCentre:"
echo "  SSH: ssh $USERNAME@${STATIC_IP%/*}"
echo "  VNC: ${STATIC_IP%/*}:590${VNC_DISPLAY#:}"
echo ""
echo "GUI control commands (from TTY login as $USERNAME):"
echo "  start-gui.sh  -> Launch OpenBox + VNC"
echo "  stop-gui.sh   -> Stop OpenBox + VNC"
