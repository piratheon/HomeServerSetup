ip addr add 192.168.0.12/24 dev enp2s0
ip link set enp2s0 up 
#both as sudo
sudo iptables -A INPUT -i enp2s0 -j ACCEPT   
