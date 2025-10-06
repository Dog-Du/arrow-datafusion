#!/usr/bin/env bash
# Coredump analysis helper script
# Usage: ./analyze_crash.sh [list|debug <core_file>|latest|clean]

set -e

# Color definitions
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

COREDUMP_DIR=${COREDUMP_DIR:-/var/coredumps}
BINARY_DIR=${BINARY_DIR:-./bin}

print_info() { echo -e "${CYAN}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}${BOLD}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

usage() {
    echo -e "${BLUE}${BOLD}Coredump Analysis Helper${NC}"
    echo ""
    echo -e "${YELLOW}Usage:${NC}"
    echo "  $0 list                    - List all coredump files"
    echo "  $0 info <id|file>          - Show detailed info about a coredump"
    echo "  $0 debug <id|file>         - Start GDB debugging session"
    echo "  $0 latest                  - Debug the latest coredump"
    echo "  $0 bt <id|file>            - Show backtrace only"
    echo "  $0 clean [days]            - Clean old coredumps (default: all)"
    echo "  $0 help                    - Show this help"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  $0 list                    - List all coredumps with IDs"
    echo "  $0 debug 1                 - Debug coredump #1"
    echo "  $0 debug core.dfbench.123  - Debug specific coredump file"
    echo "  $0 latest                  - Debug most recent crash"
    echo "  $0 bt 1                    - Show backtrace of coredump #1"
    echo "  $0 clean 7                 - Remove coredumps older than 7 days"
    echo ""
    echo -e "${YELLOW}Environment Variables:${NC}"
    echo "  COREDUMP_DIR  - Coredump directory (default: /var/coredumps)"
    echo "  BINARY_DIR    - Binary directory (default: ./bin)"
    echo ""
    exit 0
}

# List all coredumps with numbered IDs
list_coredumps() {
    print_header "📊 Available Coredumps in $COREDUMP_DIR"

    if [ ! -d "$COREDUMP_DIR" ]; then
        print_error "Coredump directory not found: $COREDUMP_DIR"
        exit 1
    fi

    local cores=($(ls -t "$COREDUMP_DIR"/core.* 2>/dev/null || true))

    if [ ${#cores[@]} -eq 0 ]; then
        print_warning "No coredumps found"
        echo ""
        print_info "Tip: Run 'ulimit -c unlimited' before running your program"
        return 1
    fi

    echo ""
    printf "${CYAN}%-4s %-20s %-10s %-12s %-20s${NC}\n" "ID" "Program" "PID" "Size" "Time"
    echo "─────────────────────────────────────────────────────────────────────────"

    local id=1
    for core in "${cores[@]}"; do
        local filename=$(basename "$core")
        local size=$(ls -lh "$core" | awk '{print $5}')
        local mtime=$(stat -c %y "$core" | cut -d'.' -f1)

        # Parse filename: core.<program>.<pid>.<timestamp>
        local program=$(echo "$filename" | cut -d'.' -f2)
        local pid=$(echo "$filename" | cut -d'.' -f3)

        printf "%-4s %-20s %-10s %-12s %-20s\n" "$id" "$program" "$pid" "$size" "$mtime"
        ((id++))
    done

    echo ""
    print_info "Total: ${#cores[@]} coredump(s)"
    echo ""
    print_info "Use: $0 debug <ID> to analyze"
}

# Get coredump file by ID or filename
get_coredump_file() {
    local input="$1"

    if [ -z "$input" ]; then
        print_error "No coredump specified"
        return 1
    fi

    # If it's a number (ID)
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        local cores=($(ls -t "$COREDUMP_DIR"/core.* 2>/dev/null || true))
        local idx=$((input - 1))

        if [ $idx -lt 0 ] || [ $idx -ge ${#cores[@]} ]; then
            print_error "Invalid ID: $input (valid range: 1-${#cores[@]})"
            return 1
        fi

        echo "${cores[$idx]}"
    # If it's a filename
    elif [ -f "$COREDUMP_DIR/$input" ]; then
        echo "$COREDUMP_DIR/$input"
    elif [ -f "$input" ]; then
        echo "$input"
    else
        print_error "Coredump not found: $input"
        return 1
    fi
}

# Extract program name from coredump filename
get_program_name() {
    local core_file="$1"
    local filename=$(basename "$core_file")
    echo "$filename" | cut -d'.' -f2
}

# Find binary for the program
find_binary() {
    local program="$1"

    # Try common locations
    local locations=(
        "$BINARY_DIR/$program"
        "./$program"
        "/tmp/$program"
        "$(which $program 2>/dev/null || true)"
    )

    for bin in "${locations[@]}"; do
        if [ -f "$bin" ]; then
            echo "$bin"
            return 0
        fi
    done

    return 1
}

# Show coredump information
show_info() {
    local input="$1"
    local core_file=$(get_coredump_file "$input")

    if [ -z "$core_file" ]; then
        return 1
    fi

    print_header "📋 Coredump Information"

    local filename=$(basename "$core_file")
    local program=$(get_program_name "$core_file")
    local size=$(ls -lh "$core_file" | awk '{print $5}')
    local mtime=$(stat -c %y "$core_file" | cut -d'.' -f1)

    echo ""
    echo -e "${CYAN}File:${NC}      $core_file"
    echo -e "${CYAN}Program:${NC}   $program"
    echo -e "${CYAN}Size:${NC}      $size"
    echo -e "${CYAN}Modified:${NC}  $mtime"

    # Try to get binary
    local binary=$(find_binary "$program" || echo "")
    if [ -n "$binary" ]; then
        echo -e "${CYAN}Binary:${NC}    $binary"
    else
        print_warning "Binary not found for: $program"
    fi

    echo ""

    # Show file command output
    print_info "File information:"
    file "$core_file"
}

# Show backtrace only
show_backtrace() {
    local input="$1"
    local core_file=$(get_coredump_file "$input")

    if [ -z "$core_file" ]; then
        return 1
    fi

    local program=$(get_program_name "$core_file")
    local binary=$(find_binary "$program" || echo "")

    if [ -z "$binary" ]; then
        print_error "Binary not found for: $program"
        print_info "Available locations checked:"
        echo "  - $BINARY_DIR/$program"
        echo "  - ./$program"
        echo "  - /tmp/$program"
        return 1
    fi

    print_header "🔍 Backtrace for $program"
    echo ""

    # Check if rust-gdb exists for Rust programs
    local gdb_cmd="gdb"
    if command -v rust-gdb &> /dev/null && file "$binary" | grep -q "Rust"; then
        gdb_cmd="rust-gdb"
        print_info "Using rust-gdb for Rust binary"
    fi

    $gdb_cmd -batch \
        -ex "set pagination off" \
        -ex "thread apply all bt" \
        -ex "quit" \
        "$binary" "$core_file" 2>/dev/null
}

# Start interactive debugging session
debug_coredump() {
    local input="$1"
    local core_file=$(get_coredump_file "$input")

    if [ -z "$core_file" ]; then
        return 1
    fi

    local program=$(get_program_name "$core_file")
    local binary=$(find_binary "$program" || echo "")

    if [ -z "$binary" ]; then
        print_error "Binary not found for: $program"
        print_info "Please specify binary manually:"
        echo "  gdb <binary> $core_file"
        return 1
    fi

    print_header "🐛 Debugging $program"
    echo ""
    echo -e "${CYAN}Coredump:${NC} $core_file"
    echo -e "${CYAN}Binary:${NC}   $binary"
    echo ""

    # Check if rust-gdb exists for Rust programs
    local gdb_cmd="gdb"
    if command -v rust-gdb &> /dev/null && file "$binary" | grep -q "Rust"; then
        gdb_cmd="rust-gdb"
        print_info "Using rust-gdb for Rust binary"
        echo ""
    fi

    print_info "GDB Quick Reference:"
    echo "  bt           - Show backtrace"
    echo "  bt full      - Show backtrace with local variables"
    echo "  info threads - List all threads"
    echo "  thread N     - Switch to thread N"
    echo "  frame N      - Switch to frame N"
    echo "  list         - Show source code"
    echo "  print VAR    - Print variable value"
    echo "  info locals  - Show local variables"
    echo "  quit         - Exit GDB"
    echo ""

    $gdb_cmd "$binary" "$core_file"
}

# Debug latest coredump
debug_latest() {
    local cores=($(ls -t "$COREDUMP_DIR"/core.* 2>/dev/null || true))

    if [ ${#cores[@]} -eq 0 ]; then
        print_error "No coredumps found"
        return 1
    fi

    local latest="${cores[0]}"
    print_info "Debugging latest coredump: $(basename $latest)"
    echo ""

    debug_coredump "$latest"
}

# Clean old coredumps
clean_coredumps() {
    local days="$1"

    if [ -z "$days" ]; then
        # Clean all
        print_warning "This will delete ALL coredumps in $COREDUMP_DIR"
        read -p "Are you sure? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            print_info "Cancelled"
            return 0
        fi

        sudo rm -f "$COREDUMP_DIR"/core.* 2>/dev/null || true
        print_success "All coredumps deleted"
    else
        # Clean older than N days
        print_info "Deleting coredumps older than $days days..."
        local count=$(find "$COREDUMP_DIR" -name "core.*" -mtime +$days 2>/dev/null | wc -l)
        sudo find "$COREDUMP_DIR" -name "core.*" -mtime +$days -delete 2>/dev/null || true
        print_success "Deleted $count coredump(s)"
    fi
}

# Main command dispatcher
main() {
    local cmd="${1:-list}"
    shift || true

    case "$cmd" in
        list|ls)
            list_coredumps
            ;;
        info)
            show_info "$1"
            ;;
        debug|gdb)
            debug_coredump "$1"
            ;;
        latest|last)
            debug_latest
            ;;
        bt|backtrace)
            show_backtrace "$1"
            ;;
        clean)
            clean_coredumps "$1"
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            print_error "Unknown command: $cmd"
            echo ""
            usage
            ;;
    esac
}

main "$@"
