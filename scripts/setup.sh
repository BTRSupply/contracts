#!/bin/bash
set -e

# Set the project root directory regardless of where the script is called from
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# Default options
USE_VIA_IR=false
SHOW_SIZES=false

# Parse arguments
for arg in "$@"; do
  case $arg in
    --via-ir)
      USE_VIA_IR=true
      ;;
    --sizes)
      SHOW_SIZES=true
      ;;
  esac
done

# Build options
BUILD_OPTS=""
if [ "$USE_VIA_IR" = true ]; then
  BUILD_OPTS="$BUILD_OPTS --via-ir"
fi
if [ "$SHOW_SIZES" = true ]; then
  BUILD_OPTS="$BUILD_OPTS --sizes"
fi

# Clean previous artifacts if any
rm -rf "$PROJECT_ROOT/evm/out/"

echo "=== Compiling facets ==="
# First compilation: only compile facets, excluding scripts and tests
# Save original files
(cd "$PROJECT_ROOT/evm" && mkdir -p .tmp)
if [ -d "$PROJECT_ROOT/evm/scripts" ]; then
  mv "$PROJECT_ROOT/evm/scripts" "$PROJECT_ROOT/evm/.tmp/"
fi
if [ -d "$PROJECT_ROOT/evm/tests" ]; then
  mv "$PROJECT_ROOT/evm/tests" "$PROJECT_ROOT/evm/.tmp/"
fi

# Compile only facets
cd "$PROJECT_ROOT/evm"
forge build --names --skip test $BUILD_OPTS

# Restore scripts and tests
if [ -d "$PROJECT_ROOT/evm/.tmp/scripts" ]; then
  mv "$PROJECT_ROOT/evm/.tmp/scripts" "$PROJECT_ROOT/evm/"
fi
if [ -d "$PROJECT_ROOT/evm/.tmp/tests" ]; then
  mv "$PROJECT_ROOT/evm/.tmp/tests" "$PROJECT_ROOT/evm/"
fi
rm -rf "$PROJECT_ROOT/evm/.tmp"

# Then generate the deployer
echo "=== Generating deployer ==="
python3 "$PROJECT_ROOT/scripts/generate_deployer.py" "$PROJECT_ROOT/evm/out" || exit 1

# Then compile everything with the generated deployer
echo "=== Compiling with generated deployer ==="
cd "$PROJECT_ROOT/evm"
forge build $BUILD_OPTS

echo "=== Deployment generation completed successfully ==="
