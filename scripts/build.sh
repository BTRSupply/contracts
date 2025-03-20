#!/bin/bash

cd "$(dirname "$0")/../evm" || { echo "Error: Could not navigate to evm directory"; exit 1; }

SKIPPED_DEPS=(
  "src/facets/adapters/bridges/LayerZeroAdapterFacet.sol"
)

# Check for --pre-compile flag
PRE_COMPILE=false
FACETS_ONLY=false
ARGS=()
for arg in "$@"; do
  if [ "$arg" == "--pre-compile" ]; then
    PRE_COMPILE=true
  elif [ "$arg" == "--facets-only" ]; then
    FACETS_ONLY=true
  else
    ARGS+=("$arg")
  fi
done

echo
echo ">> Building smart contracts"
echo

# If pre-compile flag is set, exclude tests, scripts, and utils
if [ "$PRE_COMPILE" = true ]; then
  echo ">> Running pre-compile (excluding tests, scripts, and utils)"
  SKIPPED_DEPS+=(
    "test/**/*.sol"
    "scripts/**/*.sol"
    "src/utils/**/*.sol"
  )
fi

if [ "$FACETS_ONLY" = true ]; then
  echo ">> Building only facets"
  
  # Explicitly exclude test and script files to avoid dependency issues
  echo "forge build --contracts 'src/facets/*.sol' --skip scripts/** --skip tests/** --skip src/facets/adapters/bridges/LayerZeroAdapterFacet.sol"
  forge build --contracts 'src/facets/*.sol' --skip scripts/** --skip tests/** --skip src/facets/adapters/bridges/LayerZeroAdapterFacet.sol
  
  if [ $? -ne 0 ]; then
    echo ">> Failed to build facets"
    exit 1
  fi
  
  echo ">> Facets built successfully"
  exit 0
fi

# Build command with all arguments
BUILD_CMD="forge build $(printf -- "--skip %s " "${SKIPPED_DEPS[@]}") ${ARGS[*]}"
echo "> $ $BUILD_CMD"

# Execute the command
eval "$BUILD_CMD"
EXIT_CODE=$?

echo
if [ $EXIT_CODE -eq 0 ]; then
  echo ">> ✅ Build completed successfully."
else
  echo ">> ⚠️ Build completed with warnings or errors."
  echo ">> Exit code: $EXIT_CODE"
fi
echo

exit $EXIT_CODE
