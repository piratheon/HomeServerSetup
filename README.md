# Home Server Setup (Powered by Debian)

This guide provides scripts and instructions to turn an old computer into a headless server (like a ThinkCentre A70z) running Debian 13 XFCE. The server is configured for a direct, private connection to a laptop via an Ethernet cable.

This is perfect for creating a dedicated development or testing environment that doesn't require a monitor or an internet connection after the initial setup.

## Prerequisites

Before you begin, make sure you have the following:

1.  **Two Computers**:
    *   A **Server PC** (the machine to become the headless server).
    *   A **Client Laptop** (your primary machine for connecting to the server).
2.  **Hardware**:
    *   An **Ethernet cable**.
    *   A **USB-to-SATA adapter** (or similar) to connect the server's hard drive to your laptop temporarily.
3.  **Software**:
    *   A fresh installation of **Debian 13 (Trixie) with the XFCE Desktop Environment** on the server's hard drive.
    *   During the Debian installation, you **must** create a user named `piratheon`.

---

## Part 1: Server Configuration

In this part, you will prepare the server's operating system. This is done by connecting its hard drive to your laptop and running a setup script.

### Step 1: Install Required Software on the Server

1.  Before removing the hard drive from the server, boot into the fresh Debian XFCE installation.
2.  Open a terminal and install the necessary software by running:
    ```bash
    sudo apt update
    sudo apt install -y openssh-server tigervnc-standalone-server ufw
    ```
3.  Once the installation is complete, shut down the server.

### Step 2: Run the Headless Setup Script

1.  Physically remove the hard drive from the server and connect it to your laptop using the USB-to-SATA adapter.
2.  On your laptop, open a terminal and excute this:
    ```bash
    curl -sL https://raw.githubusercontent.com/piratheon/HomeServerSetup/refs/heads/main/server_setup.sh -o server_setup.sh && chmod +x server_setup.sh && sudo server_setup.sh
    ```
    > **Note:** This script modifies system files on the server's hard drive, which is why it requires root permissions. It will detect the wired network interface and create configuration files.

### Step 3: Set the VNC Password

This is a critical step. The VNC server needs a password for you to connect.

1.  While the server's drive is still connected to your laptop, you need to run a command as the `piratheon` user.
2.  In your terminal, run the following command. You will be prompted to enter and verify a new password.
    ```bash
    sudo -u piratheon vncpasswd
    ```
    > **Important:** Remember this password! You will need it to connect from your VNC client.

### Step 4: Finalize the Server

1.  Properly eject and disconnect the server's hard drive from your laptop.
2.  Re-install the hard drive into the server computer.
3.  You are now ready to use the server! Do not connect a monitor or keyboard. Just plug in the power and an Ethernet cable.

---

## Part 2: Client Connection

In this part, you will use the client script on your laptop to connect to the server.

### Step 1: Connect the Hardware

1.  Boot up the headless server.
2.  Connect one end of the Ethernet cable to the server and the other end to your laptop.

### Step 2: Use the Connection Helper Script

The `connect-server.sh` script is a menu-driven tool to manage the connection.

1.  On your laptop, open a terminal and get the setup script:
    ```bash
    curl -sL https://raw.githubusercontent.com/piratheon/HomeServerSetup/refs/heads/main/connect-server.sh -o connect-server.sh
    ```
3.  Make the script executable:
    ```bash
    chmod +x connect-server.sh
    ```
4.  Run the script:
    ```bash
    ./connect-server.sh
    ```

### Step 3: Using the Menu

You will see a menu with several options. Here is the recommended workflow:

1.  **Choose `1. Configure Network (Static IP)` first.** This will temporarily assign the IP address `192.168.10.2` to your laptop's Ethernet port, allowing it to communicate with the server. The script will ask for your password (`sudo`) to do this.

2.  **Choose `2. Connect via SSH` or `3. Connect via VNC`**.
    *   **SSH** will give you a command-line terminal on the server.
    *   **VNC** will show you the graphical XFCE desktop from the server. You will need to enter the VNC password you created in Part 1.

3.  **When you are finished**, disconnect the Ethernet cable and choose **`4. Reset Network (DHCP)`**. This will remove the static IP and return your laptop's network settings to normal, allowing you to connect to the internet as usual.

---

## How It Works

This setup creates a simple, private, two-computer network.

*   The `server_setup.sh` script assigns a fixed IP address to the server:
    *   **Server IP:** `192.168.10.1`
*   The `connect-server.sh` script assigns a temporary, compatible IP address to your laptop:
    *   **Laptop IP:** `192.168.10.2`

Because they are on the same `192.168.10.x` subnet, they can communicate directly over the Ethernet cable without needing a router.
