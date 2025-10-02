# 🏠 Kekeli-HomeCloud Easy Installer

Transform your computer into a personal cloud server with mobile access - **no technical knowledge required!**

## ✨ What You Get

🌐 **Personal Cloud Storage** - Your own private alternative to Google Drive or iCloud
📱 **Mobile Access** - Access files from Android and iPhone apps
🔒 **Privacy Focused** - Your data stays on your hardware
💾 **External Storage** - Automatically detects and shares USB drives and external disks
🚀 **Step-by-Step Setup** - Interactive guided installation with full user control
🔄 **Smart IP Management** - Automatically detects and handles IP address changes
📁 **Folder Sharing** - Share any folder on your system via Docker mount points
🔧 **Health Monitoring** - Built-in storage testing and status monitoring

## 🎯 Perfect For

- Storing family photos and videos privately
- Sharing files between your devices
- Backing up phone photos automatically
- Accessing your files from anywhere in your home
- Reducing dependency on cloud storage subscriptions

## ⚡ Quick Start

### 1. Download
```bash
git clone https://github.com/your-username/kekeli-homelab.git
cd kekeli-homelab
```

### 2. Install
```bash
./install.sh
```

The installer will guide you through each step:
- 📋 Select each installation phase when ready
- 🔧 Handle sudo permissions as needed
- ⏳ Track progress and review configuration
- 🆘 Get help and troubleshooting guidance

### 3. Enjoy!
Open your web browser to the address shown and start using your personal cloud!

## 📋 System Requirements

- **Operating System**: Linux (Ubuntu, Debian, DeepinOS, or Windows WSL2)
- **Memory**: 2GB RAM minimum (4GB recommended)
- **Storage**: 4GB free disk space minimum (10GB recommended)
- **Network**: Internet connection for initial setup
- **Permissions**: Ability to run commands with sudo

## 🔧 Installation Process

The step-by-step installer guides you through:

1. **✅ System Check** - Validates your system meets requirements
2. **🐳 Docker Setup** - Installs and configures Docker containers
3. **💾 Storage Configuration** - Sets up data storage for your cloud
4. **🌐 Network Configuration** - Configures network access and firewall
5. **☁️ Nextcloud Deployment** - Deploys your personal cloud server
6. **📱 Mobile Setup** - Configures mobile device access

Each step can be run individually with full user control. You can:
- ⏸️ Pause and resume at any time
- 🔍 Review configuration between steps
- 🛠️ Handle sudo permissions when prompted
- 📚 Access help and troubleshooting for each phase

**Total time**: 5-10 minutes on average hardware

## 🌐 Network Setup & Family Access

### Consistent Family Access with Static IP

For reliable family access, your Nextcloud needs a **consistent IP address**. The installer offers two methods:

#### Method 1: Automatic Static IP Configuration (Recommended)

Set your desired IP in the `.env` file and the installer will configure it automatically:

1. **Edit `.env` file** (or create from `.env.example`):
   ```bash
   HOST_IP=192.168.1.98
   ```

2. **Run the installer**:
   ```bash
   ./install.sh
   ```

3. **The installer will**:
   - ✅ Validate your IP is available and valid
   - ✅ Configure NetworkManager/Netplan automatically
   - ✅ Set up DNS and gateway correctly
   - ✅ Ensure persistence across reboots
   - ✅ Your Nextcloud will be at: `http://192.168.1.98:8080`

**Benefits**:
- 🎯 One-time configuration in `.env` file
- 🔄 Automatic setup during installation
- 📱 Consistent URL for mobile apps: `http://192.168.1.98:8080`
- 📌 No need to update bookmarks after reboot
- 👨‍👩‍👧‍👦 Family members use same URL forever

#### Method 2: Manual Router DHCP Reservation

If you prefer router-level configuration:

1. **Run installer** (leave `HOST_IP` empty in `.env`):
   ```bash
   ./install.sh
   ```

2. **Follow the installer's guidance** to:
   - Log into your router admin panel
   - Set up DHCP reservation for your computer's MAC address
   - Restart computer and router

#### ✅ What You Get
- **Automatic Static IP**: Set `HOST_IP` in `.env` for instant configuration
- **Multiple Network Managers**: Supports NetworkManager, Netplan, and legacy interfaces
- **IP Validation**: Checks for conflicts and subnet compatibility
- **Automatic DNS/Gateway**: Detects and configures network settings
- **Persistent Configuration**: Survives system reboots

#### 🔧 Network Configuration Options

**Basic Setup (Recommended)**
```bash
./install.sh
```
The installer automatically detects your network and guides you through making it family-friendly.

**With Static IP (Best for Families)**
```bash
echo "HOST_IP=192.168.1.98" >> .env
./install.sh
```
Automatically configures your system to use the specified static IP.

**Custom Network Interface**
```bash
./scripts/setup-networking.sh --setup --interface=eth0
```
Use a specific network interface (useful for systems with multiple network connections).

**Custom Port**
```bash
./scripts/setup-networking.sh --setup --port=9000
```
Use a different port if 8080 is already in use.

**IP Persistence Setup**
```bash
./scripts/setup-networking.sh --ip-setup
```
Get detailed guidance on setting up static IP or DHCP reservation.

#### 📡 Making Your IP Persistent

**Problem**: By default, most home networks assign IP addresses automatically (DHCP), which can change after reboot.
**Solution**: Set up either DHCP reservation or static IP configuration.

**Method 1: Router DHCP Reservation (Recommended for families)**
1. Access your router admin panel (usually `http://192.168.1.1` or `http://192.168.0.1`)
2. Find "DHCP Settings" or "DHCP Reservations"
3. Add your computer's MAC address with your desired IP
4. Save and restart router and computer

**Method 2: System Static IP**
The installer provides exact commands for your system, such as:
```bash
# Ubuntu/Desktop systems
sudo nmcli con mod "Your-Connection" ipv4.method manual
sudo nmcli con mod "Your-Connection" ipv4.addresses 192.168.1.100/24
```

#### 🏠 Family Network Best Practices

1. **Choose a memorable IP**: Use something like `192.168.1.100` that's easy for family to remember
2. **Bookmark the URL**: Have family bookmark `http://192.168.1.100:8080`
3. **Test after reboot**: Verify the IP stays the same after restarting your computer
4. **Document for family**: Write down the access URL and admin credentials

## 📱 Mobile Device Setup

After installation, your family can access Nextcloud from their mobile devices:

### Android
1. Install "Nextcloud" from Google Play Store
2. Open the app and tap "Log in"
3. Enter server address: `http://YOUR_LOCAL_IP:8080` (shown after installation)
4. Enter your username and password (created during setup)

### iPhone
1. Install "Nextcloud" from App Store
2. Tap "Log in to your Nextcloud"
3. Enter server address: `http://YOUR_LOCAL_IP:8080` (shown after installation)
4. Enter your username and password (created during setup)

### QR Code Setup
The installer can generate QR codes for easy mobile setup - just scan and connect!

## 🔧 Advanced Usage

### Command Line Options
```bash
./install.sh --help          # Show all options
./install.sh --quiet         # Minimal output
./install.sh --debug         # Verbose logging for troubleshooting
./install.sh --skip-confirm  # Skip confirmation prompt

  Interactive Mode:
  ./install.sh                    # Normal installer with enhanced Docker detection
  ./install.sh --check-status     # Direct to Docker status check
  ./scripts/check-docker-status.sh # Standalone interactive status check

  Quick Status Check:
  ./install.sh --status-only      # Quick status and exit
  ./scripts/check-docker-status.sh --status-only


```

### Configuration Files
- **Config Directory**: `~/.kekeli-homecloud/`
- **Installation Log**: `~/.kekeli-homecloud/install.log`
- **Environment Settings**: `~/.kekeli-homecloud/config.env`
- **Security Settings**: `.env` (passwords and sensitive configuration)

### Environment Configuration (.env)

**🔒 Security First**: All passwords and sensitive settings are stored in a `.env` file that is never committed to version control.

**Setup Process**:
1. Copy the example: `cp .env.example .env`
2. Edit your settings: `nano .env`
3. The installer will generate secure passwords automatically

**Important Variables**:
```bash
# Network - Set your family's access IP
PRIMARY_DOMAIN=192.168.1.100
PROTOCOL=http
NEXTCLOUD_HTTP_PORT=8080

# Admin Account - Change the default admin password
ADMIN_USER=admin
ADMIN_PASSWORD=your-secure-password-here

# Automatically generated during installation
POSTGRES_PASSWORD=automatically-generated
REDIS_PASSWORD=automatically-generated
```

**🛡️ Security Notes**:
- The `.env` file contains sensitive passwords
- Never share or commit the `.env` file
- Use `.env.example` as a template for new installations
- All passwords are automatically generated for security

### Managing Your Cloud
- **Web Interface**: `http://YOUR_LOCAL_IP`
- **Add Users**: Use the Nextcloud web admin interface
- **External Storage**: Plug in USB drives - they'll appear automatically
- **Updates**: Re-run `./install.sh` to update components

## 🆘 Troubleshooting

### Installation Issues

**"Permission denied" errors**
```bash
sudo chmod +x install.sh
./install.sh
```

**"Docker not found" after installation**
```bash
sudo systemctl start docker
sudo systemctl enable docker
```

**"Cannot connect" from mobile devices**
- Ensure your device is on the same WiFi network
- Check that your computer's firewall allows connections
- Try accessing the web interface first from your computer

### Common Solutions

**Forgot your Nextcloud password?**
- Access the web interface and click "Forgot password"
- Or recreate your account through the admin interface

**External drives not showing up?**
- Ensure drives are properly formatted (NTFS, ext4, or FAT32)
- Try unplugging and reconnecting the drive
- Check the logs: `cat ~/.kekeli-homecloud/install.log`

**Mobile app can't connect?**
- Double-check the server address includes `http://`
- Ensure your phone is connected to the same WiFi network
- Try accessing the web interface from your phone's browser first

## 📞 Getting Help

1. **Check the logs**: `cat ~/.kekeli-homecloud/install.log`
2. **Run in debug mode**: `./install.sh --debug`
3. **Search issues**: Check our [GitHub Issues](https://github.com/your-username/kekeli-homelab/issues)
4. **Ask for help**: Create a new issue with your log file

## 🔐 Security Notes

- Your cloud runs on your local network only by default
- All data stays on your hardware - nothing uploaded to external servers
- Use strong passwords for your Nextcloud accounts
- Keep your system updated with regular security patches
- Consider setting up HTTPS for enhanced security (advanced users)

## 🛠️ Advanced Features

### IP Address Management

Your Nextcloud automatically detects and adapts to IP address changes in your home network.

**Automatic IP Detection**
```bash
./scripts/setup-networking.sh --check-ip     # Check current IP status
./scripts/setup-networking.sh --update-ip    # Update configuration for new IP
```

**Manual IP Management**
```bash
./install.sh                                 # Choose "Manage IP Configuration"
# Options:
# - Check current IP configuration
# - Detect and update IP changes
# - Configure network settings
```

The system automatically:
- Detects when your IP address changes
- Updates all configuration files
- Recreates containers with new settings
- Updates mobile access URLs
- Maintains uninterrupted access

### Storage & Folder Sharing

Share any folder on your system through Nextcloud using Docker mount points.

**Add Folder Sharing**
```bash
./scripts/setup-storage.sh --add-mount       # Interactive folder sharing setup
./scripts/setup-storage.sh --status          # Detailed storage health check
./scripts/setup-storage.sh --test            # Test storage functionality
```

**Storage Management**
```bash
./install.sh                                 # Choose "Manage Storage & Sharing"
# Options:
# - Add folder mount points
# - Test storage functionality
# - View detailed storage status
# - Setup storage from scratch
```

**Features:**
- Share any directory via bind mounts or symbolic links
- Automatic persistence with /etc/fstab entries
- Container restart integration
- Health monitoring and performance testing

### System Health Monitoring

**Storage Health Checks**
- Real-time disk space monitoring
- Read/write performance testing
- Docker volume access validation
- Mount point status verification

**Network Validation**
- IP address change detection
- Port availability checking
- Container networking status
- Mobile access URL validation

**Usage Examples**
```bash
# Quick storage test
./scripts/setup-storage.sh --test

# Detailed status report
./scripts/setup-storage.sh --status

# Check for IP changes
./scripts/setup-networking.sh --check-ip

# Update after IP change
./scripts/setup-networking.sh --update-ip
```

## 🚀 What's Next?

After your cloud is running:

- **Explore Apps**: Install additional Nextcloud apps for calendar, contacts, notes
- **Set Up Backups**: Configure automatic backups of your important data
- **Add Family Members**: Create accounts for family members
- **Mobile Photo Backup**: Set up automatic photo backup from your phone
- **External Access**: Configure secure remote access (advanced setup)

## 📊 Technical Details

This installer packages proven components from enterprise-grade Nextcloud deployments into a beginner-friendly experience:

- **Database**: PostgreSQL for reliable data storage
- **Web Server**: Nginx proxy for optimized performance
- **Containers**: Docker for isolated, maintainable deployment
- **Storage**: UUID-based mounting for persistent external drives
- **Network**: Automatic local IP detection and firewall configuration

## 🤝 Contributing

Found a bug or want to improve the installer? We welcome contributions!

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is open source and available under the MIT License.

---

**Made with ❤️ for friends and family who deserve their own cloud storage**

*Questions? Problems? Create an issue and we'll help you get your personal cloud running!*