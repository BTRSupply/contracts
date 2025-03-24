#!/bin/bash
set -e  # Exit on error

# Navigate to the root directory of the project
cd "$(dirname "$0")/.." || { echo "Error: Could not navigate to project root"; exit 1; }

echo "=== Smart Contract Deployment Generator ==="

# Step 1: Initial build to compile only the core facets and generate artifacts
echo "Step 1: Building facets to generate artifacts..."
cd evm || { echo "Error: evm directory not found"; exit 1; }

# Create generated directory
mkdir -p utils/generated

# Remove existing DiamondDeployer if it exists
if [ -f "utils/generated/DiamondDeployer.gen.sol" ]; then
  rm -f "utils/generated/DiamondDeployer.gen.sol"
fi

# Temporarily zipping dependent folders to exclude them from build
echo "Temporarily zipping dependent folders..."
[ -d "scripts" ] && zip -q -r scripts.zip scripts && rm -rf scripts
[ -d "test" ] && zip -q -r test.zip test && rm -rf test
[ -d "tests" ] && zip -q -r tests.zip tests && rm -rf tests
[ -d "utils" ] && zip -q -r utils.zip utils && rm -rf utils

# Run initial build withping dependent folders removed
echo "Building core facets..."
forge build --via-ir || { 
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

# Step 2: Run Python generator to create DiamondDeployer.gen.sol
echo "Step 2: Generating DiamondDeployer.gen.sol using Python..."
cd ..

# Create a temporary copy of generate_deployer.py with updated output path
cp scripts/generate_deployer.py scripts/generate_deployer_temp.py

# Update the output path in the temporary script
sed -i '' 's/output_path = os\.path\.join("evm", "utils", "DiamondDeployer\.sol")/output_path = os\.path\.join("evm", "utils", "generated", "DiamondDeployer.gen.sol")/' scripts/generate_deployer_temp.py

chmod +x scripts/generate_deployer_temp.py 2>/dev/null || true
python3 scripts/generate_deployer_temp.py || { echo "Error: Python generator failed"; exit 1; }

# Remove temporary script
rm scripts/generate_deployer_temp.py

# Create a symbolic link to ensure backward compatibility
cd evm/utils
ln -sf generated/DiamondDeployer.gen.sol DiamondDeployer.sol
cd ../..

# Step 3: Update import paths in test files
echo "Step 3: Updating import paths in test files..."
find evm/tests -name "*.sol" -type f -exec sed -i '' 's|import {DiamondDeployer} from "@utils/DiamondDeployer.sol";|import {DiamondDeployer} from "@utils/generated/DiamondDeployer.gen.sol";|g' {} \;

# Step 4: Run a full compilation to ensure everything works
echo "Step 4: Running full compilation..."
cd evm || { echo "Error: evm directory not found"; exit 1; }

# Run full build with --via-ir flag
forge build --via-ir || { echo "Error: Final build failed"; exit 1; }

echo "=== Deployment generation completed successfully ==="

# This file will become setup.sh - changes here will be moved to the new file
