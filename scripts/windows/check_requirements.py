#!/usr/bin/env python3
"""
Windows Requirements Checker for Kekeli-HomeCloud
Validates system requirements for Windows-based Nextcloud installation

Part of the Kekeli-HomeCloud Easy Installer Project
"""

import os
import sys
import platform
import subprocess
import shutil
import winreg
import ctypes
from pathlib import Path
import json

class Colors:
    """ANSI color codes for Windows terminal output"""
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    CYAN = '\033[0;36m'
    NC = '\033[0m'  # No Color

# Requirements (based on Linux version but adjusted for Windows)
MIN_DISK_SPACE_GB = 4
RECOMMENDED_DISK_SPACE_GB = 10
MIN_MEMORY_MB = 2048
RECOMMENDED_MEMORY_MB = 4096

# Exit codes (matching Linux version)
SUCCESS = 0
ERROR_OS_NOT_SUPPORTED = 1
ERROR_INSUFFICIENT_DISK = 2
ERROR_INSUFFICIENT_MEMORY = 3
ERROR_NO_NETWORK = 4
ERROR_NO_ADMIN = 5
ERROR_DOCKER_UNAVAILABLE = 6

def print_status(status_type, message):
    """Print status message with appropriate icon and color"""
    if status_type == "pass":
        print(f"  ✅ {Colors.GREEN}{message}{Colors.NC}")
    elif status_type == "warn":
        print(f"  ⚠️  {Colors.YELLOW}{message}{Colors.NC}")
    elif status_type == "fail":
        print(f"  ❌ {Colors.RED}{message}{Colors.NC}")
    elif status_type == "info":
        print(f"  ℹ️  {Colors.CYAN}{message}{Colors.NC}")

def human_readable_size(bytes_val):
    """Convert bytes to human readable format"""
    if bytes_val >= 1024**3:
        return f"{bytes_val // (1024**3)} GB"
    elif bytes_val >= 1024**2:
        return f"{bytes_val // (1024**2)} MB"
    else:
        return f"{bytes_val // 1024} KB"

def is_admin():
    """Check if running with administrator privileges"""
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except:
        return False

def check_os_support():
    """Check Windows operating system support"""
    print(f"{Colors.YELLOW}📱 Checking Operating System Support...{Colors.NC}")

    try:
        # Get Windows version information
        version = platform.version()
        release = platform.release()

        # Windows 10 build 1903+ or Windows 11
        if release == "10":
            build = int(platform.version().split('.')[2])
            if build >= 18362:  # Windows 10 1903
                print_status("pass", f"Operating System: Windows {release} (Build {build})")
                return True
            else:
                print_status("fail", f"Windows 10 build {build} is too old (minimum: 18362)")
                return False
        elif release == "11":
            print_status("pass", f"Operating System: Windows {release}")
            return True
        else:
            print_status("fail", f"Unsupported Windows version: {release}")
            print_status("info", "Supported: Windows 10 (1903+), Windows 11")
            return False

    except Exception as e:
        print_status("fail", f"Could not determine Windows version: {e}")
        return False

def check_disk_space():
    """Check available disk space on current drive"""
    print(f"{Colors.YELLOW}💾 Checking Disk Space...{Colors.NC}")

    try:
        # Get current working directory drive
        current_drive = Path.cwd().anchor

        # Get disk usage
        total, used, free = shutil.disk_usage(current_drive)
        free_gb = free // (1024**3)

        print_status("info", f"Available space on {current_drive}: {human_readable_size(free)}")

        if free_gb >= RECOMMENDED_DISK_SPACE_GB:
            print_status("pass", f"Disk space: Excellent (>= {RECOMMENDED_DISK_SPACE_GB}GB)")
            return True
        elif free_gb >= MIN_DISK_SPACE_GB:
            print_status("warn", f"Disk space: Adequate (>= {MIN_DISK_SPACE_GB}GB, recommended: {RECOMMENDED_DISK_SPACE_GB}GB)")
            return True
        else:
            print_status("fail", f"Insufficient disk space: {free_gb}GB (minimum: {MIN_DISK_SPACE_GB}GB)")
            return False

    except Exception as e:
        print_status("fail", f"Could not check disk space: {e}")
        return False

def check_memory():
    """Check available system memory"""
    print(f"{Colors.YELLOW}🧠 Checking Available Memory...{Colors.NC}")

    try:
        # Get memory information using WMI
        result = subprocess.run([
            'wmic', 'OS', 'get', 'TotalVisibleMemorySize,FreePhysicalMemory', '/format:list'
        ], capture_output=True, text=True, timeout=10)

        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')
            total_kb = 0
            free_kb = 0

            for line in lines:
                if 'TotalVisibleMemorySize=' in line:
                    total_kb = int(line.split('=')[1])
                elif 'FreePhysicalMemory=' in line:
                    free_kb = int(line.split('=')[1])

            total_mb = total_kb // 1024
            free_mb = free_kb // 1024

            print_status("info", f"Total memory: {human_readable_size(total_kb * 1024)}")
            print_status("info", f"Available memory: {human_readable_size(free_kb * 1024)}")

            if free_mb >= RECOMMENDED_MEMORY_MB:
                print_status("pass", f"Memory: Excellent (>= {RECOMMENDED_MEMORY_MB}MB available)")
                return True
            elif free_mb >= MIN_MEMORY_MB:
                print_status("warn", f"Memory: Adequate (>= {MIN_MEMORY_MB}MB available, recommended: {RECOMMENDED_MEMORY_MB}MB)")
                return True
            else:
                print_status("fail", f"Insufficient memory: {free_mb}MB available (minimum: {MIN_MEMORY_MB}MB)")
                return False
        else:
            raise Exception("WMIC command failed")

    except Exception as e:
        print_status("warn", f"Could not get detailed memory info: {e}")
        print_status("info", "Proceeding with basic memory check...")
        return True

def check_network():
    """Check network connectivity"""
    print(f"{Colors.YELLOW}🌐 Checking Network Connectivity...{Colors.NC}")

    try:
        # Check internet connectivity
        result = subprocess.run(['ping', '-n', '1', '8.8.8.8'],
                              capture_output=True, timeout=10)

        if result.returncode == 0:
            print_status("pass", "Internet connectivity: Available")
        else:
            print_status("fail", "No internet connectivity (required for Docker installation)")
            return False

        # Check local network interfaces
        try:
            result = subprocess.run(['ipconfig'], capture_output=True, text=True)
            if 'IPv4 Address' in result.stdout:
                print_status("pass", "Local network interfaces: Available")
                # Extract and show IP addresses
                lines = result.stdout.split('\n')
                for line in lines:
                    if 'IPv4 Address' in line and '127.0.0.1' not in line:
                        ip = line.split(':')[-1].strip()
                        if ip and ip != '127.0.0.1':
                            print_status("info", f"  Interface IP: {ip}")
            else:
                print_status("warn", "No local network interfaces found (mobile access may be limited)")
        except:
            print_status("info", "Could not enumerate network interfaces")

        return True

    except Exception as e:
        print_status("fail", f"Network check failed: {e}")
        return False

def check_admin_privileges():
    """Check if running with administrator privileges"""
    print(f"{Colors.YELLOW}🔐 Checking Administrative Privileges...{Colors.NC}")

    if is_admin():
        print_status("pass", "Administrator privileges: Available")
        return True
    else:
        print_status("fail", "No administrator privileges (required for Docker installation)")
        print_status("info", "Please run this script as Administrator:")
        print_status("info", "  1. Right-click on Command Prompt or PowerShell")
        print_status("info", "  2. Select 'Run as administrator'")
        print_status("info", "  3. Run the installer again")
        return False

def check_docker():
    """Check Docker Desktop availability"""
    print(f"{Colors.YELLOW}🐳 Checking Docker Desktop Availability...{Colors.NC}")

    docker_available = False
    docker_compose_available = False

    # Check if Docker Desktop is installed
    docker_path = shutil.which('docker')
    if docker_path:
        try:
            result = subprocess.run(['docker', '--version'],
                                  capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                version = result.stdout.strip()
                print_status("pass", f"Docker installed: {version}")
                docker_available = True

                # Check if Docker daemon is running
                try:
                    result = subprocess.run(['docker', 'info'],
                                          capture_output=True, timeout=10)
                    if result.returncode == 0:
                        print_status("pass", "Docker daemon: Running")
                    else:
                        print_status("warn", "Docker daemon: Not running (will be started during installation)")
                except:
                    print_status("warn", "Docker daemon: Status unknown")
            else:
                print_status("warn", "Docker installed but not working properly")
        except Exception as e:
            print_status("warn", f"Docker check failed: {e}")
    else:
        print_status("info", "Docker not installed (will be installed automatically)")

    # Check Docker Compose
    compose_path = shutil.which('docker-compose')
    if compose_path:
        try:
            result = subprocess.run(['docker-compose', '--version'],
                                  capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                version = result.stdout.strip()
                print_status("pass", f"Docker Compose installed: {version}")
                docker_compose_available = True
        except:
            pass

    if not docker_compose_available:
        # Check for docker compose plugin
        try:
            result = subprocess.run(['docker', 'compose', 'version'],
                                  capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                version = result.stdout.strip()
                print_status("pass", f"Docker Compose (plugin) installed: {version}")
                docker_compose_available = True
        except:
            print_status("info", "Docker Compose not installed (will be installed with Docker Desktop)")

    # Check if Docker Desktop can be installed
    if not docker_available:
        # Check Windows version compatibility for Docker Desktop
        if check_hyper_v_support():
            print_status("pass", "Docker Desktop installation: Supported (Hyper-V capable)")
        elif check_wsl2_support():
            print_status("pass", "Docker Desktop installation: Supported (WSL2 backend)")
        else:
            print_status("fail", "Docker Desktop installation: Not supported (requires Hyper-V or WSL2)")
            return False

    return True

def check_hyper_v_support():
    """Check if Hyper-V is supported and available"""
    try:
        # Check if Hyper-V feature is available
        result = subprocess.run([
            'powershell', '-Command',
            'Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All | Select-Object State'
        ], capture_output=True, text=True, timeout=15)

        return 'Enabled' in result.stdout
    except:
        return False

def check_wsl2_support():
    """Check if WSL2 is supported"""
    try:
        # Check if WSL is available
        result = subprocess.run(['wsl', '--status'],
                              capture_output=True, timeout=10)
        return result.returncode == 0
    except:
        return False

def check_storage_detection():
    """Check storage detection capabilities"""
    print(f"{Colors.YELLOW}📁 Checking Storage Detection...{Colors.NC}")

    try:
        # Get available drives
        drives = []
        for drive_letter in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ':
            drive_path = f"{drive_letter}:\\"
            if os.path.exists(drive_path):
                drives.append(drive_letter)

        print_status("info", f"Available drives: {', '.join([f'{d}:' for d in drives])}")

        # Check for external storage (removable drives)
        try:
            result = subprocess.run([
                'powershell', '-Command',
                'Get-WmiObject -Class Win32_LogicalDisk | Where-Object {$_.DriveType -eq 2} | Select-Object DeviceID'
            ], capture_output=True, text=True, timeout=10)

            if result.returncode == 0 and 'DeviceID' in result.stdout:
                removable_drives = [line.strip() for line in result.stdout.split('\n')
                                  if ':' in line and 'DeviceID' not in line]
                if removable_drives:
                    print_status("pass", f"Removable storage detected: {', '.join(removable_drives)}")
                else:
                    print_status("info", "No removable storage currently connected")
            else:
                print_status("info", "No removable storage currently connected")
        except:
            print_status("info", "Could not check for removable storage")

        print_status("pass", "Storage detection: Available")
        return True

    except Exception as e:
        print_status("warn", f"Storage detection check failed: {e}")
        return True  # Non-critical

def main():
    """Main requirements check function"""
    print(f"{Colors.BLUE}🔍 Kekeli-HomeCloud Windows Requirements Checker{Colors.NC}")
    print(f"{Colors.BLUE}================================================{Colors.NC}")
    print()

    print(f"{Colors.CYAN}Starting comprehensive Windows system requirements check...{Colors.NC}")
    print()

    overall_status = True

    # Run all checks
    checks = [
        ("Operating System", check_os_support),
        ("Disk Space", check_disk_space),
        ("Memory", check_memory),
        ("Network", check_network),
        ("Administrator Privileges", check_admin_privileges),
        ("Docker Desktop", check_docker),
        ("Storage Detection", check_storage_detection),
    ]

    for check_name, check_func in checks:
        try:
            if not check_func():
                overall_status = False
        except Exception as e:
            print_status("fail", f"{check_name} check failed: {e}")
            overall_status = False
        print()

    # Final summary
    print(f"{Colors.BLUE}================================================{Colors.NC}")
    if overall_status:
        print_status("pass", "Requirements Check: PASSED")
        print(f"{Colors.GREEN}Your Windows system is ready for Kekeli-HomeCloud installation!{Colors.NC}")
        print()
        print(f"{Colors.CYAN}Next steps:{Colors.NC}")
        print(f"  1. Run: python scripts/windows/install.py")
        print(f"  2. Follow the interactive setup wizard")
        print(f"  3. Access your Nextcloud via web browser")
        return SUCCESS
    else:
        print_status("fail", "Requirements Check: FAILED")
        print(f"{Colors.RED}Please resolve the issues above before installation.{Colors.NC}")
        print()
        print(f"{Colors.CYAN}Common solutions:{Colors.NC}")
        print(f"  • Ensure Windows 10 (1903+) or Windows 11")
        print(f"  • Run as Administrator")
        print(f"  • Install Docker Desktop manually if needed")
        print(f"  • Free up disk space (minimum {MIN_DISK_SPACE_GB}GB)")
        print(f"  • Close applications to free memory")
        return ERROR_GENERAL

if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print()
        print_status("info", "Requirements check cancelled by user")
        sys.exit(ERROR_GENERAL)
    except Exception as e:
        print()
        print_status("fail", f"Unexpected error: {e}")
        sys.exit(ERROR_GENERAL)