#!/usr/bin/env python3
"""
Windows Storage Detection and Setup for Kekeli-HomeCloud
Automated storage detection, mounting, and configuration for Windows

Part of the Kekeli-HomeCloud Easy Installer Project
"""

import os
import sys
import subprocess
import shutil
from pathlib import Path
import json
import uuid

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

def human_readable_size(bytes_val):
    """Convert bytes to human readable format"""
    if bytes_val >= 1024**4:
        return f"{bytes_val / (1024**4):.1f} TB"
    elif bytes_val >= 1024**3:
        return f"{bytes_val / (1024**3):.1f} GB"
    elif bytes_val >= 1024**2:
        return f"{bytes_val / (1024**2):.1f} MB"
    else:
        return f"{bytes_val / 1024:.1f} KB"

def get_drive_info():
    """Get information about all available drives"""
    drives = []

    try:
        # Use PowerShell to get detailed drive information
        cmd = [
            'powershell', '-Command',
            'Get-WmiObject -Class Win32_LogicalDisk | Select-Object DeviceID, DriveType, Size, FreeSpace, VolumeName, FileSystem | ConvertTo-Json'
        ]

        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)

        if result.returncode == 0:
            drive_data = json.loads(result.stdout)

            # Handle single drive vs multiple drives
            if isinstance(drive_data, dict):
                drive_data = [drive_data]

            for drive in drive_data:
                if drive.get('Size'):  # Only include drives with size info
                    drive_info = {
                        'device_id': drive['DeviceID'],
                        'drive_type': drive['DriveType'],
                        'size': int(drive['Size']),
                        'free_space': int(drive['FreeSpace']),
                        'volume_name': drive.get('VolumeName', ''),
                        'file_system': drive.get('FileSystem', ''),
                        'drive_type_name': get_drive_type_name(drive['DriveType'])
                    }
                    drives.append(drive_info)

    except Exception as e:
        print_status("warn", f"Could not get detailed drive info: {e}")

    return sorted(drives, key=lambda x: x['device_id'])

def get_drive_type_name(drive_type):
    """Convert Windows drive type number to human readable name"""
    drive_types = {
        0: "Unknown",
        1: "No Root Directory",
        2: "Removable",
        3: "Fixed",
        4: "Network",
        5: "CD-ROM",
        6: "RAM"
    }
    return drive_types.get(drive_type, f"Type {drive_type}")

def display_drive_selection(drives):
    """Display available drives for user selection"""
    print(f"\n{Colors.CYAN}Available Storage Drives:{Colors.NC}")
    print(f"{Colors.CYAN}========================{Colors.NC}")

    for i, drive in enumerate(drives, 1):
        size_str = human_readable_size(drive['size'])
        free_str = human_readable_size(drive['free_space'])
        usage_percent = ((drive['size'] - drive['free_space']) / drive['size']) * 100

        print(f"\n{Colors.YELLOW}[{i}] {drive['device_id']} ({drive['drive_type_name']}){Colors.NC}")
        print(f"    Volume: {drive['volume_name'] or 'Unnamed'}")
        print(f"    File System: {drive['file_system']}")
        print(f"    Size: {size_str}")
        print(f"    Free: {free_str} ({100-usage_percent:.1f}% available)")

        # Add recommendations
        if drive['drive_type'] == 2:  # Removable
            print(f"    {Colors.GREEN}💡 Recommended for external storage{Colors.NC}")
        elif drive['drive_type'] == 3 and drive['free_space'] > 10 * 1024**3:  # Fixed with >10GB
            print(f"    {Colors.BLUE}💡 Suitable for Nextcloud data{Colors.NC}")

def get_user_storage_choice(drives):
    """Get user's storage choice through interactive selection"""
    print(f"\n{Colors.CYAN}Storage Configuration Options:{Colors.NC}")
    print(f"1. Use default location (C:\\Nextcloud)")
    print(f"2. Choose custom drive/location")
    print(f"3. Use external storage (recommended)")

    while True:
        try:
            choice = input(f"\n{Colors.YELLOW}Select option (1-3): {Colors.NC}").strip()

            if choice == "1":
                return create_default_storage_path()
            elif choice == "2":
                return get_custom_storage_path(drives)
            elif choice == "3":
                return get_external_storage_path(drives)
            else:
                print_status("warn", "Please enter 1, 2, or 3")

        except KeyboardInterrupt:
            print("\n")
            print_status("info", "Storage selection cancelled")
            return None

def create_default_storage_path():
    """Create default storage path on C: drive"""
    default_path = Path("C:/Nextcloud")

    print_status("info", f"Using default location: {default_path}")

    try:
        # Check if C: drive has enough space
        total, used, free = shutil.disk_usage("C:/")
        free_gb = free / (1024**3)

        if free_gb < 5:
            print_status("warn", f"Low disk space on C: drive ({free_gb:.1f}GB free)")
            print_status("info", "Consider using external storage for better performance")

        # Create directory
        default_path.mkdir(parents=True, exist_ok=True)
        print_status("pass", f"Storage directory created: {default_path}")

        return {
            'path': str(default_path),
            'type': 'default',
            'drive': 'C:',
            'free_space': free
        }

    except Exception as e:
        print_status("fail", f"Could not create default storage: {e}")
        return None

def get_custom_storage_path(drives):
    """Get custom storage path from user"""
    display_drive_selection(drives)

    while True:
        try:
            choice = input(f"\n{Colors.YELLOW}Select drive number (1-{len(drives)}): {Colors.NC}").strip()

            if choice.isdigit():
                drive_index = int(choice) - 1
                if 0 <= drive_index < len(drives):
                    selected_drive = drives[drive_index]
                    break
                else:
                    print_status("warn", f"Please enter a number between 1 and {len(drives)}")
            else:
                print_status("warn", "Please enter a valid number")

        except KeyboardInterrupt:
            print("\n")
            return None

    # Get custom folder name
    while True:
        try:
            folder_name = input(f"\n{Colors.YELLOW}Enter folder name (default: Nextcloud): {Colors.NC}").strip()
            if not folder_name:
                folder_name = "Nextcloud"

            custom_path = Path(selected_drive['device_id']) / folder_name

            # Validate path
            if custom_path.exists():
                overwrite = input(f"\n{Colors.YELLOW}Directory exists. Continue? (y/N): {Colors.NC}").strip().lower()
                if overwrite != 'y':
                    continue

            # Create directory
            custom_path.mkdir(parents=True, exist_ok=True)
            print_status("pass", f"Storage directory created: {custom_path}")

            return {
                'path': str(custom_path),
                'type': 'custom',
                'drive': selected_drive['device_id'],
                'free_space': selected_drive['free_space']
            }

        except Exception as e:
            print_status("fail", f"Could not create directory: {e}")
            print_status("info", "Please try a different location")

def get_external_storage_path(drives):
    """Get external storage path (removable drives)"""
    external_drives = [d for d in drives if d['drive_type'] == 2]  # Removable drives

    if not external_drives:
        print_status("info", "No external drives detected")
        print_status("info", "Please connect an external drive and try again")
        return get_custom_storage_path(drives)

    print(f"\n{Colors.CYAN}External Drives:{Colors.NC}")
    for i, drive in enumerate(external_drives, 1):
        size_str = human_readable_size(drive['size'])
        free_str = human_readable_size(drive['free_space'])
        print(f"[{i}] {drive['device_id']} - {drive['volume_name'] or 'Unnamed'} ({size_str}, {free_str} free)")

    while True:
        try:
            choice = input(f"\n{Colors.YELLOW}Select external drive (1-{len(external_drives)}): {Colors.NC}").strip()

            if choice.isdigit():
                drive_index = int(choice) - 1
                if 0 <= drive_index < len(external_drives):
                    selected_drive = external_drives[drive_index]
                    break

        except KeyboardInterrupt:
            print("\n")
            return None

    # Create Nextcloud folder on external drive
    external_path = Path(selected_drive['device_id']) / "Nextcloud"

    try:
        external_path.mkdir(parents=True, exist_ok=True)
        print_status("pass", f"External storage configured: {external_path}")

        return {
            'path': str(external_path),
            'type': 'external',
            'drive': selected_drive['device_id'],
            'free_space': selected_drive['free_space']
        }

    except Exception as e:
        print_status("fail", f"Could not configure external storage: {e}")
        return None

def create_docker_volumes(storage_config):
    """Create Docker volumes for Nextcloud data"""
    print_status("progress", "Creating Docker volumes...")

    try:
        base_path = Path(storage_config['path'])

        # Create subdirectories for different components
        directories = {
            'nextcloud_data': base_path / 'data',
            'nextcloud_config': base_path / 'config',
            'postgres_data': base_path / 'postgres',
            'redis_data': base_path / 'redis'
        }

        for name, path in directories.items():
            path.mkdir(parents=True, exist_ok=True)
            print_status("pass", f"Created {name}: {path}")

        # Set appropriate permissions (Windows equivalent)
        try:
            # Use icacls to set permissions for Docker access
            for name, path in directories.items():
                subprocess.run([
                    'icacls', str(path), '/grant', 'Everyone:(OI)(CI)F'
                ], capture_output=True, timeout=30)
        except Exception as e:
            print_status("warn", f"Could not set permissions: {e}")
            print_status("info", "Docker containers may need manual permission configuration")

        return directories

    except Exception as e:
        print_status("fail", f"Could not create Docker volumes: {e}")
        return None

def create_storage_config_file(storage_config, volumes):
    """Create storage configuration file for installer"""
    config_dir = Path.home() / '.kekeli-homecloud'
    config_dir.mkdir(exist_ok=True)

    storage_config_file = config_dir / 'storage.json'

    config_data = {
        'storage_path': storage_config['path'],
        'storage_type': storage_config['type'],
        'drive': storage_config['drive'],
        'free_space': storage_config['free_space'],
        'volumes': {name: str(path) for name, path in volumes.items()},
        'created_at': str(Path().resolve()),
        'platform': 'windows'
    }

    try:
        with open(storage_config_file, 'w') as f:
            json.dump(config_data, f, indent=2)

        print_status("pass", f"Storage configuration saved: {storage_config_file}")
        return config_data

    except Exception as e:
        print_status("fail", f"Could not save storage configuration: {e}")
        return None

def validate_storage_setup(storage_config, volumes):
    """Validate that storage setup is working correctly"""
    print_status("progress", "Validating storage setup...")

    try:
        # Test write access to each volume
        for name, path in volumes.items():
            test_file = Path(path) / 'test_write.tmp'
            try:
                test_file.write_text('test')
                test_file.unlink()
                print_status("pass", f"Write test passed: {name}")
            except Exception as e:
                print_status("fail", f"Write test failed for {name}: {e}")
                return False

        # Check available space
        total, used, free = shutil.disk_usage(storage_config['path'])
        free_gb = free / (1024**3)

        if free_gb < 1:
            print_status("fail", f"Insufficient free space: {free_gb:.1f}GB")
            return False
        elif free_gb < 5:
            print_status("warn", f"Low free space: {free_gb:.1f}GB")
        else:
            print_status("pass", f"Adequate free space: {free_gb:.1f}GB")

        return True

    except Exception as e:
        print_status("fail", f"Storage validation failed: {e}")
        return False

def main():
    """Main storage setup function"""
    print(f"{Colors.BLUE}📁 Kekeli-HomeCloud Windows Storage Setup{Colors.NC}")
    print(f"{Colors.BLUE}========================================={Colors.NC}")
    print()

    print_status("info", "Detecting available storage devices...")

    # Get drive information
    drives = get_drive_info()

    if not drives:
        print_status("fail", "No drives detected")
        return False

    print_status("pass", f"Found {len(drives)} storage devices")

    # Interactive storage selection
    storage_config = get_user_storage_choice(drives)

    if not storage_config:
        print_status("fail", "Storage configuration cancelled")
        return False

    # Create Docker volumes
    volumes = create_docker_volumes(storage_config)

    if not volumes:
        print_status("fail", "Failed to create Docker volumes")
        return False

    # Validate storage setup
    if not validate_storage_setup(storage_config, volumes):
        print_status("fail", "Storage validation failed")
        return False

    # Save configuration
    config_data = create_storage_config_file(storage_config, volumes)

    if not config_data:
        print_status("fail", "Failed to save storage configuration")
        return False

    # Success summary
    print()
    print_status("pass", "Storage setup completed successfully!")
    print()
    print(f"{Colors.CYAN}Storage Configuration Summary:{Colors.NC}")
    print(f"  Location: {storage_config['path']}")
    print(f"  Type: {storage_config['type']}")
    print(f"  Drive: {storage_config['drive']}")
    print(f"  Available Space: {human_readable_size(storage_config['free_space'])}")
    print()
    print(f"{Colors.CYAN}Next steps:{Colors.NC}")
    print(f"  1. Storage is ready for Nextcloud installation")
    print(f"  2. Run: python scripts/windows/setup_networking.py")
    print(f"  3. Docker volumes are configured and accessible")

    return True

if __name__ == "__main__":
    try:
        success = main()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print()
        print_status("info", "Storage setup cancelled by user")
        sys.exit(1)
    except Exception as e:
        print()
        print_status("fail", f"Unexpected error: {e}")
        sys.exit(1)