# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Apache DataFusion is an extensible query execution framework written in Rust that uses Apache Arrow as its in-memory format. It provides a full query planner, columnar streaming multi-threaded vectorized execution engine, and SQL/DataFrame APIs for building fast database and analytic systems.

## Common Commands

### Building and Testing

```bash
# Build the project (uses ci profile for faster CI builds)
cargo build --profile ci

# Check compilation without building
cargo check --profile ci --workspace --all-targets --features integration-tests --locked

# Run all tests
cargo test --profile ci --workspace --lib --tests --bins --features avro,json,backtrace

# Run tests for specific package
cargo test --profile ci -p datafusion-core

# Run sqllogictest suite
cargo test --test sqllogictests

# Run specific sqllogictest file (e.g., information_schema.slt)
cargo test --test sqllogictests -- information_schema

# Run specific test at line number in slt file
cargo test --test sqllogictests -- information:709

# Update sqllogictest expected output
cargo test --test sqllogictests -- ddl --complete

# Run doc tests
cargo test --profile ci --doc --features avro,json

# Run benchmarks
cargo test plan_q --package datafusion-benchmarks --profile ci --features=ci -- --test-threads=1
```

### Linting and Formatting

```bash
# Run all lints (runs fmt, clippy, toml fmt, docs, license checks)
./dev/rust_lint.sh

# Format code
cargo fmt --all

# Check formatting
cargo fmt --all -- --check

# Run clippy
cargo clippy --all-targets --workspace --features avro,pyarrow,integration-tests,extended_tests -- -D warnings

# Or use CI script
./ci/scripts/rust_clippy.sh

# Check TOML formatting
taplo fmt --check

# Check docs
cargo doc --document-private-items --no-deps --workspace --all-features
```

### Specialized Testing

```bash
# Extended tests
cargo test --package datafusion --lib --tests extended_tests --features=extended_tests

# Force hash collisions test
cargo test --profile ci --exclude datafusion-examples --exclude datafusion-benchmarks --exclude datafusion-sqllogictest --exclude datafusion-cli --workspace --lib --tests --features=force_hash_collisions,avro

# TPCH tests (requires data generation first)
INCLUDE_TPCH=true cargo test --test sqllogictests

# SQLite compatibility tests (requires large stack)
export RUST_MIN_STACK=30485760
INCLUDE_SQLITE=true cargo test --profile release-nonlto --test sqllogictests

# Postgres compatibility tests
PG_COMPAT=true PG_URI="postgresql://postgres@127.0.0.1/postgres" cargo test --features=postgres --test sqllogictests
```

### CLI

```bash
# Run DataFusion CLI
cargo run --bin datafusion-cli

# Build and test CLI
cargo test --features backtrace --profile ci -p datafusion-cli --lib --tests --bins
```

## Architecture

### Query Execution Pipeline

DataFusion follows a classic query engine architecture:

1. **SQL Parsing** (optional entry point)
   - SQL string → AST using `sqlparser` crate
   - AST → `LogicalPlan` via `SqlToRel` (in `datafusion-sql`)

2. **DataFrame API** (alternative entry point)
   - Directly builds `LogicalPlan` using `LogicalPlanBuilder`

3. **Logical Planning & Optimization** (in `datafusion-optimizer`)
   - `AnalyzerRule`s: Type coercion, semantic validation
   - `OptimizerRule`s: Projection/filter pushdown, constant folding, etc.

4. **Physical Planning** (in `datafusion-physical-planner`)
   - `LogicalPlan` → `ExecutionPlan` via `PhysicalPlanner`
   - `PhysicalOptimizerRule`s: Join selection, sort optimization

5. **Execution** (in `datafusion-physical-plan`)
   - Streaming, multi-threaded, vectorized execution
   - Operates on Arrow `RecordBatch`es

### Key Crate Organization

The workspace is organized into focused crates:

**Core Query Engine:**
- `datafusion-core`: Main entry point, `SessionContext`, `DataFrame` API
- `datafusion-expr`: Logical plan nodes and expressions (`LogicalPlan`, `Expr`)
- `datafusion-optimizer`: Logical plan optimization rules
- `datafusion-physical-plan`: Physical execution operators (`ExecutionPlan` trait)
- `datafusion-physical-expr`: Physical expression evaluation
- `datafusion-physical-optimizer`: Physical plan optimization

**Data Sources:**
- `datafusion-datasource`: Core datasource abstractions (`TableProvider`)
- `datafusion-datasource-parquet`: Parquet file support
- `datafusion-datasource-csv`: CSV file support
- `datafusion-datasource-json`: JSON file support
- `datafusion-datasource-avro`: Avro file support

**Functions:**
- `datafusion-functions`: Scalar functions
- `datafusion-functions-aggregate`: Aggregate functions (COUNT, SUM, etc.)
- `datafusion-functions-window`: Window functions
- `datafusion-functions-nested`: Array/struct operations
- `datafusion-functions-table`: Table-valued functions

**Supporting Infrastructure:**
- `datafusion-sql`: SQL parsing and planning
- `datafusion-catalog`: Catalog, schema, table management
- `datafusion-execution`: Session state and runtime config
- `datafusion-common`: Shared types, errors, utilities
- `datafusion-proto`: Protobuf serialization for distributed execution

**Testing:**
- `datafusion-sqllogictest`: SQL logic test runner
- `test-utils`: Shared test utilities

### Extension Points

DataFusion is designed for customization via traits:

- `TableProvider`: Custom data sources
- `CatalogProvider`: Custom catalogs/schemas
- `ScalarUDF`, `AggregateUDF`, `WindowUDF`: User-defined functions
- `AnalyzerRule`, `OptimizerRule`: Logical plan rewriting
- `PhysicalOptimizerRule`: Physical plan optimization
- `QueryPlanner`: Custom logical-to-physical conversion
- `ExecutionPlan`: Custom physical operators

## Compilation Profiles

The project defines several cargo profiles optimized for different scenarios:

- `dev`: Default debug build (fast compile, slow runtime)
- `release`: Full optimization with LTO (slow compile, fast runtime)
- `release-nonlto`: Release without LTO (faster compile, nearly release performance) - useful for development
- `profiling`: Release with debug symbols for profiling/flamegraphs
- `ci`: Dev profile without incremental compilation (for CI reproducibility)

Run with profiles using: `cargo build --profile <profile-name>`

## Development Workflow

### Pre-commit Hook

The repository includes a pre-commit hook at `pre-commit.sh`:

```bash
# Install it:
ln -s ../../pre-commit.sh .git/hooks/pre-commit

# It runs clippy and fmt on staged Rust files
```

### Adding Tests

For sqllogictest:
1. Create/edit a `.slt` file in `datafusion/sqllogictest/test_files/`
2. Add queries without expected results
3. Run with `--complete` flag to auto-generate expected output
4. Verify and commit

Each `.slt` file runs in isolated `SessionContext` - avoid side effects.

### Dependency Management

- `Cargo.lock` is committed (follows Rust guidance for applications)
- Dependencies updated via Dependabot
- CI uses committed `Cargo.lock`

## Important Notes

- **MSRV**: Rust 1.87.0 (defined in workspace `Cargo.toml`)
- **Arrow Version**: 56.2.0 (update via `dev/update_arrow_deps.py`)
- **License**: Apache 2.0 - all files must have license headers (checked by CI)
- **No incremental compilation in CI** (`ci` profile) for reproducibility
- **Protobuf changes**: Run codegen in `datafusion/proto/gen` and `datafusion/proto-common/gen`
- **Function docs**: Auto-generated via `dev/update_function_docs.sh`
- **Config docs**: Auto-generated via `dev/update_config_docs.sh`

## Testing Philosophy

- Each test should be isolated and reproducible
- Use `test_files/scratch/<test_name>` for temporary files in sqllogictests
- Prefer `ORDER BY` or `rowsort` in sqllogictests to avoid non-deterministic output
- Tests run in parallel - avoid global state
