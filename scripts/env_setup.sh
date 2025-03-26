#!/bin/bash

# This script sets up the environment variables required for BTR contract deployment and testing
# Usage: source ./scripts/env_setup.sh [environment]

# Default to development environment if not specified
ENVIRONMENT=${1:-"development"}

echo "Setting up environment variables for $ENVIRONMENT environment..."

# Function to check if a variable is set
check_var() {
  if [ -z "${!1}" ]; then
    echo "Warning: $1 is not set."
    return 1
  else
    return 0
  fi
}

# Set up environment variables based on the environment
case $ENVIRONMENT in
  "development")
    # Development environment (local testing)
    # Use default test private key (do not use in production!)
    export DEPLOYER_PK="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
    # Default Anvil account address
    export DEPLOYER="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
    export TREASURY="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
    ;;
    
  "testnet")
    # Read from .env file if it exists
    if [ -f ".env.testnet" ]; then
      source .env.testnet
    fi
    
    # Check if variables are set
    check_var "DEPLOYER_PK" || echo "Set DEPLOYER_PK in .env.testnet or export it"
    check_var "TREASURY" || echo "Set TREASURY in .env.testnet or export it"
    ;;
    
  "mainnet")
    # Read from .env file if it exists
    if [ -f ".env.mainnet" ]; then
      source .env.mainnet
    fi
    
    # Check if variables are set
    check_var "DEPLOYER_PK" || echo "Set DEPLOYER_PK in .env.mainnet or export it"
    check_var "TREASURY" || echo "Set TREASURY in .env.mainnet or export it"
    ;;
    
  *)
    echo "Unknown environment: $ENVIRONMENT"
    echo "Usage: source ./scripts/env_setup.sh [development|testnet|mainnet]"
    exit 1
    ;;
esac

# Set MANAGER to be same as DEPLOYER by default if not set
if [ -z "$MANAGER" ]; then
  export MANAGER="$DEPLOYER"
fi

# Print the current environment variables
echo "Environment variables set:"
echo "  DEPLOYER_PK: ${DEPLOYER_PK:0:6}...${DEPLOYER_PK: -4} (masked for security)"
echo "  DEPLOYER: $DEPLOYER"
echo "  TREASURY: $TREASURY"
echo "  MANAGER: $MANAGER"

echo "Environment setup complete." 