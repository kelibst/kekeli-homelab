# 🏠 Kekeli-HomeCloud Easy Installer

Transform your computer into a personal cloud server with mobile access - **no technical knowledge required!**

## ✨ What You Get

🌐 **Personal Cloud Storage** - Your own private alternative to Google Drive or iCloud
📱 **Mobile Access** - Access files from Android and iPhone apps
🔒 **Privacy Focused** - Your data stays on your hardware
💾 **External Storage** - Automatically detects and shares USB drives and external disks
🚀 **Step-by-Step Setup** - Interactive guided installation with full user control

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

## 📱 Mobile Device Setup

After installation:

### Android
1. Install "Nextcloud" from Google Play Store
2. Open the app and tap "Log in"
3. Enter server address: `http://YOUR_LOCAL_IP` (shown after installation)
4. Enter your username and password from the web setup

### iPhone
1. Install "Nextcloud" from App Store
2. Tap "Log in to your Nextcloud"
3. Enter server address: `http://YOUR_LOCAL_IP` (shown after installation)
4. Enter your username and password from the web setup

## 🔧 Advanced Usage

### Command Line Options
```bash
./install.sh --help          # Show all options
./install.sh --quiet         # Minimal output
./install.sh --debug         # Verbose logging for troubleshooting
./install.sh --skip-confirm  # Skip confirmation prompt
```

### Configuration Files
- **Config Directory**: `~/.kekeli-homecloud/`
- **Installation Log**: `~/.kekeli-homecloud/install.log`
- **Environment Settings**: `~/.kekeli-homecloud/config.env`

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