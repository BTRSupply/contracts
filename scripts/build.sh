#!/bin/bash

# Change to the evm directory
cd "$(dirname "$0")/../evm" || { echo "Error: Could not navigate to evm directory"; exit 1; }

# Define skipped dependencies
SKIPPED_DEPS=(
  "src/facets/adapters/bridges/LayerZeroAdapterFacet.sol"
)

echo "====================================================="
echo "Forge Build with Skip"
echo "====================================================="
echo "Running forge build with the following files/directories skipped:"
for DEP in "${SKIPPED_DEPS[@]}"; do
  echo "  - ${DEP#erc/}"
done
echo "====================================================="

# Run forge build with the files/directories to skip
forge build \
  $(printf -- "--skip %s " "${SKIPPED_DEPS[@]}") \
  "$@"

BUILD_EXIT_CODE=$?

if [ $BUILD_EXIT_CODE -eq 0 ]; then
  echo "====================================================="
  echo "✅ Build completed successfully."
  echo "====================================================="
  exit 0
else
  echo "====================================================="
  echo "⚠️  Build completed with warnings or errors."
  echo "Exit code: $BUILD_EXIT_CODE"
  echo "====================================================="
  exit $BUILD_EXIT_CODE
fi