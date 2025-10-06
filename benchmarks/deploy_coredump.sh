#!/usr/bin/env bash
# Deploy coredump setup script to remote server and execute it

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
REMOTE_DIR=${REMOTE_DIR:-"/tmp"}

usage() {
    echo -e "${BLUE}🚀 Deploy Coredump Setup to Remote Server${NC}\n"
    echo -e "${YELLOW}Usage:${NC}"
    echo "  REMOTE_USER=user REMOTE_HOST=server.com $0"
    echo ""
    echo -e "${YELLOW}Environment Variables:${NC}"
    echo "  REMOTE_USER    SSH user (required)"
    echo "  REMOTE_HOST    Remote server hostname/IP (required)"
    echo "  REMOTE_DIR     Remote directory for scripts (default: /tmp)"
    echo ""
    echo -e "${YELLOW}Example:${NC}"
    echo "  REMOTE_USER=ubuntu REMOTE_HOST=192.168.1.100 $0"
    echo ""
    echo -e "${YELLOW}What it does:${NC}"
    echo "  1. Uploads setup_coredump.sh to remote server"
    echo "  2. Executes the setup script remotely"
    echo "  3. Configures systemd-coredump for crash capture"
    echo "  4. Creates analysis helper script on remote server"
    exit 1
}

# Check required variables
if [ -z "$REMOTE_USER" ] || [ -z "$REMOTE_HOST" ]; then
    echo -e "${RED}❌ Error: REMOTE_USER and REMOTE_HOST must be set${NC}\n"
    usage
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🚀 Deploy Coredump Setup to Remote Server${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${YELLOW}Remote:${NC}     ${REMOTE_USER}@${REMOTE_HOST}"
echo -e "  ${YELLOW}Directory:${NC}  ${REMOTE_DIR}"
echo ""

# Check if setup script exists
if [ ! -f "$SCRIPT_DIR/setup_coredump.sh" ]; then
    echo -e "${RED}❌ Error: setup_coredump.sh not found in $SCRIPT_DIR${NC}"
    exit 1
fi

# Step 1: Upload setup script
echo -e "${GREEN}📤 Step 1/2: Uploading setup_coredump.sh to remote server...${NC}"
scp -q "$SCRIPT_DIR/setup_coredump.sh" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/"
echo -e "${GREEN}✅ Script uploaded${NC}"
echo ""

# Step 2: Execute setup script remotely
echo -e "${GREEN}🔧 Step 2/2: Executing setup script on remote server...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

ssh -t "${REMOTE_USER}@${REMOTE_HOST}" "
    chmod +x ${REMOTE_DIR}/setup_coredump.sh
    ${REMOTE_DIR}/setup_coredump.sh
"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🎉 Coredump setup complete on remote server!${NC}"
echo ""
echo -e "${YELLOW}📝 Next steps:${NC}"
echo "  1. Run your benchmark on the remote server"
echo "  2. If it crashes, the coredump will be automatically captured"
echo "  3. Analyze crashes using:"
echo ""
echo "     ssh ${REMOTE_USER}@${REMOTE_HOST}"
echo "     coredumpctl list"
echo "     ./analyze_crash.sh latest"
echo ""
echo -e "${YELLOW}📊 To check status remotely:${NC}"
echo "  ssh ${REMOTE_USER}@${REMOTE_HOST} coredumpctl list"
echo ""
