#!/usr/bin/env bash
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# This script is a simplified version of bench.sh focused only on ClickBench benchmarks

# Exit on error
set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Emoji definitions (can be disabled by setting NO_EMOJI=1)
if [ -z "$NO_EMOJI" ]; then
    ROCKET="🚀"
    CHECK="✅"
    DOWNLOAD="⬇️"
    RUNNING="⚡"
    DONE="🎉"
    INFO="ℹ️"
    WARNING="⚠️"
    ERROR="❌"
    CHART="📊"
else
    ROCKET="[*]"
    CHECK="[✓]"
    DOWNLOAD="[↓]"
    RUNNING="[>]"
    DONE="[✓]"
    INFO="[i]"
    WARNING="[!]"
    ERROR="[X]"
    CHART="[#]"
fi

# Get script directory
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Print colored message
print_info() {
    echo -e "${CYAN}${INFO} $1${NC}"
}

print_success() {
    echo -e "${GREEN}${CHECK} $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}${WARNING} $1${NC}"
}

print_error() {
    echo -e "${RED}${ERROR} $1${NC}"
}

print_header() {
    echo -e "${MAGENTA}${BOLD}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${NC}"
}

print_section() {
    echo -e "\n${BLUE}${BOLD}▶ $1${NC}"
}

# Execute command and also print it, for debugging purposes
debug_run() {
    local env_vars=()

    # 收集所有环境变量设置
    while [[ "$1" == *=* ]]; do
        env_vars+=("$1")
        shift
    done

    echo -e "${CYAN}${RUNNING} Executing: ${env_vars[@]} $@${NC}"
    set -x
    env ${env_vars[@]} "$@"
    set +x
}

# Set Defaults
COMMAND=
BENCHMARK=clickbench_partitioned
DATAFUSION_DIR=${DATAFUSION_DIR:-$SCRIPT_DIR/..}
DATA_DIR=${DATA_DIR:-$SCRIPT_DIR/data}
USE_PREBUILT=${USE_PREBUILT:-0}

# Determine binary execution method
if [ "$USE_PREBUILT" = "1" ]; then
    PREBUILT_BIN="${SCRIPT_DIR}/bin/dfbench"
    if [ ! -f "$PREBUILT_BIN" ]; then
        print_error "Prebuilt binary not found at $PREBUILT_BIN"
        print_info "Please upload the binary to ${SCRIPT_DIR}/bin/dfbench"
        exit 1
    fi
    CARGO_COMMAND="$PREBUILT_BIN"
    print_info "Using prebuilt binary: $PREBUILT_BIN"
else
    CARGO_COMMAND=${CARGO_COMMAND:-"cargo run"}
fi

VIRTUAL_ENV=${VIRTUAL_ENV:-$SCRIPT_DIR/venv}

usage() {
    echo -e "${BOLD}${ROCKET} ClickBench Benchmark Runner for DataFusion${NC}\n"
    echo -e "${BOLD}Usage:${NC}"
    echo "  $0 data [benchmark]"
    echo "  $0 run [benchmark] [query]"
    echo "  $0 compare <branch1> <branch2>"
    echo "  $0 compare_detail <branch1> <branch2>"
    echo "  $0 venv"
    echo ""
    print_header "📝 Examples"
    echo "  # Download ClickBench datasets"
    echo -e "  ${GREEN}./clickbench.sh data${NC}"
    echo ""
    echo "  # Run all ClickBench benchmarks"
    echo -e "  ${GREEN}./clickbench.sh run all${NC}"
    echo ""
    echo "  # Run only the single file benchmark"
    echo -e "  ${GREEN}./clickbench.sh run clickbench_1${NC}"
    echo ""
    echo "  # Run a specific query (e.g., query 5)"
    echo -e "  ${GREEN}./clickbench.sh run clickbench_1 5${NC}"
    echo ""
    print_header "🎯 Commands"
    echo -e "  ${CYAN}data${NC}            Downloads ClickBench data needed for benchmarking"
    echo -e "  ${CYAN}run${NC}             Runs the named benchmark"
    echo -e "  ${CYAN}compare${NC}         Compares fastest results from benchmark runs"
    echo -e "  ${CYAN}compare_detail${NC}  Compares minimum, average (±stddev), and maximum results"
    echo -e "  ${CYAN}venv${NC}            Creates new venv and installs compare's requirements"
    echo ""
    print_header "📊 Benchmarks"
    echo -e "  ${YELLOW}clickbench_partitioned (default)${NC}  ClickBench queries against partitioned (100 files) parquet (~14GB)"
    echo -e "  ${YELLOW}clickbench_1${NC}            ClickBench queries against a single parquet file (~14GB)"
    echo -e "  ${YELLOW}clickbench_pushdown${NC}     ClickBench with filter_pushdown enabled"
    echo -e "  ${YELLOW}clickbench_extended${NC}     ClickBench 'inspired' queries (DataFusion specific)"
    echo -e "  ${YELLOW}all${NC}                     Run all ClickBench benchmarks"
    echo ""
    print_header "⚙️  Configuration (Environment Variables)"
    echo "  DATA_DIR        Directory to store datasets (default: ./data)"
    echo "  USE_PREBUILT    Use prebuilt binary from ./bin/dfbench (default: 0, set to 1 to use)"
    echo "  CARGO_COMMAND   Command that runs the benchmark binary (default: cargo run --release)"
    echo "  DATAFUSION_DIR  DataFusion directory to use (default: parent of script dir)"
    echo "  RESULTS_NAME    Folder where the benchmark files are stored"
    echo "  VENV_PATH       Python venv to use for compare (default: ./venv)"
    echo "  NO_EMOJI        Set to 1 to disable emoji output"
    echo "  DATAFUSION_*    Set the given datafusion configuration"
    echo ""
    echo -e "${BOLD}${ROCKET} Using Prebuilt Binaries:${NC}"
    echo "  1. Build locally:      ./build_binaries.sh"
    echo "  2. Deploy and run:     REMOTE_USER=user REMOTE_HOST=host ./deploy.sh [benchmark]"
    echo "  3. Or run locally:     USE_PREBUILT=1 ./clickbench.sh run [benchmark]"
    echo ""
    exit 1
}

# Downloads the single file hits.parquet ClickBench dataset
# Creates data in $DATA_DIR/hits.parquet
data_clickbench_1() {
    print_section "${DOWNLOAD} Downloading ClickBench single file dataset"

    pushd "${DATA_DIR}" > /dev/null

    # Avoid downloading if it already exists and is the right size
    OUTPUT_SIZE=$(wc -c hits.parquet 2>/dev/null | awk '{print $1}' || true)
    echo -n "Checking hits.parquet..."
    if test "${OUTPUT_SIZE}" = "14779976446"; then
        echo ""
        print_success "hits.parquet already exists (${OUTPUT_SIZE} bytes / ~14GB)"
    else
        URL="https://datasets.clickhouse.com/hits_compatible/hits.parquet"
        echo ""
        print_info "Downloading ${URL} (~14GB)..."
        print_warning "This may take a while depending on your internet connection"
        wget --continue --progress=bar:force ${URL}
        print_success "Download complete!"
    fi
    popd > /dev/null
}

# Downloads the 100 file partitioned ClickBench dataset
# Creates data in $DATA_DIR/hits_partitioned
data_clickbench_partitioned() {
    MAX_CONCURRENT_DOWNLOADS=10

    print_section "${DOWNLOAD} Downloading ClickBench partitioned dataset (100 files)"

    mkdir -p "${DATA_DIR}/hits_partitioned"
    pushd "${DATA_DIR}/hits_partitioned" > /dev/null

    echo -n "Checking hits_partitioned..."
    OUTPUT_SIZE=$(wc -c -- * 2>/dev/null | tail -n 1 | awk '{print $1}' || true)
    if test "${OUTPUT_SIZE}" = "14737666736"; then
        echo ""
        print_success "hits_partitioned already exists (${OUTPUT_SIZE} bytes / ~14GB)"
    else
        echo ""
        print_info "Downloading 100 partitioned files with ${MAX_CONCURRENT_DOWNLOADS} parallel workers..."
        print_warning "Progress: each dot represents one completed file"
        echo -n "  "
        seq 0 99 | xargs -P${MAX_CONCURRENT_DOWNLOADS} -I{} bash -c 'wget -q --continue https://datasets.clickhouse.com/hits_compatible/athena_partitioned/hits_{}.parquet && echo -n "."'
        echo ""
        print_success "All 100 files downloaded successfully!"
    fi

    popd > /dev/null
}

# Runs the clickbench benchmark with a single large parquet file
run_clickbench_1() {
    print_section "${RUNNING} Running ClickBench (single file) benchmark"

    RESULTS_FILE="${RESULTS_DIR}/clickbench_1.json"
    print_info "Results will be saved to: ${RESULTS_FILE}"

    if [ ! -f "${DATA_DIR}/hits.parquet" ]; then
        print_error "Data file not found! Please run: $0 data clickbench_1"
        exit 1
    fi

    if [ "$USE_PREBUILT" = "1" ]; then
        debug_run $CARGO_COMMAND clickbench --iterations 5 --path "${DATA_DIR}/hits.parquet" --queries-path "${SCRIPT_DIR}/queries/clickbench/queries" -o "${RESULTS_FILE}" ${QUERY_ARG}
    else
        debug_run $CARGO_COMMAND --bin dfbench -- clickbench --iterations 5 --path "${DATA_DIR}/hits.parquet" --queries-path "${SCRIPT_DIR}/queries/clickbench/queries" -o "${RESULTS_FILE}" ${QUERY_ARG}
    fi
    print_success "Benchmark completed! Results saved to ${RESULTS_FILE}"
}

# Runs the clickbench benchmark with the partitioned parquet dataset (100 files)
run_clickbench_partitioned() {
    print_section "${RUNNING} Running ClickBench (100 partitioned files) benchmark"

    RESULTS_FILE="${RESULTS_DIR}/clickbench_partitioned.json"
    print_info "Results will be saved to: ${RESULTS_FILE}"

    if [ ! -d "${DATA_DIR}/hits_partitioned" ] || [ -z "$(ls -A ${DATA_DIR}/hits_partitioned 2>/dev/null)" ]; then
        print_error "Partitioned data not found! Please run: $0 data clickbench_partitioned"
        exit 1
    fi

    if [ "$USE_PREBUILT" = "1" ]; then
        debug_run $CARGO_COMMAND clickbench --iterations 5 --path "${DATA_DIR}/hits_partitioned" --queries-path "${SCRIPT_DIR}/queries/clickbench/queries" -o "${RESULTS_FILE}" ${QUERY_ARG}
    else
        debug_run $CARGO_COMMAND --bin dfbench -- clickbench --iterations 5 --path "${DATA_DIR}/hits_partitioned" --queries-path "${SCRIPT_DIR}/queries/clickbench/queries" -o "${RESULTS_FILE}" ${QUERY_ARG}
    fi
    print_success "Benchmark completed! Results saved to ${RESULTS_FILE}"
}

# Runs the clickbench benchmark with the partitioned parquet files and filter_pushdown enabled
run_clickbench_pushdown() {
    print_section "${RUNNING} Running ClickBench (with filter pushdown) benchmark"

    RESULTS_FILE="${RESULTS_DIR}/clickbench_pushdown.json"
    print_info "Results will be saved to: ${RESULTS_FILE}"
    print_info "Filter pushdown and filter reordering enabled"

    if [ ! -d "${DATA_DIR}/hits_partitioned" ] || [ -z "$(ls -A ${DATA_DIR}/hits_partitioned 2>/dev/null)" ]; then
        print_error "Partitioned data not found! Please run: $0 data clickbench_partitioned"
        exit 1
    fi

    if [ "$USE_PREBUILT" = "1" ]; then
        debug_run $CARGO_COMMAND clickbench --pushdown --iterations 5 --path "${DATA_DIR}/hits_partitioned" --queries-path "${SCRIPT_DIR}/queries/clickbench/queries" -o "${RESULTS_FILE}" ${QUERY_ARG}
    else
        debug_run $CARGO_COMMAND --bin dfbench -- clickbench --pushdown --iterations 5 --path "${DATA_DIR}/hits_partitioned" --queries-path "${SCRIPT_DIR}/queries/clickbench/queries" -o "${RESULTS_FILE}" ${QUERY_ARG}
    fi
    print_success "Benchmark completed! Results saved to ${RESULTS_FILE}"
}

# Runs the clickbench "extended" benchmark with a single large parquet file
run_clickbench_extended() {
    print_section "${RUNNING} Running ClickBench Extended (DataFusion specific) benchmark"

    RESULTS_FILE="${RESULTS_DIR}/clickbench_extended.json"
    print_info "Results will be saved to: ${RESULTS_FILE}"

    if [ ! -f "${DATA_DIR}/hits.parquet" ]; then
        print_error "Data file not found! Please run: $0 data clickbench_1"
        exit 1
    fi

    if [ "$USE_PREBUILT" = "1" ]; then
        debug_run $CARGO_COMMAND clickbench --iterations 5 --path "${DATA_DIR}/hits.parquet" --queries-path "${SCRIPT_DIR}/queries/clickbench/extended" -o "${RESULTS_FILE}" ${QUERY_ARG}
    else
        debug_run $CARGO_COMMAND --bin dfbench -- clickbench --iterations 5 --path "${DATA_DIR}/hits.parquet" --queries-path "${SCRIPT_DIR}/queries/clickbench/extended" -o "${RESULTS_FILE}" ${QUERY_ARG}
    fi
    print_success "Benchmark completed! Results saved to ${RESULTS_FILE}"
}

# Compare benchmark results between two branches
compare_benchmarks() {
    print_section "${CHART} Comparing benchmark results"

    BASE_RESULTS_DIR="${SCRIPT_DIR}/results"
    BRANCH1="$1"
    BRANCH2="$2"
    OPTS="$3"

    if [ -z "$BRANCH1" ] ; then
        print_error "<branch1> not specified"
        print_info "Available branches:"
        ls -1 "${BASE_RESULTS_DIR}"
        exit 1
    fi

    if [ -z "$BRANCH2" ] ; then
        print_error "<branch2> not specified"
        print_info "Available branches:"
        ls -1 "${BASE_RESULTS_DIR}"
        exit 1
    fi

    print_info "Comparing ${BRANCH1} vs ${BRANCH2}"

    FOUND_RESULTS=false
    for RESULTS_FILE1 in "${BASE_RESULTS_DIR}/${BRANCH1}"/clickbench*.json ; do
        BENCH=$(basename "${RESULTS_FILE1}")
        RESULTS_FILE2="${BASE_RESULTS_DIR}/${BRANCH2}/${BENCH}"
        if test -f "${RESULTS_FILE2}" ; then
            FOUND_RESULTS=true
            echo ""
            print_header "${CHART} Benchmark: ${BENCH}"
            PATH=$VIRTUAL_ENV/bin:$PATH python3 "${SCRIPT_DIR}"/compare.py $OPTS "${RESULTS_FILE1}" "${RESULTS_FILE2}"
        else
            print_warning "Skipping ${BENCH} - not found in ${BRANCH2}"
        fi
    done

    if [ "$FOUND_RESULTS" = true ]; then
        echo ""
        print_success "Comparison complete!"
    else
        print_error "No matching benchmark results found for comparison"
        exit 1
    fi
}

# Setup Python virtual environment for comparison scripts
setup_venv() {
    print_section "🐍 Setting up Python virtual environment"

    print_info "Creating virtual environment at: $VIRTUAL_ENV"
    python3 -m venv "$VIRTUAL_ENV"

    print_info "Installing requirements..."
    PATH=$VIRTUAL_ENV/bin:$PATH python3 -m pip install -q -r requirements.txt

    print_success "Virtual environment ready!"
    print_info "Activate with: source $VIRTUAL_ENV/bin/activate"
}

# Parse command line arguments
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            shift
            usage
            ;;
        -*)
            print_error "Unknown option $1"
            echo ""
            usage
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

set -- "${POSITIONAL_ARGS[@]}"
COMMAND=${1:-"${COMMAND}"}
ARG2=$2
ARG3=$3

# Main command dispatcher
main() {
    case "$COMMAND" in
        data)
            BENCHMARK=${ARG2:-"${BENCHMARK}"}

            print_header "${ROCKET} ClickBench Data Downloader"
            echo -e "  ${BOLD}Command:${NC}    ${COMMAND}"
            echo -e "  ${BOLD}Benchmark:${NC}  ${BENCHMARK}"
            echo -e "  ${BOLD}Data Dir:${NC}   ${DATA_DIR}"
            echo ""

            mkdir -p "${DATA_DIR}"

            case "$BENCHMARK" in
                all)
                    data_clickbench_1
                    data_clickbench_partitioned
                    echo ""
                    print_success "${DONE} All datasets downloaded successfully!"
                    ;;
                clickbench_1)
                    data_clickbench_1
                    echo ""
                    print_success "${DONE} Dataset downloaded successfully!"
                    ;;
                clickbench_partitioned)
                    data_clickbench_partitioned
                    echo ""
                    print_success "${DONE} Dataset downloaded successfully!"
                    ;;
                clickbench_pushdown)
                    print_info "clickbench_pushdown uses the same data as clickbench_partitioned"
                    data_clickbench_partitioned
                    echo ""
                    print_success "${DONE} Dataset downloaded successfully!"
                    ;;
                clickbench_extended)
                    print_info "clickbench_extended uses the same data as clickbench_1"
                    data_clickbench_1
                    echo ""
                    print_success "${DONE} Dataset downloaded successfully!"
                    ;;
                *)
                    print_error "Unknown benchmark '$BENCHMARK' for data generation"
                    echo ""
                    usage
                    ;;
            esac
            ;;
        run)
            BENCHMARK=${ARG2:-"${BENCHMARK}"}
            EXTRA_ARGS=("${POSITIONAL_ARGS[@]:2}")
            QUERY=${EXTRA_ARGS[0]}
            QUERY_ARG=""
            if [ -n "$QUERY" ]; then
                QUERY_ARG="--query ${QUERY}"
            fi

            BRANCH_NAME=$(cd "${DATAFUSION_DIR}" && git rev-parse --abbrev-ref HEAD)
            BRANCH_NAME=${BRANCH_NAME//\//_}
            RESULTS_NAME=${RESULTS_NAME:-"${BRANCH_NAME}"}
            RESULTS_DIR=${RESULTS_DIR:-"$SCRIPT_DIR/results/$RESULTS_NAME"}

            print_header "${ROCKET} ClickBench Benchmark Runner"
            echo -e "  ${BOLD}Command:${NC}         ${COMMAND}"
            echo -e "  ${BOLD}Benchmark:${NC}       ${BENCHMARK}"
            echo -e "  ${BOLD}Query:${NC}           ${QUERY:-All queries}"
            echo -e "  ${BOLD}DataFusion Dir:${NC}  ${DATAFUSION_DIR}"
            echo -e "  ${BOLD}Branch:${NC}          ${BRANCH_NAME}"
            echo -e "  ${BOLD}Data Dir:${NC}        ${DATA_DIR}"
            echo -e "  ${BOLD}Results Dir:${NC}     ${RESULTS_DIR}"
            echo -e "  ${BOLD}Cargo Command:${NC}   ${CARGO_COMMAND}"
            echo ""

            pushd "${DATAFUSION_DIR}/benchmarks" > /dev/null
            mkdir -p "${RESULTS_DIR}"
            mkdir -p "${DATA_DIR}"

            START_TIME=$(date +%s)

            case "$BENCHMARK" in
                all)
                    print_info "Running all ClickBench benchmarks..."
                    run_clickbench_1
                    run_clickbench_partitioned
                    run_clickbench_pushdown
                    run_clickbench_extended
                    ;;
                clickbench_1)
                    run_clickbench_1
                    ;;
                clickbench_partitioned)
                    run_clickbench_partitioned
                    ;;
                clickbench_pushdown)
                    run_clickbench_pushdown
                    ;;
                clickbench_extended)
                    run_clickbench_extended
                    ;;
                *)
                    print_error "Unknown benchmark '$BENCHMARK' for run"
                    echo ""
                    usage
                    ;;
            esac

            END_TIME=$(date +%s)
            DURATION=$((END_TIME - START_TIME))
            MINUTES=$((DURATION / 60))
            SECONDS=$((DURATION % 60))

            popd > /dev/null
            echo ""
            print_success "${DONE} All benchmarks completed in ${MINUTES}m ${SECONDS}s!"
            print_info "Results saved in: ${RESULTS_DIR}"
            ;;
        compare)
            compare_benchmarks "$ARG2" "$ARG3"
            ;;
        compare_detail)
            compare_benchmarks "$ARG2" "$ARG3" "--detailed"
            ;;
        venv)
            setup_venv
            ;;
        "")
            usage
            ;;
        *)
            print_error "Unknown command: $COMMAND"
            echo ""
            usage
            ;;
    esac
}

# Start the process
main
