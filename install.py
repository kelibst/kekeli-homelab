#!/usr/bin/env python3
"""
Kekeli-HomeCloud Easy Installer - Smart Platform Detection
Main entry point that detects the platform and delegates to appropriate installer

Part of the Kekeli-HomeCloud Easy Installer Project
Author: Kekeli-HomeCloud Team
"""

import os
import sys
import platform
import subprocess
import shutil
from pathlib import Path

class Colors:
    """ANSI color codes for terminal output"""
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    CYAN = '\033[0;36m'
    MAGENTA = '\033[0;35m'
    NC = '\033[0m'  # No Color

def print_banner():
    """Print the Kekeli-HomeCloud welcome banner"""
    print(f"""{Colors.BLUE}
╔══════════════════════════════════════════════════════════════╗
║                 🏠 Kekeli-HomeCloud Installer                 ║
║            Transform Your Computer Into Your Cloud           ║
╚══════════════════════════════════════════════════════════════╝{Colors.NC}

{Colors.CYAN}One-click Nextcloud installation for everyone!{Colors.NC}
""")

def print_status(status_type, message):
    """Print status message with appropriate icon and color"""
    if status_type == "info":
        print(f"  ℹ️  {Colors.CYAN}{message}{Colors.NC}")
    elif status_type == "success":
        print(f"  ✅ {Colors.GREEN}{message}{Colors.NC}")
    elif status_type == "warning":
        print(f"  ⚠️  {Colors.YELLOW}{message}{Colors.NC}")
    elif status_type == "error":
        print(f"  ❌ {Colors.RED}{message}{Colors.NC}")

def detect_platform():
    """
    Detect the current platform and return appropriate installer path

    Returns:
        tuple: (platform_name, installer_type, installer_path)
    """
    system = platform.system().lower()

    if system == "linux":
        # Check if running in WSL
        try:
            with open('/proc/version', 'r') as f:
                if 'microsoft' in f.read().lower():
                    return ("WSL2", "bash", "linux")
        except:
            pass

        # Native Linux
        return ("Linux", "bash", "linux")

    elif system == "windows":
        # Pure Windows environment
        return ("Windows", "python", "windows")

    elif system == "darwin":
        # macOS (future support)
        return ("macOS", "unsupported", "macos")

    else:
        return ("Unknown", "unsupported", "unknown")

def check_bash_availability():
    """Check if bash is available on the system"""
    return shutil.which('bash') is not None

def check_python_version():
    """Check if Python version is compatible"""
    version = sys.version_info
    if version.major >= 3 and version.minor >= 6:
        return True, f"{version.major}.{version.minor}.{version.micro}"
    return False, f"{version.major}.{version.minor}.{version.micro}"

def run_linux_installer():
    """Run the Linux bash-based installer"""
    script_dir = Path(__file__).parent
    installer_script = script_dir / "scripts" / "check-requirements.sh"

    if not installer_script.exists():
        print_status("error", f"Linux installer not found: {installer_script}")
        print_status("info", "Please ensure you're running from the correct directory")
        return False

    print_status("info", "Starting Linux/WSL2 installer...")
    print(f"{Colors.CYAN}Running: bash {installer_script}{Colors.NC}")
    print()

    try:
        # Run the requirements checker first
        result = subprocess.run(['bash', str(installer_script)], check=False)

        if result.returncode == 0:
            print()
            print_status("success", "Requirements check passed!")
            print_status("info", "You can now run the full installer:")
            print(f"  {Colors.CYAN}bash install.sh{Colors.NC}")
            return True
        else:
            print()
            print_status("warning", "Requirements check found issues.")
            print_status("info", "Please resolve the issues above before proceeding.")
            return False

    except FileNotFoundError:
        print_status("error", "Bash not found. Please install bash or use WSL2 on Windows.")
        return False
    except Exception as e:
        print_status("error", f"Failed to run Linux installer: {e}")
        return False

def run_windows_installer():
    """Run the Windows Python-based installer"""
    script_dir = Path(__file__).parent
    windows_installer = script_dir / "scripts" / "windows" / "check_requirements.py"

    if not windows_installer.exists():
        print_status("error", f"Windows installer not found: {windows_installer}")
        print_status("info", "Windows support is still under development.")
        print_status("info", "Consider using WSL2 with the Linux installer as an alternative.")
        return False

    print_status("info", "Starting Windows installer...")

    try:
        # Import and run the Windows requirements checker
        sys.path.insert(0, str(script_dir / "scripts" / "windows"))
        import check_requirements
        return check_requirements.main()

    except ImportError as e:
        print_status("error", f"Failed to import Windows installer: {e}")
        return False
    except Exception as e:
        print_status("error", f"Failed to run Windows installer: {e}")
        return False

def show_help():
    """Show help information"""
    print(f"""
{Colors.BLUE}Kekeli-HomeCloud Easy Installer{Colors.NC}

{Colors.CYAN}Usage:{Colors.NC}
  python install.py [options]
  ./install.py [options]

{Colors.CYAN}Options:{Colors.NC}
  -h, --help        Show this help message
  -v, --version     Show version information
  --platform        Show detected platform information
  --check-only      Only run requirements check, don't install

{Colors.CYAN}Platform Support:{Colors.NC}
  • Linux (Ubuntu, Debian, DeepinOS) - Native bash installer
  • WSL2 - Uses Linux bash installer with Windows optimizations
  • Windows 10/11 - Native Python installer
  • macOS - Planned for future release

{Colors.CYAN}Quick Start:{Colors.NC}
  1. Run this script: python install.py
  2. Follow the interactive prompts
  3. Access Nextcloud via web browser
  4. Set up mobile devices using provided QR codes

{Colors.CYAN}Requirements:{Colors.NC}
  • Internet connection
  • 4GB+ available disk space
  • 2GB+ available RAM
  • Administrative privileges (sudo/Administrator)
  • Docker or ability to install Docker

{Colors.CYAN}For help and support:{Colors.NC}
  • Documentation: docs/
  • Troubleshooting: docs/troubleshooting.md
  • Mobile setup: docs/mobile-setup.md
""")

def show_platform_info():
    """Show detailed platform information"""
    platform_name, installer_type, installer_path = detect_platform()
    python_ok, python_version = check_python_version()
    bash_available = check_bash_availability()

    print(f"""
{Colors.BLUE}Platform Detection Results{Colors.NC}
{Colors.BLUE}========================{Colors.NC}

{Colors.CYAN}System Information:{Colors.NC}
  • Operating System: {platform.system()} {platform.release()}
  • Architecture: {platform.machine()}
  • Python Version: {python_version}

{Colors.CYAN}Detected Platform:{Colors.NC}
  • Platform: {platform_name}
  • Installer Type: {installer_type}
  • Installer Path: {installer_path}

{Colors.CYAN}Available Tools:{Colors.NC}
  • Python 3.6+: {'✅' if python_ok else '❌'}
  • Bash: {'✅' if bash_available else '❌'}

{Colors.CYAN}Recommended Action:{Colors.NC}""")

    if installer_type == "bash":
        print(f"  • Use Linux/WSL2 installer (bash scripts)")
    elif installer_type == "python":
        print(f"  • Use Windows installer (Python scripts)")
    elif installer_type == "unsupported":
        print(f"  • Platform not yet supported")

    print()

def main():
    """Main installer function"""
    # Parse command line arguments
    if len(sys.argv) > 1:
        arg = sys.argv[1].lower()
        if arg in ['-h', '--help']:
            show_help()
            return 0
        elif arg in ['-v', '--version']:
            print("Kekeli-HomeCloud Easy Installer v1.0")
            return 0
        elif arg == '--platform':
            show_platform_info()
            return 0
        elif arg == '--check-only':
            # Set flag for check-only mode
            os.environ['KEKELI_CHECK_ONLY'] = '1'
        else:
            print_status("error", f"Unknown option: {arg}")
            print_status("info", "Use --help for usage information")
            return 1

    # Print banner
    print_banner()

    # Detect platform
    platform_name, installer_type, installer_path = detect_platform()

    print_status("info", f"Detected platform: {platform_name}")
    print_status("info", f"Using installer: {installer_type}")
    print()

    # Run appropriate installer
    if installer_type == "bash":
        success = run_linux_installer()
    elif installer_type == "python":
        success = run_windows_installer()
    else:
        print_status("error", f"Platform '{platform_name}' is not yet supported")
        print_status("info", "Supported platforms: Linux, WSL2, Windows 10/11")
        if platform_name == "macOS":
            print_status("info", "macOS support is planned for a future release")
        return 1

    # Final status
    print()
    if success:
        print_status("success", "Platform check completed successfully!")
        if not os.environ.get('KEKELI_CHECK_ONLY'):
            print()
            print(f"{Colors.CYAN}Next steps:{Colors.NC}")
            if installer_type == "bash":
                print(f"  1. Run: bash install.sh")
            else:
                print(f"  1. Run: python scripts/windows/install.py")
            print(f"  2. Follow the interactive setup")
            print(f"  3. Access Nextcloud via web browser")
    else:
        print_status("error", "Platform check failed")
        print_status("info", "Please resolve the issues above before proceeding")
        return 1

    return 0

if __name__ == "__main__":
    try:
        exit_code = main()
        sys.exit(exit_code)
    except KeyboardInterrupt:
        print()
        print_status("info", "Installation cancelled by user")
        sys.exit(1)
    except Exception as e:
        print()
        print_status("error", f"Unexpected error: {e}")
        sys.exit(1)