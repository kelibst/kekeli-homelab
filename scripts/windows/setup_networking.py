#!/usr/bin/env python3
"""
Windows Networking and Firewall Configuration for Kekeli-HomeCloud
Automated network setup and Windows Firewall configuration for Nextcloud access

Part of the Kekeli-HomeCloud Easy Installer Project
"""

import os
import sys
import subprocess
import socket
import ipaddress
import json
from pathlib import Path

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

def get_network_interfaces():
    """Get network interface information using PowerShell"""
    print_status("progress", "Detecting network interfaces...")

    try:
        cmd = [
            'powershell', '-Command',
            '''Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notlike "*Loopback*" -and $_.IPAddress -ne "127.0.0.1"} | Select-Object IPAddress, InterfaceAlias, PrefixLength | ConvertTo-Json'''
        ]

        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)

        if result.returncode == 0 and result.stdout.strip():
            interface_data = json.loads(result.stdout)

            # Handle single interface vs multiple interfaces
            if isinstance(interface_data, dict):
                interface_data = [interface_data]

            interfaces = []
            for iface in interface_data:
                interfaces.append({
                    'ip_address': iface['IPAddress'],
                    'interface_name': iface['InterfaceAlias'],
                    'prefix_length': iface['PrefixLength']
                })

            return interfaces

    except Exception as e:
        print_status("warn", f"Could not get network interfaces: {e}")

    # Fallback method using socket
    try:
        hostname = socket.gethostname()
        local_ip = socket.gethostbyname(hostname)
        return [{'ip_address': local_ip, 'interface_name': 'Primary', 'prefix_length': 24}]
    except:
        return []

def get_default_gateway():
    """Get default gateway IP address"""
    try:
        cmd = [
            'powershell', '-Command',
            'Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Select-Object NextHop | ConvertTo-Json'
        ]

        result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)

        if result.returncode == 0 and result.stdout.strip():
            gateway_data = json.loads(result.stdout)

            if isinstance(gateway_data, dict):
                return gateway_data.get('NextHop')
            elif isinstance(gateway_data, list) and gateway_data:
                return gateway_data[0].get('NextHop')

    except Exception as e:
        print_status("warn", f"Could not detect default gateway: {e}")

    return None

def calculate_network_range(ip_address, prefix_length):
    """Calculate network range from IP and prefix length"""
    try:
        network = ipaddress.IPv4Network(f"{ip_address}/{prefix_length}", strict=False)
        return str(network)
    except:
        return f"{ip_address}/24"  # Default fallback

def configure_windows_firewall():
    """Configure Windows Firewall for Nextcloud access"""
    print_status("progress", "Configuring Windows Firewall...")

    firewall_rules = [
        {
            'name': 'Kekeli-HomeCloud-HTTP',
            'port': '80',
            'protocol': 'TCP',
            'description': 'Allow HTTP access to Kekeli-HomeCloud Nextcloud'
        },
        {
            'name': 'Kekeli-HomeCloud-HTTPS',
            'port': '443',
            'protocol': 'TCP',
            'description': 'Allow HTTPS access to Kekeli-HomeCloud Nextcloud'
        },
        {
            'name': 'Kekeli-HomeCloud-Custom',
            'port': '8080',
            'protocol': 'TCP',
            'description': 'Allow custom port access to Kekeli-HomeCloud Nextcloud'
        }
    ]

    success_count = 0

    for rule in firewall_rules:
        try:
            # Check if rule already exists
            check_cmd = [
                'powershell', '-Command',
                f'Get-NetFirewallRule -DisplayName "{rule["name"]}" -ErrorAction SilentlyContinue'
            ]

            check_result = subprocess.run(check_cmd, capture_output=True, timeout=10)

            if check_result.returncode == 0 and check_result.stdout.strip():
                print_status("info", f"Firewall rule already exists: {rule['name']}")
                success_count += 1
                continue

            # Create new firewall rule
            create_cmd = [
                'powershell', '-Command',
                f'''New-NetFirewallRule -DisplayName "{rule["name"]}" -Direction Inbound -Protocol {rule["protocol"]} -LocalPort {rule["port"]} -Action Allow -Profile Domain,Private -Description "{rule["description"]}"'''
            ]

            create_result = subprocess.run(create_cmd, capture_output=True, timeout=15)

            if create_result.returncode == 0:
                print_status("pass", f"Firewall rule created: {rule['name']} (port {rule['port']})")
                success_count += 1
            else:
                print_status("fail", f"Failed to create firewall rule: {rule['name']}")

        except Exception as e:
            print_status("fail", f"Error creating firewall rule {rule['name']}: {e}")

    if success_count == len(firewall_rules):
        print_status("pass", "Windows Firewall configuration completed")
        return True
    elif success_count > 0:
        print_status("warn", f"Partial firewall configuration ({success_count}/{len(firewall_rules)} rules)")
        return True
    else:
        print_status("fail", "Firewall configuration failed")
        return False

def test_port_accessibility(port, timeout=5):
    """Test if a port is accessible locally"""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        result = sock.connect_ex(('localhost', port))
        sock.close()
        return result == 0
    except:
        return False

def generate_qr_code_data(ip_address, port=8080):
    """Generate QR code data for mobile device setup"""
    nextcloud_url = f"http://{ip_address}:{port}"

    qr_data = {
        'url': nextcloud_url,
        'ip_address': ip_address,
        'port': port,
        'platform': 'windows',
        'setup_instructions': [
            f"1. Connect your mobile device to the same WiFi network",
            f"2. Open your mobile browser",
            f"3. Visit: {nextcloud_url}",
            f"4. Install the Nextcloud mobile app from your app store",
            f"5. Configure the app with server URL: {nextcloud_url}"
        ]
    }

    return qr_data

def create_mobile_setup_guide(network_config):
    """Create HTML mobile setup guide"""
    print_status("progress", "Creating mobile setup guide...")

    try:
        config_dir = Path.home() / '.kekeli-homecloud'
        config_dir.mkdir(exist_ok=True)

        setup_guide_file = config_dir / 'mobile_setup.html'

        # Get primary IP address
        primary_ip = network_config['interfaces'][0]['ip_address'] if network_config['interfaces'] else 'localhost'

        html_content = f"""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Kekeli-HomeCloud Mobile Setup</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }}
        .container {{ max-width: 600px; margin: 0 auto; background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
        .header {{ text-align: center; color: #0082c9; margin-bottom: 30px; }}
        .step {{ margin: 20px 0; padding: 15px; background: #f8f9fa; border-left: 4px solid #0082c9; }}
        .url {{ background: #e3f2fd; padding: 10px; border-radius: 5px; font-family: monospace; word-break: break-all; }}
        .warning {{ background: #fff3cd; border-left: 4px solid #ffc107; padding: 10px; margin: 15px 0; }}
        .success {{ background: #d4edda; border-left: 4px solid #28a745; padding: 10px; margin: 15px 0; }}
        .network-info {{ background: #e8f4f8; padding: 15px; border-radius: 5px; margin: 15px 0; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🏠 Kekeli-HomeCloud</h1>
            <h2>Mobile Device Setup Guide</h2>
        </div>

        <div class="network-info">
            <h3>📡 Network Information</h3>
            <p><strong>Server IP:</strong> {primary_ip}</p>
            <p><strong>Access URL:</strong> <span class="url">http://{primary_ip}:8080</span></p>
            <p><strong>Network:</strong> {network_config.get('network_range', 'Local Network')}</p>
        </div>

        <div class="step">
            <h3>📱 Step 1: Connect to WiFi</h3>
            <p>Ensure your mobile device is connected to the same WiFi network as this computer.</p>
        </div>

        <div class="step">
            <h3>🌐 Step 2: Test Web Access</h3>
            <p>Open your mobile browser and visit:</p>
            <div class="url">http://{primary_ip}:8080</div>
            <p>You should see the Nextcloud login page.</p>
        </div>

        <div class="step">
            <h3>📲 Step 3: Install Nextcloud App</h3>
            <p>Download the official Nextcloud app:</p>
            <ul>
                <li><strong>Android:</strong> Google Play Store → "Nextcloud"</li>
                <li><strong>iPhone:</strong> App Store → "Nextcloud"</li>
            </ul>
        </div>

        <div class="step">
            <h3>⚙️ Step 4: Configure App</h3>
            <p>In the Nextcloud app:</p>
            <ol>
                <li>Enter server URL: <span class="url">http://{primary_ip}:8080</span></li>
                <li>Enter your username and password</li>
                <li>Complete the setup wizard</li>
            </ol>
        </div>

        <div class="warning">
            <h4>⚠️ Troubleshooting</h4>
            <p>If you can't connect:</p>
            <ul>
                <li>Check that both devices are on the same WiFi network</li>
                <li>Try turning Windows Firewall off temporarily</li>
                <li>Ensure Nextcloud container is running</li>
                <li>Try accessing from computer first: <span class="url">http://localhost:8080</span></li>
            </ul>
        </div>

        <div class="success">
            <h4>✅ Success!</h4>
            <p>Once connected, you can:</p>
            <ul>
                <li>Upload and download files</li>
                <li>Sync photos automatically</li>
                <li>Share files with others</li>
                <li>Access your files from anywhere on your network</li>
            </ul>
        </div>

        <div style="text-align: center; margin-top: 30px; color: #666;">
            <p>Generated by Kekeli-HomeCloud Installer</p>
            <p>Platform: Windows | Generated at: {Path().resolve()}</p>
        </div>
    </div>
</body>
</html>
"""

        with open(setup_guide_file, 'w', encoding='utf-8') as f:
            f.write(html_content)

        print_status("pass", f"Mobile setup guide created: {setup_guide_file}")
        return str(setup_guide_file)

    except Exception as e:
        print_status("fail", f"Could not create mobile setup guide: {e}")
        return None

def save_network_config(network_config):
    """Save network configuration to file"""
    try:
        config_dir = Path.home() / '.kekeli-homecloud'
        config_dir.mkdir(exist_ok=True)

        network_config_file = config_dir / 'network.json'

        with open(network_config_file, 'w') as f:
            json.dump(network_config, f, indent=2)

        print_status("pass", f"Network configuration saved: {network_config_file}")
        return True

    except Exception as e:
        print_status("fail", f"Could not save network configuration: {e}")
        return False

def main():
    """Main networking setup function"""
    print(f"{Colors.BLUE}🌐 Kekeli-HomeCloud Windows Networking Setup{Colors.NC}")
    print(f"{Colors.BLUE}============================================={Colors.NC}")
    print()

    # Detect network interfaces
    interfaces = get_network_interfaces()

    if not interfaces:
        print_status("fail", "No network interfaces detected")
        return False

    print_status("pass", f"Detected {len(interfaces)} network interfaces")

    # Display detected interfaces
    for i, iface in enumerate(interfaces, 1):
        network_range = calculate_network_range(iface['ip_address'], iface['prefix_length'])
        print_status("info", f"Interface {i}: {iface['interface_name']} - {iface['ip_address']} ({network_range})")

    # Get default gateway
    gateway = get_default_gateway()
    if gateway:
        print_status("pass", f"Default gateway: {gateway}")
    else:
        print_status("warn", "Could not detect default gateway")

    # Configure Windows Firewall
    if not configure_windows_firewall():
        print_status("warn", "Firewall configuration had issues, but continuing...")

    # Prepare network configuration
    primary_interface = interfaces[0]  # Use first interface as primary
    network_config = {
        'interfaces': interfaces,
        'primary_ip': primary_interface['ip_address'],
        'primary_interface': primary_interface['interface_name'],
        'gateway': gateway,
        'network_range': calculate_network_range(primary_interface['ip_address'], primary_interface['prefix_length']),
        'platform': 'windows'
    }

    # Generate QR code data for mobile setup
    qr_data = generate_qr_code_data(primary_interface['ip_address'])
    network_config['mobile_setup'] = qr_data

    # Create mobile setup guide
    setup_guide_path = create_mobile_setup_guide(network_config)
    if setup_guide_path:
        network_config['setup_guide_path'] = setup_guide_path

    # Save network configuration
    if not save_network_config(network_config):
        print_status("warn", "Could not save network configuration")

    # Success summary
    print()
    print_status("pass", "Network setup completed successfully!")
    print()
    print(f"{Colors.CYAN}Network Configuration Summary:{Colors.NC}")
    print(f"  Primary IP: {network_config['primary_ip']}")
    print(f"  Network Range: {network_config['network_range']}")
    print(f"  Interface: {network_config['primary_interface']}")
    if gateway:
        print(f"  Gateway: {gateway}")
    print()
    print(f"{Colors.CYAN}Nextcloud Access URLs:{Colors.NC}")
    print(f"  Local: http://localhost:8080")
    print(f"  Network: http://{network_config['primary_ip']}:8080")
    print()
    print(f"{Colors.CYAN}Mobile Setup:{Colors.NC}")
    if setup_guide_path:
        print(f"  Setup Guide: {setup_guide_path}")
    print(f"  Mobile URL: {qr_data['url']}")
    print()
    print(f"{Colors.CYAN}Next steps:{Colors.NC}")
    print(f"  1. Network configuration is complete")
    print(f"  2. Run: python scripts/windows/setup_nextcloud.py")
    print(f"  3. Use mobile setup guide to connect devices")

    return True

if __name__ == "__main__":
    try:
        success = main()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print()
        print_status("info", "Network setup cancelled by user")
        sys.exit(1)
    except Exception as e:
        print()
        print_status("fail", f"Unexpected error: {e}")
        sys.exit(1)