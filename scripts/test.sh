#!/bin/bash

cd "$(dirname "$0")/../evm" || { echo "Error: Could not navigate to evm directory"; exit 1; }

echo
echo ">> Running tests"
echo

# Run command with all arguments
TEST_CMD="forge test -vvv $*"
echo "> $ $TEST_CMD"

# Execute the command
eval "$TEST_CMD"
EXIT_CODE=$?

echo
if [ $EXIT_CODE -eq 0 ]; then
  echo ">> ✅ Tests completed successfully."
else
  echo ">> ⚠️ Tests completed with failures."
  echo ">> Exit code: $EXIT_CODE"
fi
echo

# Commented out examples for specific test runs
# Run specific test suites
# forge test --match-contract DiamondDeployerTest -vvv
# forge test --match-contract ALMFacetTest -vvv

# Run with gas reporting
# forge test --gas-report

# Run with coverage reporting
# forge coverage

exit $EXIT_CODE 