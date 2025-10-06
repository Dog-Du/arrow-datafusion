#!/usr/bin/env bash
# Fix WSL2 coredump issue: "PID 1 having crashed" problem

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info() { echo -e "${CYAN}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_header "🔧 Fix WSL2 Coredump Issue"

echo ""
print_error "Detected issue: systemd-coredump disabled due to 'PID 1 crashed'"
print_info "This is a known WSL2 issue. We'll use an alternative approach."

echo ""
print_info "Solution: Configure manual core dump to file instead of systemd-coredump"

# 1. Create coredump directory first
echo ""
print_info "Step 1: Creating coredump directory..."
sudo mkdir -p /var/coredumps
sudo chmod 1777 /var/coredumps  # Sticky bit + world writable
print_success "Coredump directory created at /var/coredumps"

# 2. Set core_pattern to write files directly
echo ""
print_info "Step 2: Configuring core_pattern to write files directly..."
sudo mkdir -p /etc/sysctl.d/
echo "kernel.core_pattern=/var/coredumps/core.%e.%p.%t" | sudo tee /etc/sysctl.d/50-coredump.conf > /dev/null
echo "/var/coredumps/core.%e.%p.%t" | sudo tee /proc/sys/kernel/core_pattern > /dev/null
print_success "Core pattern set to: /var/coredumps/core.%e.%p.%t"
echo "  %e = executable name"
echo "  %p = PID"
echo "  %t = timestamp"

# 3. Set ulimit
echo ""
print_info "Step 3: Configuring unlimited core file size..."
sudo sed -i '/^.*core.*unlimited/d' /etc/security/limits.conf 2>/dev/null || true
echo "* soft core unlimited" | sudo tee -a /etc/security/limits.conf > /dev/null
echo "* hard core unlimited" | sudo tee -a /etc/security/limits.conf > /dev/null

# Set for systemd
sudo mkdir -p /etc/systemd/system.conf.d/
sudo tee /etc/systemd/system.conf.d/coredump.conf > /dev/null <<EOF
[Manager]
DefaultLimitCORE=infinity
EOF

# Set for current session
ulimit -c unlimited
print_success "Core limits configured"

# 4. Reload systemd
echo ""
print_info "Step 4: Reloading systemd..."
sudo systemctl daemon-reload
sudo sysctl -p /etc/sysctl.d/50-coredump.conf 2>/dev/null || true
print_success "System configuration reloaded"

print_header "📊 Current Configuration"
echo ""
echo "ulimit -c:       $(ulimit -c)"
echo "core_pattern:    $(cat /proc/sys/kernel/core_pattern)"
echo "coredump dir:    /var/coredumps"
echo "permissions:     $(ls -ld /var/coredumps)"

print_header "🧪 Running Test"
echo ""
print_info "Compiling test program..."
cat > /tmp/test_crash.c <<'CEOF'
#include <stdio.h>
#include <unistd.h>
int main() {
    printf("PID: %d\n", getpid());
    printf("Triggering crash...\n");
    int *ptr = NULL;
    *ptr = 42;
    return 0;
}
CEOF

gcc -g /tmp/test_crash.c -o /tmp/test_crash
print_success "Test compiled"

echo ""
print_info "Running test (will crash)..."
cd /var/coredumps
ulimit -c unlimited
/tmp/test_crash 2>&1 || true

echo ""
print_info "Checking for coredump files..."
sleep 1
if ls -lh /var/coredumps/core.* 2>/dev/null; then
    print_success "✨ Coredump captured successfully!"
    echo ""
    LATEST_CORE=$(ls -t /var/coredumps/core.* 2>/dev/null | head -1)
    if [ -n "$LATEST_CORE" ]; then
        print_info "Latest coredump: $LATEST_CORE"
        SIZE=$(ls -lh "$LATEST_CORE" | awk '{print $5}')
        print_info "Size: $SIZE"
    fi
else
    print_error "No coredump found"
fi

print_header "📖 Usage Instructions"
echo ""
cat <<'EOF'
Coredumps will now be saved to /var/coredumps/

File naming: core.<program>.<pid>.<timestamp>

To analyze a coredump:
  1. Find your coredump:
     ls -lht /var/coredumps/

  2. Analyze with gdb:
     gdb <binary> <coredump-file>

     Example:
     gdb ./test_crash /var/coredumps/core.test_crash.12345.1234567890

  3. For Rust programs (like dfbench):
     rust-gdb ./bin/dfbench /var/coredumps/core.dfbench.12345.1234567890

  4. Useful gdb commands:
     bt              - Show backtrace
     bt full         - Backtrace with variables
     info threads    - Show all threads
     thread <N>      - Switch to thread N
     frame <N>       - Switch to frame N
     print <var>     - Print variable
     info locals     - Show local variables

  5. Clean old coredumps:
     sudo rm /var/coredumps/core.*
     # Or keep only recent ones:
     sudo find /var/coredumps -name "core.*" -mtime +7 -delete

IMPORTANT: Before running benchmarks, set ulimit:
  ulimit -c unlimited && ./your_benchmark
EOF

echo ""
print_success "Setup complete! Core dumps will be saved to /var/coredumps/"
print_warning "Remember to run 'ulimit -c unlimited' in each new shell session"
print_info "Or add it to your ~/.bashrc: echo 'ulimit -c unlimited' >> ~/.bashrc"
