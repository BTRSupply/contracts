#!/bin/bash

# Script to fetch dependencies for the project

# Define dependencies with versions
DEPS=(
  "https://github.com/OpenZeppelin/openzeppelin-contracts.git v5.2.0"
  "https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable.git v5.2.0"
  "https://github.com/foundry-rs/forge-std.git v1.9.6"
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
  REPO_NAME=$(basename $URL .git)
  TARGET_DIR="${LIBS_DIR}/$(echo $REPO_NAME | sed 's/-contracts//')"
  
  echo "Fetching $REPO_NAME at version $VERSION..."
  
  # Clone the repository
  cd $TMP_DIR
  git clone -b $VERSION --depth 1 $URL
  
  # Copy files to target directory
  mkdir -p $TARGET_DIR
  cp -r $TMP_DIR/$REPO_NAME/* $TARGET_DIR/
done

# Clean up
rm -rf $TMP_DIR

echo "Dependencies installed successfully"
