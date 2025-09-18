#!/usr/bin/env python3
"""
Windows Docker Desktop Setup for Kekeli-HomeCloud
Automated Docker Desktop installation and configuration for Windows

Part of the Kekeli-HomeCloud Easy Installer Project
"""

import os
import sys
import subprocess
import time
import urllib.request
import urllib.error
from pathlib import Path
import tempfile
import json

class Colors:
    """ANSI color codes for Windows terminal output"""
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    CYAN = '\033[0;36m'
    NC = '\033[0m'  # No Color

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
    elif status_type == "progress":
        print(f"  🔄 {Colors.BLUE}{message}{Colors.NC}")

def is_docker_installed():
    """Check if Docker Desktop is already installed"""
    try:
        result = subprocess.run(['docker', '--version'],
                              capture_output=True, text=True, timeout=5)
        return result.returncode == 0
    except:
        return False

def is_docker_running():
    """Check if Docker daemon is running"""
    try:
        result = subprocess.run(['docker', 'info'],
                              capture_output=True, timeout=10)
        return result.returncode == 0
    except:
        return False

def get_docker_desktop_download_url():
    """Get the latest Docker Desktop download URL for Windows"""
    # Docker Desktop for Windows stable release
    return "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"

def download_docker_desktop(download_url, dest_path):
    """Download Docker Desktop installer"""
    print_status("progress", "Downloading Docker Desktop installer...")
    print_status("info", f"URL: {download_url}")

    try:
        def show_progress(block_num, block_size, total_size):
            downloaded = block_num * block_size
            if total_size > 0:
                percent = min(100, (downloaded * 100) // total_size)
                print(f"\r  📥 Download progress: {percent}% ({downloaded // (1024*1024)}MB)", end='')

        urllib.request.urlretrieve(download_url, dest_path, show_progress)
        print()  # New line after progress
        print_status("pass", f"Downloaded to: {dest_path}")
        return True

    except urllib.error.URLError as e:
        print_status("fail", f"Download failed: {e}")
        return False
    except Exception as e:
        print_status("fail", f"Download error: {e}")
        return False

def install_docker_desktop(installer_path):
    """Install Docker Desktop using the downloaded installer"""
    print_status("progress", "Installing Docker Desktop...")
    print_status("info", "This may take several minutes...")

    try:
        # Run installer with quiet/automated flags
        cmd = [
            str(installer_path),
            'install',
            '--quiet',
            '--accept-license'
        ]

        print_status("info", f"Running: {' '.join(cmd)}")

        result = subprocess.run(cmd, timeout=600)  # 10 minute timeout

        if result.returncode == 0:
            print_status("pass", "Docker Desktop installation completed")
            return True
        else:
            print_status("fail", f"Installation failed with exit code: {result.returncode}")
            return False

    except subprocess.TimeoutExpired:
        print_status("fail", "Installation timed out (10 minutes)")
        return False
    except Exception as e:
        print_status("fail", f"Installation error: {e}")
        return False

def start_docker_desktop():
    """Start Docker Desktop application"""
    print_status("progress", "Starting Docker Desktop...")

    try:
        # Try multiple common installation paths
        docker_paths = [
            Path(os.environ.get('ProgramFiles', 'C:\\Program Files')) / 'Docker' / 'Docker' / 'Docker Desktop.exe',
            Path(os.environ.get('ProgramFiles(x86)', 'C:\\Program Files (x86)')) / 'Docker' / 'Docker' / 'Docker Desktop.exe',
            Path.home() / 'AppData' / 'Local' / 'Programs' / 'Docker' / 'Docker' / 'Docker Desktop.exe'
        ]

        docker_exe = None
        for path in docker_paths:
            if path.exists():
                docker_exe = path
                break

        if not docker_exe:
            print_status("fail", "Docker Desktop executable not found")
            print_status("info", "Please start Docker Desktop manually")
            return False

        # Start Docker Desktop
        subprocess.Popen([str(docker_exe)], creationflags=subprocess.CREATE_NEW_PROCESS_GROUP)
        print_status("info", "Docker Desktop startup initiated...")

        return True

    except Exception as e:
        print_status("fail", f"Failed to start Docker Desktop: {e}")
        return False

def wait_for_docker_daemon(timeout=300):
    """Wait for Docker daemon to become available"""
    print_status("progress", "Waiting for Docker daemon to start...")

    start_time = time.time()
    while time.time() - start_time < timeout:
        if is_docker_running():
            print_status("pass", "Docker daemon is running")
            return True

        elapsed = int(time.time() - start_time)
        print(f"\r  ⏳ Waiting for Docker daemon... ({elapsed}s)", end='')
        time.sleep(5)

    print()
    print_status("fail", f"Docker daemon did not start within {timeout} seconds")
    return False

def configure_docker_settings():
    """Configure Docker Desktop settings for optimal Nextcloud performance"""
    print_status("progress", "Configuring Docker Desktop settings...")

    try:
        # Docker Desktop settings are stored in daemon.json
        docker_config_dir = Path.home() / '.docker'
        daemon_config_file = docker_config_dir / 'daemon.json'

        # Create config directory if it doesn't exist
        docker_config_dir.mkdir(exist_ok=True)

        # Recommended settings for Nextcloud
        config = {
            "log-driver": "json-file",
            "log-opts": {
                "max-size": "10m",
                "max-file": "3"
            },
            "storage-driver": "overlay2"
        }

        # Read existing config if it exists
        if daemon_config_file.exists():
            try:
                with open(daemon_config_file, 'r') as f:
                    existing_config = json.load(f)
                    config.update(existing_config)
            except:
                print_status("warn", "Could not read existing daemon.json, creating new one")

        # Write updated config
        with open(daemon_config_file, 'w') as f:
            json.dump(config, f, indent=2)

        print_status("pass", "Docker configuration updated")
        return True

    except Exception as e:
        print_status("warn", f"Could not configure Docker settings: {e}")
        return True  # Non-critical

def enable_wsl2_backend():
    """Enable WSL2 backend for Docker Desktop if WSL2 is available"""
    print_status("info", "Checking WSL2 backend availability...")

    try:
        # Check if WSL2 is available
        result = subprocess.run(['wsl', '--status'],
                              capture_output=True, timeout=10)

        if result.returncode == 0:
            print_status("pass", "WSL2 is available")
            print_status("info", "Docker Desktop will use WSL2 backend (recommended)")
            return True
        else:
            print_status("info", "WSL2 not available, using Hyper-V backend")
            return True

    except Exception as e:
        print_status("info", f"Could not check WSL2 status: {e}")
        return True  # Non-critical

def verify_docker_installation():
    """Verify Docker installation is working correctly"""
    print_status("progress", "Verifying Docker installation...")

    try:
        # Test Docker version
        result = subprocess.run(['docker', '--version'],
                              capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            print_status("pass", f"Docker version: {result.stdout.strip()}")
        else:
            print_status("fail", "Docker version check failed")
            return False

        # Test Docker Compose
        result = subprocess.run(['docker', 'compose', 'version'],
                              capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            print_status("pass", f"Docker Compose: {result.stdout.strip()}")
        else:
            # Try legacy docker-compose
            result = subprocess.run(['docker-compose', '--version'],
                                  capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                print_status("pass", f"Docker Compose (legacy): {result.stdout.strip()}")
            else:
                print_status("warn", "Docker Compose not available")

        # Test Docker daemon
        if is_docker_running():
            print_status("pass", "Docker daemon is responding")
        else:
            print_status("fail", "Docker daemon is not responding")
            return False

        # Test container creation
        print_status("info", "Testing container creation...")
        result = subprocess.run([
            'docker', 'run', '--rm', 'hello-world'
        ], capture_output=True, text=True, timeout=60)

        if result.returncode == 0:
            print_status("pass", "Container test successful")
        else:
            print_status("warn", f"Container test failed: {result.stderr}")

        return True

    except Exception as e:
        print_status("fail", f"Docker verification failed: {e}")
        return False

def main():
    """Main Docker Desktop setup function"""
    print(f"{Colors.BLUE}🐳 Kekeli-HomeCloud Docker Desktop Setup{Colors.NC}")
    print(f"{Colors.BLUE}=========================================={Colors.NC}")
    print()

    # Check if Docker is already installed and working
    if is_docker_installed():
        print_status("info", "Docker is already installed")

        if is_docker_running():
            print_status("pass", "Docker is running")
            print_status("info", "Verifying Docker installation...")

            if verify_docker_installation():
                print_status("pass", "Docker setup is complete and working")
                return True
            else:
                print_status("warn", "Docker installation needs attention")
        else:
            print_status("info", "Docker is installed but not running")

            if start_docker_desktop():
                if wait_for_docker_daemon():
                    configure_docker_settings()
                    if verify_docker_installation():
                        print_status("pass", "Docker setup completed successfully")
                        return True

    print_status("info", "Docker Desktop installation required")

    # Download and install Docker Desktop
    with tempfile.TemporaryDirectory() as temp_dir:
        installer_path = Path(temp_dir) / "DockerDesktopInstaller.exe"
        download_url = get_docker_desktop_download_url()

        print_status("info", f"Installing Docker Desktop to: {installer_path}")

        # Download installer
        if not download_docker_desktop(download_url, installer_path):
            print_status("fail", "Failed to download Docker Desktop")
            return False

        # Install Docker Desktop
        if not install_docker_desktop(installer_path):
            print_status("fail", "Failed to install Docker Desktop")
            return False

    # Post-installation setup
    print_status("info", "Performing post-installation setup...")

    # Enable WSL2 backend if available
    enable_wsl2_backend()

    # Start Docker Desktop
    if start_docker_desktop():
        # Wait for daemon to start
        if wait_for_docker_daemon():
            # Configure settings
            configure_docker_settings()

            # Verify installation
            if verify_docker_installation():
                print_status("pass", "Docker Desktop setup completed successfully!")
                print()
                print(f"{Colors.CYAN}Next steps:{Colors.NC}")
                print(f"  1. Docker Desktop is now running")
                print(f"  2. You can proceed with Nextcloud installation")
                print(f"  3. Run: python scripts/windows/install.py")
                return True

    print_status("fail", "Docker Desktop setup incomplete")
    print_status("info", "Please check Docker Desktop manually and try again")
    return False

if __name__ == "__main__":
    try:
        success = main()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print()
        print_status("info", "Docker setup cancelled by user")
        sys.exit(1)
    except Exception as e:
        print()
        print_status("fail", f"Unexpected error: {e}")
        sys.exit(1)