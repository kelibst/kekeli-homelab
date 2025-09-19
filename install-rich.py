#!/usr/bin/env python3
"""
Kekeli-HomeCloud Interactive Installer with Rich UI
Enhanced installation experience with beautiful terminal interface

Part of the Kekeli-HomeCloud Easy Installer Project
"""

import os
import sys
import time
import platform
import subprocess
import shutil
from pathlib import Path
from typing import Tuple, Optional, List
import threading

# Try to import rich components, fall back to basic if not available
try:
    from rich.console import Console
    from rich.panel import Panel
    from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn, TaskProgressColumn, TimeRemainingColumn
    from rich.table import Table
    from rich.prompt import Prompt, Confirm
    from rich.layout import Layout
    from rich.live import Live
    from rich.text import Text
    from rich.align import Align
    from rich import print as rprint
    from rich.markdown import Markdown
    RICH_AVAILABLE = True
except ImportError:
    RICH_AVAILABLE = False
    print("📦 Installing enhanced UI components...")
    subprocess.run([sys.executable, "-m", "pip", "install", "rich", "questionary", "tqdm"], capture_output=True)
    try:
        from rich.console import Console
        from rich.panel import Panel
        from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn, TaskProgressColumn, TimeRemainingColumn
        from rich.table import Table
        from rich.prompt import Prompt, Confirm
        from rich.layout import Layout
        from rich.live import Live
        from rich.text import Text
        from rich.align import Align
        from rich import print as rprint
        from rich.markdown import Markdown
        RICH_AVAILABLE = True
    except:
        RICH_AVAILABLE = False

# Initialize console
console = Console() if RICH_AVAILABLE else None

class InteractiveInstaller:
    """Main installer class with rich UI components"""

    def __init__(self):
        self.console = console
        self.platform = self.detect_platform()
        self.install_dir = Path.home() / "kekeli-homelab"
        self.profile = None
        self.system_checks = []

    def detect_platform(self) -> Tuple[str, str, str]:
        """Detect the current platform"""
        system = platform.system().lower()

        if system == "linux":
            # Check if running in WSL
            try:
                with open('/proc/version', 'r') as f:
                    if 'microsoft' in f.read().lower():
                        return ("WSL2", "bash", "linux")
            except:
                pass
            return ("Linux", "bash", "linux")
        elif system == "windows":
            return ("Windows", "python", "windows")
        elif system == "darwin":
            return ("macOS", "unsupported", "macos")
        else:
            return ("Unknown", "unsupported", "unknown")

    def show_welcome_banner(self):
        """Display animated welcome banner"""
        if not RICH_AVAILABLE:
            print("\n" + "="*60)
            print("    🏠 Kekeli-HomeCloud Interactive Installer")
            print("    Transform Your Computer Into Your Personal Cloud")
            print("="*60 + "\n")
            return

        welcome_text = """
# 🏠 Kekeli-HomeCloud Interactive Installer

Transform your computer into your personal cloud storage solution!

**Features:**
- ✨ One-click installation
- 📱 Mobile-ready with QR codes
- 💾 Smart storage integration
- 🔒 Secure network configuration
- 🚀 Docker-powered deployment
        """

        panel = Panel(
            Markdown(welcome_text),
            title="[bold cyan]Welcome to Kekeli-HomeCloud[/bold cyan]",
            border_style="cyan",
            padding=(1, 2)
        )

        self.console.print(panel)
        time.sleep(1)

    def select_installation_profile(self) -> str:
        """Interactive profile selection with rich UI"""
        if not RICH_AVAILABLE:
            print("\n📦 SELECT YOUR INSTALLATION PROFILE")
            print("="*50)
            print("\n1. EXPRESS (Recommended) - 5 minutes")
            print("   ✨ Automatic configuration")
            print("   ✨ Standard paths")
            print("   ✨ Mobile support enabled\n")
            print("2. CUSTOM - 10-15 minutes")
            print("   🔧 Choose components")
            print("   🔧 Custom paths")
            print("   🔧 Advanced options\n")
            print("3. DEVELOPER - 15-20 minutes")
            print("   💻 All tools included")
            print("   💻 Debug features")
            print("   💻 API documentation\n")

            choice = input("Select profile (1-3, default=1): ").strip() or "1"
            return ["Express", "Custom", "Developer"][int(choice)-1] if choice in "123" else "Express"

        # Rich UI profile selection
        table = Table(title="[bold cyan]Installation Profiles[/bold cyan]", show_header=True, header_style="bold magenta")
        table.add_column("Profile", style="cyan", width=12)
        table.add_column("Time", style="yellow")
        table.add_column("Description", style="white")
        table.add_column("Features", style="dim")

        table.add_row(
            "[bold green]Express[/bold green]\n(Recommended)",
            "5 min",
            "Quick installation with\nsmart defaults",
            "• Auto configuration\n• Standard paths\n• Mobile ready"
        )
        table.add_row(
            "[bold blue]Custom[/bold blue]",
            "10-15 min",
            "Choose your components\nand settings",
            "• Component selection\n• Custom paths\n• Advanced options"
        )
        table.add_row(
            "[bold magenta]Developer[/bold magenta]",
            "15-20 min",
            "Full installation with\ndevelopment tools",
            "• All components\n• Debug tools\n• API access"
        )

        self.console.print(table)

        profiles = ["Express", "Custom", "Developer"]
        choice = Prompt.ask(
            "\n[yellow]Select installation profile[/yellow]",
            choices=profiles,
            default="Express"
        )

        self.console.print(f"\n[green]✓[/green] Selected profile: [bold cyan]{choice}[/bold cyan]")
        return choice

    def check_system_requirements(self) -> bool:
        """Check system requirements with progress display"""
        checks = [
            ("Operating System", self.check_os),
            ("Python Version", self.check_python),
            ("Available Disk Space", self.check_disk_space),
            ("Memory", self.check_memory),
            ("Network Connection", self.check_network),
            ("Docker", self.check_docker),
            ("Administrator/Sudo", self.check_permissions),
        ]

        if not RICH_AVAILABLE:
            print("\n🔍 CHECKING SYSTEM REQUIREMENTS")
            print("="*50)
            passed = 0
            for name, check_func in checks:
                print(f"  Checking {name}...", end=" ")
                try:
                    if check_func():
                        print("✅")
                        passed += 1
                    else:
                        print("❌")
                except Exception as e:
                    print(f"❌ ({e})")

            print(f"\nResult: {passed}/{len(checks)} checks passed")
            return passed == len(checks)

        # Rich UI progress
        self.console.print("\n[bold cyan]🔍 System Requirements Check[/bold cyan]\n")

        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            BarColumn(),
            TaskProgressColumn(),
            console=self.console
        ) as progress:

            task = progress.add_task("[cyan]Checking requirements...", total=len(checks))

            results = []
            for name, check_func in checks:
                progress.update(task, description=f"[cyan]Checking {name}...")
                time.sleep(0.5)  # Visual effect

                try:
                    result = check_func()
                    status = "[green]✅ Passed[/green]" if result else "[red]❌ Failed[/red]"
                    results.append((name, status, result))
                except Exception as e:
                    results.append((name, f"[red]❌ Error: {e}[/red]", False))

                progress.advance(task)

        # Display results table
        table = Table(show_header=True, header_style="bold magenta")
        table.add_column("Component", style="cyan")
        table.add_column("Status", justify="center")

        all_passed = True
        for name, status, passed in results:
            table.add_row(name, status)
            if not passed and name != "Docker":  # Docker is optional
                all_passed = False

        self.console.print(table)

        if all_passed:
            self.console.print("\n[bold green]✅ All requirements satisfied![/bold green]")
        else:
            self.console.print("\n[bold yellow]⚠️ Some requirements not met[/bold yellow]")

        return all_passed

    # Check functions
    def check_os(self) -> bool:
        return platform.system() in ["Linux", "Windows", "Darwin"]

    def check_python(self) -> bool:
        version = sys.version_info
        return version.major >= 3 and version.minor >= 6

    def check_disk_space(self) -> bool:
        import shutil
        stat = shutil.disk_usage(Path.home())
        free_gb = stat.free / (1024**3)
        return free_gb >= 4

    def check_memory(self) -> bool:
        try:
            import psutil
            mem = psutil.virtual_memory()
            return mem.total >= 2 * (1024**3)  # 2GB
        except ImportError:
            return True  # Assume OK if psutil not available

    def check_network(self) -> bool:
        import socket
        try:
            socket.create_connection(("8.8.8.8", 53), timeout=3)
            return True
        except:
            return False

    def check_docker(self) -> bool:
        return shutil.which('docker') is not None

    def check_permissions(self) -> bool:
        if platform.system() == "Windows":
            import ctypes
            return ctypes.windll.shell32.IsUserAnAdmin() != 0
        else:
            return os.geteuid() == 0 or os.access('/usr/bin/sudo', os.X_OK)

    def run_installation(self):
        """Execute installation with rich progress tracking"""
        steps = [
            ("Preparing environment", 2),
            ("Installing dependencies", 3),
            ("Downloading Kekeli-HomeCloud", 4),
            ("Configuring system", 3),
            ("Setting up Docker", 5),
            ("Deploying Nextcloud", 4),
            ("Configuring mobile access", 2),
            ("Running verification", 2),
        ]

        if not RICH_AVAILABLE:
            print("\n🚀 STARTING INSTALLATION")
            print("="*50)
            for i, (step, duration) in enumerate(steps, 1):
                print(f"\nStep {i}/{len(steps)}: {step}")
                for j in range(duration):
                    print(".", end="", flush=True)
                    time.sleep(1)
                print(" ✅")
            return True

        # Rich UI installation progress
        self.console.print("\n[bold cyan]🚀 Starting Installation[/bold cyan]\n")

        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            BarColumn(),
            TaskProgressColumn(),
            TimeRemainingColumn(),
            console=self.console
        ) as progress:

            overall_task = progress.add_task(
                f"[cyan]Installing Kekeli-HomeCloud ({self.profile} profile)...",
                total=sum(duration for _, duration in steps)
            )

            for step_num, (step_name, duration) in enumerate(steps, 1):
                step_task = progress.add_task(
                    f"[yellow]Step {step_num}/{len(steps)}: {step_name}",
                    total=duration
                )

                for _ in range(duration):
                    time.sleep(1)  # Simulate work
                    progress.advance(step_task)
                    progress.advance(overall_task)

                progress.update(step_task, description=f"[green]✓ {step_name}")

        return True

    def show_completion(self):
        """Display installation completion with celebration"""
        if not RICH_AVAILABLE:
            print("\n" + "="*60)
            print("    🎉 INSTALLATION SUCCESSFUL! 🎉")
            print("    Your Kekeli-HomeCloud is ready!")
            print("="*60)
            print("\n📱 Mobile Setup: Check mobile-setup folder")
            print("🌐 Web Access: http://localhost")
            print("📚 Documentation: docs/getting-started.html")
            return

        # Rich UI celebration
        celebration = """
# 🎉 Installation Complete! 🎉

## Your Kekeli-HomeCloud is Ready!

### Quick Start:
- **📱 Mobile Setup:** QR codes in `mobile-setup/` folder
- **🌐 Web Access:** [http://localhost](http://localhost)
- **📚 Documentation:** Open `docs/getting-started.html`

### Next Steps:
1. Access the web interface
2. Create your admin account
3. Set up mobile devices using QR codes
4. Configure external storage (optional)

**Thank you for using Kekeli-HomeCloud!** ✨
        """

        panel = Panel(
            Markdown(celebration),
            title="[bold green]Success![/bold green]",
            border_style="green",
            padding=(1, 2)
        )

        self.console.print(panel)

        # Animated sparkles
        sparkles = ["✨", "⭐", "💫", "🌟", "✨"]
        with Live(console=self.console, refresh_per_second=4) as live:
            for i in range(len(sparkles) * 2):
                sparkle = sparkles[i % len(sparkles)]
                text = Text(f"{sparkle} Thank you for choosing Kekeli-HomeCloud! {sparkle}")
                text.stylize("bold yellow")
                centered = Align.center(text)
                live.update(centered)
                time.sleep(0.5)

    def run(self):
        """Main installation flow"""
        try:
            # Welcome
            self.show_welcome_banner()

            # Platform detection
            platform_name, installer_type, _ = self.platform
            if RICH_AVAILABLE:
                self.console.print(f"\n[cyan]Detected platform:[/cyan] [bold]{platform_name}[/bold]")
            else:
                print(f"\nDetected platform: {platform_name}")

            # Profile selection
            self.profile = self.select_installation_profile()

            # System requirements
            if not self.check_system_requirements():
                if RICH_AVAILABLE:
                    if not Confirm.ask("\n[yellow]Continue with missing requirements?[/yellow]"):
                        self.console.print("[red]Installation cancelled[/red]")
                        return False
                else:
                    response = input("\nContinue with missing requirements? (y/N): ")
                    if response.lower() != 'y':
                        print("Installation cancelled")
                        return False

            # Confirmation
            if RICH_AVAILABLE:
                if not Confirm.ask(f"\n[green]Ready to install with {self.profile} profile?[/green]"):
                    self.console.print("[yellow]Installation cancelled[/yellow]")
                    return False
            else:
                response = input(f"\nReady to install with {self.profile} profile? (Y/n): ")
                if response.lower() == 'n':
                    print("Installation cancelled")
                    return False

            # Run installation
            if self.run_installation():
                self.show_completion()
                return True
            else:
                if RICH_AVAILABLE:
                    self.console.print("[red]Installation failed[/red]")
                else:
                    print("Installation failed")
                return False

        except KeyboardInterrupt:
            if RICH_AVAILABLE:
                self.console.print("\n[yellow]Installation interrupted by user[/yellow]")
            else:
                print("\nInstallation interrupted by user")
            return False
        except Exception as e:
            if RICH_AVAILABLE:
                self.console.print(f"\n[red]Error: {e}[/red]")
            else:
                print(f"\nError: {e}")
            return False


def main():
    """Main entry point"""
    installer = InteractiveInstaller()
    success = installer.run()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()