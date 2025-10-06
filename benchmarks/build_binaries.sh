#!/usr/bin/env bash
# Build script for ClickBench benchmark binaries
# This script compiles all necessary binaries for remote deployment

set -e

# Color definitions
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DATAFUSION_DIR=${DATAFUSION_DIR:-$SCRIPT_DIR/..}
BUILD_DIR=${BUILD_DIR:-$SCRIPT_DIR/bin}
PROFILE=${PROFILE:-release}

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔨 Building ClickBench Benchmark Binaries${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${YELLOW}DataFusion Dir:${NC} ${DATAFUSION_DIR}"
echo -e "  ${YELLOW}Build Profile:${NC}  ${PROFILE}"
echo -e "  ${YELLOW}Output Dir:${NC}     ${BUILD_DIR}"
echo ""

# Create output directory
mkdir -p "${BUILD_DIR}"

# Navigate to DataFusion benchmarks directory
cd "${DATAFUSION_DIR}/benchmarks"

# Build the dfbench binary (contains clickbench benchmark)
echo -e "${GREEN}📦 Building dfbench binary...${NC}"
if [ "${PROFILE}" = "release" ]; then
    cargo build --release --bin dfbench
    BINARY_PATH="${DATAFUSION_DIR}/target/release/dfbench"
else
    cargo build --profile "${PROFILE}" --bin dfbench
    BINARY_PATH="${DATAFUSION_DIR}/target/${PROFILE}/dfbench"
fi

# Copy binary to output directory
echo -e "${GREEN}📋 Copying binary to ${BUILD_DIR}/${NC}"
cp "${BINARY_PATH}" "${BUILD_DIR}/dfbench"

# Get binary info
BINARY_SIZE=$(ls -lh "${BUILD_DIR}/dfbench" | awk '{print $5}')
echo ""
echo -e "${GREEN}✅ Build complete!${NC}"
echo -e "  ${YELLOW}Binary:${NC} ${BUILD_DIR}/dfbench"
echo -e "  ${YELLOW}Size:${NC}   ${BINARY_SIZE}"
echo ""
echo -e "${BLUE}📤 Next steps:${NC}"
echo -e "  1. Use ${YELLOW}deploy.sh${NC} to upload to remote server"
echo -e "  2. Run ${YELLOW}clickbench.sh${NC} on the remote server with ${YELLOW}USE_PREBUILT=1${NC}"
echo ""
