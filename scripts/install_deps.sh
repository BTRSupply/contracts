#!/bin/bash

# Script to fetch dependencies for the project

# Define dependencies with versions, solidity-only flag, and optional alias
DEPS=(
  "https://github.com/OpenZeppelin/openzeppelin-contracts.git v5.2.0 true oz"
  "https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable.git v5.2.0 true oz-upgradeable"
  "https://github.com/LayerZero-Labs/devtools.git @layerzerolabs/ua-devtools-evm@5.0.7 true lz-devtools"
  "https://github.com/LayerZero-Labs/layerzero-v2 main true lz-v2"
  "https://github.com/foundry-rs/forge-std.git v1.9.6 false forge-std"
)

# Store root directory and create dependencies dir
ROOT_DIR=$(cd "$(dirname "$0")"/.. && pwd)
DEPS_DIR="${ROOT_DIR}/evm/.deps"
mkdir -p ${DEPS_DIR}

# Clone repos to temp dir
TMP_DIR=$(mktemp -d)

# Iterate through dependencies
for DEP in "${DEPS[@]}"; do
  URL=$(echo $DEP | cut -d' ' -f1)
  VERSION=$(echo $DEP | cut -d' ' -f2)
  SOLIDITY_ONLY=$(echo $DEP | cut -d' ' -f3)
  ALIAS=$(echo $DEP | cut -d' ' -f4)
  REPO_NAME=$(basename $URL .git)
  TARGET_DIR="${DEPS_DIR}/${ALIAS:-$(echo $REPO_NAME | sed 's/-contracts//')}"
  
  echo "Fetching $REPO_NAME at version $VERSION..."
  
  # Clone the repository
  cd $TMP_DIR
  git clone -b $VERSION --depth 1 $URL
  
  # Copy files to target directory
  mkdir -p $TARGET_DIR
  cp -r $TMP_DIR/$REPO_NAME/* $TARGET_DIR/
  
  # If solidity-only flag is true, remove non-solidity files
  if [ "$SOLIDITY_ONLY" = "true" ]; then
    echo "Keeping only Solidity files for $REPO_NAME..."
    find $TARGET_DIR -type f -not -name "*.sol" -delete
    # Remove empty directories
    find $TARGET_DIR -type d -empty -delete
  fi
  
  # Update import paths for OpenZeppelin contracts
  echo "Updating import paths for $REPO_NAME..."
done

# Clean up
rm -rf $TMP_DIR

echo "Dependencies installed successfully"
