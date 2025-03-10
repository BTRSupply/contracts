#!/bin/bash

# Script to fetch dependencies for the project

# Define dependencies with versions and solidity-only flag
DEPS=(
  "https://github.com/OpenZeppelin/openzeppelin-contracts.git v5.2.0 true"
  "https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable.git v5.2.0 true"
  "https://github.com/foundry-rs/forge-std.git v1.9.6 false"
)

# Store root directory and create libraries dir
ROOT_DIR=$(pwd)
LIBS_DIR="${ROOT_DIR}/evm/libraries"
mkdir -p ${LIBS_DIR}

# Clone repos to temp dir
TMP_DIR=$(mktemp -d)

# Iterate through dependencies
for DEP in "${DEPS[@]}"; do
  URL=$(echo $DEP | cut -d' ' -f1)
  VERSION=$(echo $DEP | cut -d' ' -f2)
  SOLIDITY_ONLY=$(echo $DEP | cut -d' ' -f3)
  REPO_NAME=$(basename $URL .git)
  TARGET_DIR="${LIBS_DIR}/$(echo $REPO_NAME | sed 's/-contracts//')"
  
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
done

# Clean up
rm -rf $TMP_DIR

echo "Dependencies installed successfully"
