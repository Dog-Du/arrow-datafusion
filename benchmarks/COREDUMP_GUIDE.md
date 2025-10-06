# Coredump Capture and Analysis Guide

This guide explains how to capture and analyze program crashes (coredumps) for DataFusion benchmarks and other applications.

## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Setup](#setup)
4. [Analyzing Crashes](#analyzing-crashes)
5. [Advanced Usage](#advanced-usage)
6. [Troubleshooting](#troubleshooting)

## Overview

When a program crashes (e.g., segmentation fault, out of memory), the operating system can save a **coredump** - a snapshot of the program's memory at the time of the crash. This coredump can be analyzed with a debugger like GDB to understand what went wrong.

### What's Included

- **`setup_coredump.sh`** - **Recommended:** Full setup with systemd-coredump
- **`fix_coredump.sh`** - Fallback: Direct file dump (use if systemd-coredump fails)
- **`analyze_crash.sh`** - Interactive tool for analyzing coredumps
- **`deploy_coredump.sh`** - Deploy setup to remote servers

### Coredump Methods

**Method 1: systemd-coredump (Recommended)**
- Files managed by systemd in `/var/lib/systemd/coredump/`
- Use `coredumpctl` for analysis
- Automatic compression and cleanup

**Method 2: Direct file dump (Fallback)**
- Files saved to `/var/coredumps/core.<program>.<pid>.<timestamp>`
- Use when systemd-coredump doesn't work (WSL2, etc.)

## Quick Start

### 1. Enable Coredump Capture

**Try systemd-coredump first (recommended):**

```bash
cd benchmarks
./setup_coredump.sh
```

This will:
- ✅ Install systemd-coredump and gdb
- ✅ Configure systemd-coredump storage
- ✅ Set unlimited core file size
- ✅ Enable systemd-coredump service
- ✅ Create analyze_crash.sh helper script

**If systemd-coredump doesn't work, use fallback:**

```bash
./fix_coredump.sh
```

This will:
- ✅ Configure kernel to save coredumps to `/var/coredumps/`
- ✅ Bypass systemd-coredump entirely
- ✅ Run a test crash to verify setup

### 2. Run Your Program

**Important:** Always set `ulimit -c unlimited` before running:

```bash
ulimit -c unlimited
./your_program
```

Or in one line:
```bash
ulimit -c unlimited && ./your_program
```

### 3. Analyze the Crash

```bash
# List all coredumps
./analyze_crash.sh list

# Debug the latest crash
./analyze_crash.sh latest

# Debug by ID
./analyze_crash.sh debug 1
```

## Setup

### Local Setup (Recommended)

**Try systemd-coredump first:**

```bash
./benchmarks/setup_coredump.sh
```

**If you see errors like "PID 1 having crashed", use the fallback:**

```bash
./benchmarks/fix_coredump.sh
```

**Expected output (systemd-coredump):**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔧 Installing Coredump Tools
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
...
✅ Coredump tools installed successfully
✨ Setup complete! Coredump capture is now enabled.
```

**Expected output (fallback):**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔧 Fix WSL2 Coredump Issue
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ℹ️  Step 1: Creating coredump directory...
✅ Coredump directory created at /var/coredumps
...
✨ Coredump captured successfully!
```

### Remote Server Setup

Deploy to a remote server:

```bash
REMOTE_USER=ubuntu REMOTE_HOST=192.168.1.100 ./deploy_coredump.sh
```

### Manual Setup

If you need to set up manually:

```bash
# 1. Create directory
sudo mkdir -p /var/coredumps
sudo chmod 1777 /var/coredumps

# 2. Configure kernel
echo "/var/coredumps/core.%e.%p.%t" | sudo tee /proc/sys/kernel/core_pattern

# 3. Make it permanent
echo "kernel.core_pattern=/var/coredumps/core.%e.%p.%t" | \
  sudo tee /etc/sysctl.d/50-coredump.conf

# 4. Set ulimit
ulimit -c unlimited

# 5. Make ulimit permanent (add to ~/.bashrc)
echo "ulimit -c unlimited" >> ~/.bashrc
```

## Analyzing Crashes

### List All Coredumps

```bash
./analyze_crash.sh list
```

**Example output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Available Coredumps in /var/coredumps
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ID   Program              PID        Size         Time
─────────────────────────────────────────────────────────────────────────
1    dfbench             42315      156M         2025-10-06 16:48:02
2    dfbench             41835      148M         2025-10-06 16:47:04
3    test_crash          40605      48K          2025-10-06 16:42:44

ℹ️  Total: 3 coredump(s)
```

### Show Coredump Information

```bash
./analyze_crash.sh info 1
```

**Output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 Coredump Information
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

File:      /var/coredumps/core.dfbench.42315.1728234567
Program:   dfbench
Size:      156M
Modified:  2025-10-06 16:48:02
Binary:    ./bin/dfbench
```

### Quick Backtrace

View backtrace without entering GDB:

```bash
./analyze_crash.sh bt 1
```

### Interactive Debugging

```bash
# Debug latest crash
./analyze_crash.sh latest

# Debug by ID
./analyze_crash.sh debug 1

# Debug by filename
./analyze_crash.sh debug core.dfbench.42315.1728234567
```

**GDB will start with helpful hints:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🐛 Debugging dfbench
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Coredump: /var/coredumps/core.dfbench.42315.1728234567
Binary:   ./bin/dfbench

ℹ️  GDB Quick Reference:
  bt           - Show backtrace
  bt full      - Show backtrace with local variables
  info threads - List all threads
  thread N     - Switch to thread N
  frame N      - Switch to frame N
  list         - Show source code
  print VAR    - Print variable value
  info locals  - Show local variables
  quit         - Exit GDB

(gdb)
```

### Common GDB Commands

Once in GDB:

```gdb
# Show backtrace (call stack)
bt

# Show backtrace with local variables
bt full

# List all threads
info threads

# Switch to thread 5
thread 5

# Show backtrace for all threads
thread apply all bt

# Switch to frame 3
frame 3

# Show source code around current location
list

# Print a variable
print my_variable

# Show all local variables
info locals

# Show all registers
info registers

# Exit GDB
quit
```

### For Rust Programs

The script automatically detects Rust binaries and uses `rust-gdb` if available:

```bash
# Install rust-gdb (Ubuntu/Debian)
sudo apt-get install rust-gdb

# The script will automatically use it
./analyze_crash.sh debug 1
```

## Advanced Usage

### Environment Variables

**`COREDUMP_DIR`** - Override coredump directory (default: `/var/coredumps`)
```bash
COREDUMP_DIR=/custom/path ./analyze_crash.sh list
```

**`BINARY_DIR`** - Override binary search directory (default: `./bin`)
```bash
BINARY_DIR=/path/to/binaries ./analyze_crash.sh debug 1
```

### Binary Search Order

The script searches for binaries in this order:

1. `$BINARY_DIR/<program>` (default: `./bin/<program>`)
2. `./<program>` (current directory)
3. `/tmp/<program>`
4. `which <program>` (system PATH)

### Clean Old Coredumps

```bash
# Remove all coredumps (will prompt for confirmation)
./analyze_crash.sh clean

# Remove coredumps older than 7 days
./analyze_crash.sh clean 7
```

### Manual GDB Usage

If the script can't find your binary:

```bash
# Find your coredump file
ls -lht /var/coredumps/

# Run GDB manually
gdb /path/to/binary /var/coredumps/core.program.pid.timestamp

# For Rust programs
rust-gdb /path/to/binary /var/coredumps/core.program.pid.timestamp
```

## Troubleshooting

### No Coredumps Generated

**Check ulimit:**
```bash
ulimit -c
```

Should output `unlimited`. If it shows `0`:
```bash
ulimit -c unlimited
```

**Check core_pattern:**
```bash
cat /proc/sys/kernel/core_pattern
```

Should output: `/var/coredumps/core.%e.%p.%t`

If not:
```bash
./fix_coredump.sh
```

**Verify directory permissions:**
```bash
ls -ld /var/coredumps
```

Should show: `drwxrwxrwt` (with sticky bit set)

### Binary Not Found

If the script can't find your binary:

```bash
# Specify binary directory
BINARY_DIR=/path/to/binaries ./analyze_crash.sh debug 1

# Or use GDB directly
gdb /path/to/your/binary /var/coredumps/core.program.pid.timestamp
```

### Coredumps Too Large

Coredumps can be very large (especially for programs using lots of memory).

**Check sizes:**
```bash
du -sh /var/coredumps/*
```

**Clean old ones:**
```bash
./analyze_crash.sh clean 7  # Keep only last 7 days
```

**Limit coredump size (if needed):**
```bash
# Limit to 1GB
ulimit -c 1048576  # Size in KB
```

## Understanding systemd-coredump Issues

### Why We Don't Use systemd-coredump

On some systems (especially WSL2 and certain Linux configurations), `systemd-coredump` may fail with this error:

```
systemd-coredump[38837]: Due to PID 1 having crashed coredump collection will now be turned off.
```

### Diagnostic Process

When troubleshooting coredump issues, here's what we check:

#### 1. Check System Logs

```bash
sudo journalctl -xe --no-pager | grep -i core | tail -20
```

**What this command does:**
- `journalctl -xe` - Show system journal (logs) with full entries (`-x`) and jump to end (`-e`)
- `--no-pager` - Output directly without using a pager
- `grep -i core` - Filter for lines containing "core" (case-insensitive)
- `tail -20` - Show last 20 matching lines

**Why it has output:**
- System logs (`journalctl`) record ALL system events, including:
  - Kernel messages (segfaults)
  - systemd service events
  - systemd-coredump attempts
  - Error messages

**Example output:**
```
Oct 06 16:37:06 backupmachine kernel: test_crash[38836]: segfault at 0 ip 00005ac9514ea13d
Oct 06 16:37:06 backupmachine systemd-coredump[38837]: Due to PID 1 having crashed coredump collection will now be turned off.
```

This shows:
1. The kernel detected a segfault
2. `systemd-coredump` tried to handle it but refused due to "PID 1 crashed" protection

#### 2. Check systemd-coredump Service

```bash
sudo journalctl -u systemd-coredump --no-pager -n 50
```

Shows logs specifically for the `systemd-coredump` service.

**If output is "No entries":**
- systemd-coredump never successfully processed any coredumps
- Confirms it's not working properly

#### 3. Check for Alternative Crash Reporters

```bash
systemctl status apport --no-pager
```

On Ubuntu, `apport` can interfere with coredump collection.

#### 4. Verify systemd-coredump Binary

```bash
ls -la /usr/lib/systemd/systemd-coredump
cat /proc/sys/kernel/core_pattern
```

Checks if the binary exists and if kernel is configured to use it.

### The "PID 1 Crashed" Issue

**What it means:**
- PID 1 is the init process (systemd itself)
- systemd-coredump has a safety mechanism: if it detects PID 1 might have crashed, it disables itself to prevent infinite crash loops
- This is a **false positive** - PID 1 hasn't actually crashed (system is still running)

**Why it happens:**
- WSL2's systemd implementation has quirks
- Certain boot conditions trigger this detection
- systemd-coredump may misinterpret system events

**Solution:**
Instead of fixing systemd-coredump (complex and unreliable), we bypass it entirely and use the kernel's built-in core dump mechanism to write files directly.

### Direct File Approach (Our Solution)

**How it works:**

1. **Kernel `core_pattern`:**
   ```bash
   echo "/var/coredumps/core.%e.%p.%t" > /proc/sys/kernel/core_pattern
   ```
   - `%e` = executable name
   - `%p` = PID
   - `%t` = timestamp

2. **When a crash occurs:**
   - Kernel intercepts the signal (SIGSEGV, SIGABRT, etc.)
   - Writes memory dump directly to file (no systemd-coredump involved)
   - File appears instantly in `/var/coredumps/`

3. **Advantages:**
   - ✅ Works on all Linux systems
   - ✅ No dependencies on systemd-coredump
   - ✅ Simpler and more reliable
   - ✅ Easier to manage (just files)

**Comparison:**

| Method | systemd-coredump | Direct Files |
|--------|------------------|--------------|
| **Setup** | Complex, may fail | Simple |
| **Reliability** | Can break | Always works |
| **Analysis** | `coredumpctl debug` | `gdb binary corefile` |
| **Storage** | `/var/lib/systemd/coredump/` | `/var/coredumps/` |
| **Compression** | Automatic | Manual if needed |
| **WSL2 Support** | ❌ Often broken | ✅ Works |

## Example Workflow

### Complete Example: Debug a ClickBench Crash

```bash
# 1. Setup (one-time)
./fix_coredump.sh

# 2. Run benchmark
cd benchmarks
ulimit -c unlimited && USE_PREBUILT=1 ./clickbench.sh run clickbench_partitioned

# 3. If it crashes, check for coredump
./analyze_crash.sh list

# 4. Analyze the crash
./analyze_crash.sh latest

# In GDB:
(gdb) bt              # Show where it crashed
(gdb) info threads    # Check all threads
(gdb) thread apply all bt  # Backtrace all threads
(gdb) frame 5         # Go to interesting frame
(gdb) info locals     # See local variables
(gdb) quit            # Exit

# 5. Clean up when done
./analyze_crash.sh clean 7
```

## Best Practices

1. **Always set ulimit before running:**
   ```bash
   ulimit -c unlimited && ./your_program
   ```

2. **Add to your shell profile:**
   ```bash
   echo "ulimit -c unlimited" >> ~/.bashrc
   ```

3. **Monitor disk space:**
   ```bash
   df -h /var/coredumps
   du -sh /var/coredumps
   ```

4. **Clean regularly:**
   ```bash
   # Keep only recent coredumps
   ./analyze_crash.sh clean 7
   ```

5. **For production debugging:**
   - Keep the binary that produced the coredump
   - Note the exact version/commit
   - Preserve environment variables and config

## References

- GDB Manual: https://sourceware.org/gdb/documentation/
- Rust GDB Guide: https://rust-lang.github.io/rustup/concepts/debugging.html
- Core Pattern Documentation: `man core`
- systemd-coredump: `man systemd-coredump`

## Summary

- ✅ **Setup:** Run `./fix_coredump.sh` once
- ✅ **Run:** Always use `ulimit -c unlimited`
- ✅ **Analyze:** Use `./analyze_crash.sh` for easy debugging
- ✅ **Clean:** Regular cleanup with `./analyze_crash.sh clean`

For issues or questions, check the [Troubleshooting](#troubleshooting) section.
