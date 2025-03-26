#!/bin/bash

# Navigate to the EVM directory
cd evm

# First build the entire project
echo "Building the project..."
forge build

# Test specific tests
echo "Running specific initialization tests..."
forge test -vvv --match-test "testDiamondConstructor" 

echo "Test run completed." 