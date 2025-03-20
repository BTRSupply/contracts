#!/bin/bash
set -e  # Exit on error

# Navigate to the root directory of the project
cd "$(dirname "$0")/.." || { echo "Error: Could not navigate to project root"; exit 1; }

echo "=== Smart Contract Deployment Generator ==="

# Step 1: Initial build to compile only the core facets and generate artifacts
echo "Step 1: Building facets to generate artifacts..."
cd evm || { echo "Error: evm directory not found"; exit 1; }

# Remove existing DiamondDeployer if it exists
if [ -f "utils/DiamondDeployer.sol" ]; then
  rm -f "utils/DiamondDeployer.sol"
fi

# Create utils directory if it doesn't exist
mkdir -p utils

# Temporarily zip problematic folders to exclude them from build
echo "Temporarily zipping problematic folders..."
[ -d "scripts" ] && zip -q -r scripts.zip scripts && rm -rf scripts
[ -d "test" ] && zip -q -r test.zip test && rm -rf test
[ -d "tests" ] && zip -q -r tests.zip tests && rm -rf tests
[ -d "utils" ] && zip -q -r utils.zip utils && rm -rf utils

# Run initial build with problematic folders removed
echo "Building core facets..."
forge build --skip src/facets/adapters/bridges/LayerZeroAdapterFacet.sol || { 
  echo "Error: Initial facet build failed"
  
  # Restore zipped folders even on failure
  [ -f "scripts.zip" ] && unzip -q scripts.zip && rm scripts.zip
  [ -f "test.zip" ] && unzip -q test.zip && rm test.zip
  [ -f "tests.zip" ] && unzip -q tests.zip && rm tests.zip
  [ -f "utils.zip" ] && unzip -q utils.zip && rm utils.zip
  
  exit 1
}

# Restore the zipped folders
echo "Restoring temporarily removed folders..."
[ -f "scripts.zip" ] && unzip -q scripts.zip && rm scripts.zip
[ -f "test.zip" ] && unzip -q test.zip && rm test.zip
[ -f "tests.zip" ] && unzip -q tests.zip && rm tests.zip
[ -f "utils.zip" ] && unzip -q utils.zip && rm utils.zip

# Step 2: Run Python generator to create DiamondDeployer.sol
echo "Step 2: Generating DiamondDeployer.sol using Python..."
cd ..
chmod +x scripts/generate_deployer.py 2>/dev/null || true
python3 scripts/generate_deployer.py || { echo "Error: Python generator failed"; exit 1; }

# Step 3: Run a full compilation to ensure everything works
echo "Step 3: Running full compilation..."
cd evm || { echo "Error: evm directory not found"; exit 1; }

# Run full build
forge build --skip src/facets/adapters/bridges/LayerZeroAdapterFacet.sol || { echo "Error: Final build failed"; exit 1; }

echo "=== Deployment generation completed successfully ==="
