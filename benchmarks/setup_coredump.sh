#!/usr/bin/env bash
# Setup script for coredump capture and analysis
# Installs and configures systemd-coredump (coredumpctl) for debugging crashes

set -e

# Color definitions
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        print_error "Cannot detect OS"
        exit 1
    fi
}

# Install systemd-coredump and debugging tools
install_coredump_tools() {
    print_header "🔧 Installing Coredump Tools"

    detect_os
    print_info "Detected OS: $OS $VERSION"

    case "$OS" in
        ubuntu|debian)
            print_info "Installing systemd-coredump and gdb on Ubuntu/Debian..."
            sudo apt-get update -qq
            sudo apt-get install -y systemd-coredump gdb binutils
            ;;
        centos|rhel|fedora)
            print_info "Installing systemd-coredump and gdb on CentOS/RHEL/Fedora..."
            sudo yum install -y systemd-coredump gdb binutils
            ;;
        arch)
            print_info "Installing systemd-coredump and gdb on Arch Linux..."
            sudo pacman -Sy --noconfirm systemd gdb binutils
            ;;
        *)
            print_error "Unsupported OS: $OS"
            print_info "Please install systemd-coredump and gdb manually"
            exit 1
            ;;
    esac

    print_success "Coredump tools installed successfully"
}

# Configure coredump settings
configure_coredump() {
    print_header "⚙️  Configuring Coredump Settings"

    # Enable systemd-coredump
    print_info "Enabling systemd-coredump service..."

    # Configure unlimited core file size
    print_info "Setting unlimited core file size..."
    echo "* soft core unlimited" | sudo tee -a /etc/security/limits.conf > /dev/null
    echo "* hard core unlimited" | sudo tee -a /etc/security/limits.conf > /dev/null

    # Set current session limits
    ulimit -c unlimited

    # Configure systemd-coredump storage
    print_info "Configuring coredump storage..."
    sudo mkdir -p /etc/systemd/coredump.conf.d/

    cat <<'EOF' | sudo tee /etc/systemd/coredump.conf.d/custom.conf > /dev/null
[Coredump]
Storage=external
Compress=yes
ProcessSizeMax=8G
ExternalSizeMax=8G
MaxUse=10G
KeepFree=1G
EOF

    # Reload systemd configuration
    print_info "Reloading systemd configuration..."
    sudo systemctl daemon-reload

    # Enable and start systemd-coredump
    if systemctl list-unit-files | grep -q systemd-coredump; then
        print_info "Starting systemd-coredump socket..."
        sudo systemctl enable systemd-coredump.socket 2>/dev/null || true
        sudo systemctl start systemd-coredump.socket 2>/dev/null || true
    fi

    print_success "Coredump configuration complete"
}

# Display configuration status
show_status() {
    print_header "📊 Coredump Configuration Status"

    echo -e "${CYAN}Current ulimit for core files:${NC}"
    ulimit -c

    echo ""
    echo -e "${CYAN}Systemd coredump configuration:${NC}"
    if [ -f /etc/systemd/coredump.conf.d/custom.conf ]; then
        cat /etc/systemd/coredump.conf.d/custom.conf
    else
        echo "Configuration file not found"
    fi

    echo ""
    echo -e "${CYAN}Systemd-coredump service status:${NC}"
    systemctl status systemd-coredump.socket --no-pager 2>/dev/null || echo "Not running as systemd service"

    echo ""
    echo -e "${CYAN}Available coredumps:${NC}"
    coredumpctl list 2>/dev/null || echo "No coredumps found (or coredumpctl not available)"
}

# Show usage instructions
show_usage() {
    print_header "📖 Coredump Usage Guide"

    cat <<'EOF'
After a crash occurs, you can analyze the coredump using:

1. List all coredumps:
   coredumpctl list

2. Show info about the latest coredump:
   coredumpctl info

3. Show info for a specific PID:
   coredumpctl info <PID>

4. Debug with gdb (latest crash):
   coredumpctl debug

5. Debug specific crash:
   coredumpctl debug <PID>

6. Extract coredump to file:
   coredumpctl dump -o coredump.file

7. View backtrace:
   coredumpctl debug --debugger-arguments="-batch -ex bt -ex quit"

8. For Rust programs (like dfbench), install rust-gdb:
   # On Ubuntu/Debian
   sudo apt-get install rust-gdb

   # Then use:
   coredumpctl debug --debugger=rust-gdb

9. Clean old coredumps:
   sudo coredumpctl clean --keep=5

10. Get detailed crash info with env vars and maps:
    coredumpctl info <PID> --all

Common gdb commands once in debugger:
  bt           - Show backtrace
  bt full      - Show backtrace with local variables
  info threads - Show all threads
  thread <N>   - Switch to thread N
  frame <N>    - Switch to frame N
  print <var>  - Print variable value
  info locals  - Show local variables
  quit         - Exit gdb

EOF

    print_info "Current session core file limit: $(ulimit -c)"
    print_warning "Note: You may need to logout/login for limits to take effect globally"
}

# Create a helper script for analyzing dfbench crashes
create_analysis_script() {
    print_header "📝 Creating Analysis Helper Script"

    cat <<'ANALYSIS_EOF' > analyze_crash.sh
#!/usr/bin/env bash
# Helper script to analyze dfbench crashes

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ -z "$1" ]; then
    echo -e "${CYAN}Available coredumps:${NC}"
    coredumpctl list
    echo ""
    echo -e "${YELLOW}Usage: $0 <PID|latest>${NC}"
    echo "  $0 latest       - Analyze most recent crash"
    echo "  $0 <PID>        - Analyze specific crash by PID"
    exit 1
fi

if [ "$1" = "latest" ]; then
    echo -e "${CYAN}Analyzing latest crash...${NC}"
    PID=$(coredumpctl list --no-legend | tail -1 | awk '{print $5}')
    if [ -z "$PID" ]; then
        echo "No coredumps found"
        exit 1
    fi
else
    PID=$1
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Crash Analysis for PID: $PID${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
echo -e "${GREEN}1. Crash Information:${NC}"
coredumpctl info $PID

echo ""
echo -e "${GREEN}2. Backtrace:${NC}"
coredumpctl debug $PID --debugger-arguments="-batch -ex 'thread apply all bt' -ex quit" 2>/dev/null || echo "GDB analysis failed"

echo ""
echo -e "${GREEN}3. Extract coredump file:${NC}"
DUMP_FILE="coredump_${PID}_$(date +%Y%m%d_%H%M%S).dump"
coredumpctl dump $PID -o "$DUMP_FILE"
echo -e "${GREEN}Coredump saved to: $DUMP_FILE${NC}"

echo ""
echo -e "${YELLOW}To interactively debug:${NC}"
echo "  coredumpctl debug $PID"
echo ""
echo -e "${YELLOW}To debug with rust-gdb:${NC}"
echo "  coredumpctl debug $PID --debugger=rust-gdb"

ANALYSIS_EOF

    chmod +x analyze_crash.sh
    print_success "Created analyze_crash.sh helper script"
    print_info "Usage: ./analyze_crash.sh latest"
}

# Main execution
main() {
    print_header "🚀 Coredump Setup for DataFusion ClickBench"
    echo ""

    # Check if running as root or with sudo
    if [ "$EUID" -eq 0 ]; then
        print_warning "Running as root. Some commands will be executed directly."
        SUDO=""
    else
        SUDO="sudo"
        print_info "This script requires sudo privileges for installation"
    fi

    # Install tools
    install_coredump_tools
    echo ""

    # Configure coredump
    configure_coredump
    echo ""

    # Create analysis helper
    create_analysis_script
    echo ""

    # Show status
    show_status
    echo ""

    # Show usage
    show_usage
    echo ""

    print_success "✨ Setup complete! Coredump capture is now enabled."
    print_info "You may need to logout/login for all settings to take effect"
    print_info "Run your benchmark and crashes will be automatically captured"
}

# Run main function
main
