# ClickBench Benchmark - Prebuilt Binary Workflow

This document describes how to compile benchmarks locally and deploy them to remote servers for execution without requiring compilation on the remote machine.

## Overview

The workflow consists of three main steps:
1. **Build**: Compile benchmark binaries locally
2. **Deploy**: Upload binaries and scripts to remote server
3. **Run**: Execute benchmarks on remote server using pre-downloaded data

## Prerequisites

### Local Machine
- Rust toolchain (for compilation)
- SSH access to remote server
- `scp` command available

### Remote Server
- ClickBench dataset already downloaded (e.g., `hits_partitioned` or `hits.parquet`)
- DataFusion repository cloned
- No compilation tools required

## Quick Start

### Step 1: Build Binaries Locally

```bash
cd benchmarks
./build_binaries.sh
```

**What it does:**
- Compiles the `dfbench` binary in release mode **with debug info**
- Debug symbols included for coredump analysis
- Outputs the binary to `benchmarks/bin/dfbench`
- Shows binary size and debug info status

**Output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔨 Building ClickBench Benchmark Binaries
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  DataFusion Dir: /path/to/datafusion
  Build Profile:  release
  Debug Info:     1 (for coredump analysis)
  Output Dir:     /path/to/benchmarks/bin

📦 Building dfbench binary...
ℹ️  Debug info enabled (RUSTFLAGS=-C debuginfo=2)
📋 Copying binary to /path/to/benchmarks/bin/

✅ Build complete!
  Binary:      /path/to/benchmarks/bin/dfbench
  Size:        65M
  Debug Info:  Yes

💡 Tips:
  - Debug info is included for coredump analysis with GDB
  - To disable debug info: DEBUG_INFO=0 ./build_binaries.sh
  - Binary will be larger with debug info but provides better crash analysis
```

**Note:** Binary size will be larger (~20-40MB more) with debug info, but this is essential for meaningful crash analysis.

### Step 2: Deploy and Run on Remote Server

```bash
REMOTE_USER=your_username REMOTE_HOST=your_server ./deploy.sh clickbench_partitioned
```

**What it does:**
1. Uploads `dfbench` binary to remote server
2. Uploads `clickbench.sh` script
3. Uploads query files
4. Automatically executes the benchmark
5. Saves results to `results/` directory on remote server

**Example:**
```bash
# Run partitioned benchmark (100 files)
REMOTE_USER=ubuntu REMOTE_HOST=192.168.1.100 ./deploy.sh clickbench_partitioned

# Run single file benchmark
REMOTE_USER=ubuntu REMOTE_HOST=192.168.1.100 ./deploy.sh clickbench_1

# Run all benchmarks
REMOTE_USER=ubuntu REMOTE_HOST=192.168.1.100 ./deploy.sh all
```

### Step 3: Download Results (Optional)

```bash
scp -r your_user@your_server:~/datafusion/benchmarks/results ./results_remote
```

## Available Benchmarks

| Benchmark | Description | Data Required |
|-----------|-------------|---------------|
| `clickbench_1` | Single parquet file (~14GB) | `hits.parquet` |
| `clickbench_partitioned` | 100 partitioned files (~14GB) | `hits_partitioned/` |
| `clickbench_pushdown` | Partitioned with filter pushdown | `hits_partitioned/` |
| `clickbench_extended` | DataFusion-specific queries | `hits.parquet` |
| `all` | Run all benchmarks | Both datasets |

## Configuration

### Environment Variables

#### For build_binaries.sh
- `DATAFUSION_DIR`: DataFusion source directory (default: `..`)
- `BUILD_DIR`: Output directory for binaries (default: `./bin`)
- `PROFILE`: Cargo build profile (default: `release`)

Example:
```bash
PROFILE=release-nonlto ./build_binaries.sh
```

#### For deploy.sh
- `REMOTE_USER`: SSH username (required)
- `REMOTE_HOST`: Remote server hostname/IP (required)
- `REMOTE_DATAFUSION_DIR`: Remote DataFusion path (default: `~/datafusion`)
- `LOCAL_BIN_DIR`: Local binary directory (default: `./bin`)

Example:
```bash
REMOTE_USER=ubuntu \
REMOTE_HOST=192.168.1.100 \
REMOTE_DATAFUSION_DIR=/opt/datafusion \
./deploy.sh clickbench_partitioned
```

#### For clickbench.sh (on remote)
- `USE_PREBUILT`: Use prebuilt binary (set to `1`)
- `DATA_DIR`: Data directory (default: `./data`)
- `RESULTS_NAME`: Results folder name (default: current branch name)
- `NO_EMOJI`: Disable emoji output (set to `1`)

## Manual Deployment (Alternative)

If you prefer manual deployment without using `deploy.sh`:

### 1. Upload binary
```bash
scp benchmarks/bin/dfbench user@server:~/datafusion/benchmarks/bin/
```

### 2. Upload script
```bash
scp benchmarks/clickbench.sh user@server:~/datafusion/benchmarks/
```

### 3. Upload queries
```bash
scp -r benchmarks/queries/clickbench user@server:~/datafusion/benchmarks/queries/
```

### 4. SSH into remote and run
```bash
ssh user@server
cd ~/datafusion/benchmarks
USE_PREBUILT=1 ./clickbench.sh run clickbench_partitioned
```

## Running Specific Queries

To run a specific query (e.g., query 5):

```bash
REMOTE_USER=user REMOTE_HOST=server ./deploy.sh clickbench_partitioned
# Then on remote:
USE_PREBUILT=1 ./clickbench.sh run clickbench_partitioned 5
```

Or deploy first, then run specific queries:
```bash
# Deploy (one time)
REMOTE_USER=user REMOTE_HOST=server ./deploy.sh clickbench_partitioned

# Run different queries via SSH
ssh user@server "cd ~/datafusion/benchmarks && USE_PREBUILT=1 ./clickbench.sh run clickbench_partitioned 1"
ssh user@server "cd ~/datafusion/benchmarks && USE_PREBUILT=1 ./clickbench.sh run clickbench_partitioned 2"
```

## Troubleshooting

### Binary not found error
```
❌ Error: Binary not found at ./bin/dfbench
ℹ️  Please run ./build_binaries.sh first
```
**Solution:** Run `./build_binaries.sh` to compile the binary first.

### Prebuilt binary not found on remote
```
❌ Prebuilt binary not found at /path/to/bin/dfbench
ℹ️  Please upload the binary to /path/to/bin/dfbench
```
**Solution:** Ensure the binary was uploaded correctly. Re-run `deploy.sh`.

### Data file not found
```
❌ Data file not found! Please run: ./clickbench.sh data clickbench_1
```
**Solution:** Download the dataset on the remote server first:
```bash
ssh user@server
cd ~/datafusion/benchmarks
./clickbench.sh data clickbench_partitioned
```

### SSH connection issues
**Solution:** Verify SSH access:
```bash
ssh user@server echo "Connection OK"
```

## Performance Tips

1. **Use release profile**: Default `release` profile provides best performance
2. **Alternative profiles**: Use `release-nonlto` for faster compilation with near-release performance:
   ```bash
   PROFILE=release-nonlto ./build_binaries.sh
   ```
3. **Parallel downloads**: Data download uses 10 parallel workers by default (for partitioned dataset)
4. **Benchmark iterations**: Default is 5 iterations per query for stable results

## Result Files

Results are saved in JSON format:
- Location: `benchmarks/results/<branch_name>/`
- Format: `clickbench_*.json`
- Contains: Query timing, iterations, statistics

Example result structure:
```json
{
  "query": 1,
  "iterations": [100.5, 98.2, 99.1, 97.8, 100.0],
  "mean": 99.12,
  "median": 99.1,
  "min": 97.8,
  "max": 100.5
}
```

## Comparing Results

To compare results between different runs or branches:

```bash
# Download results from different runs
scp -r user@server:~/datafusion/benchmarks/results/branch1 ./results/
scp -r user@server:~/datafusion/benchmarks/results/branch2 ./results/

# Compare (requires Python venv setup)
./clickbench.sh venv  # One-time setup
./clickbench.sh compare branch1 branch2
./clickbench.sh compare_detail branch1 branch2  # Detailed stats
```

## Scripts Reference

### build_binaries.sh
Compiles benchmark binaries locally for deployment.

**Usage:**
```bash
./build_binaries.sh
PROFILE=release-nonlto ./build_binaries.sh
```

### deploy.sh
Uploads binaries and scripts to remote server, then runs benchmarks.

**Usage:**
```bash
REMOTE_USER=user REMOTE_HOST=host ./deploy.sh [benchmark]
```

**Arguments:**
- `benchmark`: Benchmark name (default: `clickbench_partitioned`)

### clickbench.sh
Main benchmark runner script (works both locally and on remote).

**Usage:**
```bash
# With prebuilt binary
USE_PREBUILT=1 ./clickbench.sh run [benchmark] [query]

# With cargo (compile on demand)
./clickbench.sh run [benchmark] [query]

# Download data
./clickbench.sh data [benchmark]

# Compare results
./clickbench.sh compare <branch1> <branch2>
```

## Workflow Diagram

```
┌─────────────────┐
│  Local Machine  │
│                 │
│  1. Build       │
│     binaries    │
│                 │
│  2. Run         │
│     deploy.sh   │
└────────┬────────┘
         │
         │ SSH/SCP
         │
         ▼
┌─────────────────┐
│  Remote Server  │
│                 │
│  3. Receive     │
│     binary +    │
│     scripts     │
│                 │
│  4. Execute     │
│     benchmark   │
│                 │
│  5. Save        │
│     results     │
└─────────────────┘
```

## License

Licensed under the Apache License, Version 2.0. See LICENSE file for details.
