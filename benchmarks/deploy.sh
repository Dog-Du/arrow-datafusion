#!/usr/bin/env bash
# Deploy and run ClickBench benchmarks on remote server
# Assumes remote server already has data downloaded

set -e

# Color definitions
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Configuration
REMOTE_USER=${REMOTE_USER:-""}
REMOTE_HOST=${REMOTE_HOST:-""}
REMOTE_DATAFUSION_DIR=${REMOTE_DATAFUSION_DIR:-"/shared/rust_pro/datafusion"}
LOCAL_BIN_DIR=${LOCAL_BIN_DIR:-"$SCRIPT_DIR/bin"}
BENCHMARK=${BENCHMARK:-"clickbench_partitioned"}

usage() {
    echo -e "${BLUE}🚀 Deploy and Run ClickBench on Remote Server${NC}\n"
    echo -e "${YELLOW}Usage:${NC}"
    echo "  REMOTE_USER=user REMOTE_HOST=server.com $0 [benchmark]"
    echo ""
    echo -e "${YELLOW}Environment Variables:${NC}"
    echo "  REMOTE_USER          SSH user (required)"
    echo "  REMOTE_HOST          Remote server hostname/IP (required)"
    echo "  REMOTE_DATAFUSION_DIR  Remote datafusion path (default: /shared/rust_pro/datafusion)"
    echo "  LOCAL_BIN_DIR        Local binary directory (default: ./bin)"
    echo ""
    echo -e "${YELLOW}Benchmarks:${NC}"
    echo "  clickbench_1            Single file benchmark"
    echo "  clickbench_partitioned  Partitioned benchmark (default)"
    echo "  clickbench_pushdown     Partitioned with pushdown"
    echo "  clickbench_extended     Extended queries"
    echo "  all                     Run all benchmarks"
    echo ""
    echo -e "${YELLOW}Example:${NC}"
    echo "  REMOTE_USER=ubuntu REMOTE_HOST=192.168.1.100 $0 clickbench_partitioned"
    exit 1
}

# Check required variables
if [ -z "$REMOTE_USER" ] || [ -z "$REMOTE_HOST" ]; then
    echo -e "${RED}❌ Error: REMOTE_USER and REMOTE_HOST must be set${NC}\n"
    usage
fi

# Check if binary exists
if [ ! -f "$LOCAL_BIN_DIR/dfbench" ]; then
    echo -e "${RED}❌ Error: Binary not found at $LOCAL_BIN_DIR/dfbench${NC}"
    echo -e "${YELLOW}ℹ️  Please run ./build_binaries.sh first${NC}"
    exit 1
fi

BENCHMARK=${1:-$BENCHMARK}

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🚀 Deploy and Run ClickBench Benchmark${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${YELLOW}Remote:${NC}      ${REMOTE_USER}@${REMOTE_HOST}"
echo -e "  ${YELLOW}Remote Dir:${NC}  ${REMOTE_DATAFUSION_DIR}"
echo -e "  ${YELLOW}Benchmark:${NC}   ${BENCHMARK}"
echo ""

# Step 1: Upload binary
echo -e "${GREEN}📤 Step 1/4: Uploading binary to remote server...${NC}"
ssh "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p ${REMOTE_DATAFUSION_DIR}/benchmarks/bin"
scp -q "$LOCAL_BIN_DIR/dfbench" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DATAFUSION_DIR}/benchmarks/bin/"
echo -e "${GREEN}✅ Binary uploaded${NC}"
echo ""

# Step 2: Upload clickbench.sh script
echo -e "${GREEN}📤 Step 2/4: Uploading clickbench.sh script...${NC}"
scp -q "$SCRIPT_DIR/clickbench.sh" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DATAFUSION_DIR}/benchmarks/"
ssh "${REMOTE_USER}@${REMOTE_HOST}" "chmod +x ${REMOTE_DATAFUSION_DIR}/benchmarks/clickbench.sh"
echo -e "${GREEN}✅ Script uploaded${NC}"
echo ""

# Step 3: Upload queries directory
echo -e "${GREEN}📤 Step 3/4: Uploading query files...${NC}"
if [ -d "$SCRIPT_DIR/queries/clickbench" ]; then
    ssh "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p ${REMOTE_DATAFUSION_DIR}/benchmarks/queries"
    scp -q -r "$SCRIPT_DIR/queries/clickbench" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DATAFUSION_DIR}/benchmarks/queries/"
    echo -e "${GREEN}✅ Query files uploaded${NC}"
else
    echo -e "${YELLOW}⚠️  Warning: queries/clickbench not found locally, assuming it exists on remote${NC}"
fi
echo ""

# Step 4: Run benchmark on remote
echo -e "${GREEN}🏃 Step 4/4: Running benchmark on remote server...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

ssh -t "${REMOTE_USER}@${REMOTE_HOST}" "
    cd ${REMOTE_DATAFUSION_DIR}/benchmarks
    export USE_PREBUILT=1
    ./clickbench.sh run ${BENCHMARK}
"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🎉 Benchmark execution complete!${NC}"
echo ""
echo -e "${YELLOW}📊 To download results:${NC}"
echo "  scp -r ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DATAFUSION_DIR}/benchmarks/results ./results_remote"
echo ""
