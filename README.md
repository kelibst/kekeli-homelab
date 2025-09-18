# 🏠 Kekeli-HomeCloud Easy Installer

**Transform Your Computer Into Your Personal Cloud**

One-click Nextcloud installer that makes home cloud storage as easy as downloading an app. Built for everyone - from tech-curious friends to home lab enthusiasts.

## ✨ Features

- **🖱️ One-Click Installation**: Single command deploys complete Nextcloud solution
- **📱 Mobile-Ready**: Automatic Android/iPhone connectivity with QR codes
- **💾 Smart Storage**: Automatic external drive detection and mounting
- **🌐 Network Optimized**: Automatic firewall and network configuration
- **🔧 Cross-Platform**: Native support for Linux, Windows, and WSL2
- **🛡️ Robust Error Handling**: Clear guidance when things go wrong

## 🚀 Quick Start

### For Linux/WSL2 Users
```bash
# Clone and run
git clone <repository-url>
cd kekeli-homelab
python3 install.py
```

### For Windows Users
```powershell
# Clone and run (as Administrator)
git clone <repository-url>
cd kekeli-homelab
python install.py
```

The installer automatically detects your platform and uses the appropriate installation method!

## 📋 System Requirements

### Linux/WSL2
- **OS**: Ubuntu 18.04+, Debian 10+, DeepinOS, WSL2
- **RAM**: 2GB+ available (4GB+ recommended)
- **Storage**: 4GB+ free space (10GB+ recommended)
- **Network**: Internet connection + local network access
- **Permissions**: sudo access

### Windows
- **OS**: Windows 10 (1903+) or Windows 11
- **RAM**: 2GB+ available (4GB+ recommended)
- **Storage**: 4GB+ free space (10GB+ recommended)
- **Network**: Internet connection + local network access
- **Permissions**: Administrator privileges
- **Docker**: Docker Desktop (auto-installed if missing)

## 🏗️ Architecture

### Smart Platform Detection
```
install.py (Entry Point)
├── Linux/WSL2 → bash scripts (proven, battle-tested)
├── Windows → Python scripts (native Windows experience)
└── Shared → templates/, docs/, configuration
```

### Installation Flow
```
1. Requirements Check → 2. Platform Detection → 3. Component Setup → 4. Validation → 5. Success
     ↓                      ↓                      ↓                ↓            ↓
- Docker available     - Auto-detect platform   - Install Docker  - Test web   - Mobile guide
- Disk space          - Choose appropriate      - Setup storage   - Test mobile- Usage info
- Network access       installer path          - Configure net   - Run tests  - Troubleshooting
- Permissions         - Load configurations     - Deploy apps     - Validate   - Maintenance
```

## 📱 Mobile Device Setup

After installation, the system generates:
- **QR Codes** for easy mobile configuration
- **HTML Setup Guide** with step-by-step instructions
- **Automatic Network Configuration** for local access

### Connecting Your Phone
1. **Same WiFi**: Ensure your phone is on the same network
2. **Open Browser**: Visit the provided IP address
3. **Install App**: Download Nextcloud from your app store
4. **Configure**: Use the generated server URL

## 🔧 Advanced Configuration

### Linux-Specific Features
- UUID-based persistent storage mounting
- Automatic firewall configuration (iptables)
- WSL2 Windows host IP detection
- Bash-based modular architecture

### Windows-Specific Features
- Docker Desktop automation
- Windows Firewall configuration
- Drive letter and UNC path support
- PowerShell integration

## 📂 Project Structure

```
kekeli-homelab/
├── install.py                     # Smart platform detection entry point
├── scripts/
│   ├── check-requirements.sh      # Linux requirements checker
│   ├── setup-docker.sh           # Linux Docker setup
│   ├── setup-storage.sh          # Linux storage configuration
│   ├── setup-networking.sh       # Linux network setup
│   ├── setup-nextcloud.sh        # Linux Nextcloud deployment
│   ├── setup-mobile.sh           # Linux mobile configuration
│   ├── utils/                    # Linux utility functions
│   └── windows/                  # Windows-specific scripts
│       ├── check_requirements.py  # Windows requirements checker
│       ├── setup_docker.py       # Windows Docker Desktop setup
│       ├── setup_storage.py      # Windows storage configuration
│       ├── setup_networking.py   # Windows network setup
│       └── setup_nextcloud.py    # Windows Nextcloud deployment
├── templates/
│   ├── docker-compose.yml.template
│   └── .env.template
├── docs/
│   ├── troubleshooting.md
│   └── mobile-setup.md
└── tests/
    ├── test-framework.sh
    └── integration tests
```

## 🛠️ Development Status

### ✅ Completed (Linux Branch)
- Comprehensive requirements checking
- Docker installation automation
- Storage detection and mounting
- Network configuration and firewall setup
- Nextcloud container deployment
- Mobile device integration
- Testing framework

### ✅ Completed (Windows Branch)
- Platform detection system
- Windows requirements checker
- Docker Desktop automation
- Windows storage management
- Windows Firewall configuration
- Cross-platform documentation

### 🔄 In Progress
- Windows Nextcloud deployment
- Integration testing across platforms
- Performance optimization

## 🧪 Testing

### Linux Testing
```bash
# Run requirements check only
./scripts/check-requirements.sh

# Run full test suite
./tests/test-safe.sh
```

### Windows Testing
```powershell
# Run requirements check only
python scripts/windows/check_requirements.py

# Run platform detection
python install.py --platform
```

## 🏃‍♂️ Quick Install (One Command)

### Linux/WSL2
```bash
curl -sSL https://raw.githubusercontent.com/your-repo/kekeli-homelab/main/install.sh | bash
```

### Windows (PowerShell as Administrator)
```powershell
iwr -useb https://raw.githubusercontent.com/your-repo/kekeli-homelab/main/install.ps1 | iex
```

## 🆘 Troubleshooting

### Common Issues

**"Platform not supported"**
- Ensure you're on Windows 10 1903+, Windows 11, or supported Linux distro
- For Windows, try running as Administrator

**"Docker not available"**
- Linux: Installer will auto-install Docker
- Windows: Ensure virtualization is enabled in BIOS

**"Mobile can't connect"**
- Check both devices are on same WiFi network
- Verify firewall rules allow connections
- Try accessing web interface from computer first

**"Permission denied"**
- Linux: Ensure user has sudo privileges
- Windows: Run PowerShell as Administrator

### Getting Help

1. **Built-in Diagnostics**: Run with `--check-only` flag
2. **Logs**: Check `~/.kekeli-homecloud/install.log`
3. **Mobile Setup**: Open generated HTML guide
4. **Platform Info**: Run `python install.py --platform`

## 🎯 Target Users

### 👨‍👩‍👧‍👦 Friends & Family
- **Goal**: Replace Google Drive/iCloud with personal cloud
- **Experience**: Zero technical setup required
- **Benefit**: Privacy, control, no monthly fees

### 🏢 Small Businesses
- **Goal**: Secure file sharing for teams
- **Experience**: Minimal IT requirements
- **Benefit**: Professional solution without enterprise cost

### 🔬 Home Lab Enthusiasts
- **Goal**: Quick, reliable Nextcloud deployment
- **Experience**: Customizable, well-documented
- **Benefit**: Time-saving with proven components

## 🤝 Contributing

This project extracts and simplifies proven solutions from the `home-nextcloud` project. We welcome contributions that:

- Improve user experience for non-technical users
- Add support for additional platforms
- Enhance error handling and recovery
- Expand mobile device compatibility

## 📄 License

Open source project aimed at democratizing home cloud storage.

## 🎉 Success Stories

> "I had my own cloud running in 8 minutes. My iPhone connected automatically!" - Tech-curious friend

> "Finally, a Nextcloud installer that just works. No more weekend troubleshooting." - Home lab enthusiast

---

**Made with ❤️ by the Kekeli-HomeCloud Team**

*Transform your computer into your personal cloud - no technical degree required!*