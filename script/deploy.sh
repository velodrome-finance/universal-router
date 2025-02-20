#!/bin/bash

# Exit on error
set -e

echo "⚠️  WARNING: This script is only for vanilla superchain deployments!"
echo "    It assumes WETH is deployed at 0x4200000000000000000000000000000000000006"
echo "    If your chain uses a different WETH address, DO NOT use this script."
echo "    Instead, create a custom deployment script for your chain."
echo ""

read -p "Are you sure you want to continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment aborted."
    exit 1
fi

# Check if required arguments are provided
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <chain-name> [verifier-type] [additional_args]"
    echo "Example (simulation only): $0 soneium"
    echo "Example (with deployment): $0 soneium blockscout"
    echo "Example with additional args: $0 soneium blockscout \"--with-gas-price 1000000000\""
    exit 1
fi

CHAIN_NAME=$1
VERIFIER_TYPE=${2:-""} # Use empty string if no second argument provided
ADDITIONAL_ARGS=${3:-""} # Use empty string if no third argument provided

# Capitalize first letter of chain name for Solidity file and class names
CHAIN_PASCAL="$(echo "${CHAIN_NAME:0:1}" | tr '[:lower:]' '[:upper:]')${CHAIN_NAME:1}"

# Setup paths
DEPLOY_DIR="script/deployParameters"
DEPLOY_FILE="${DEPLOY_DIR}/Deploy${CHAIN_PASCAL}.s.sol"
TEMPLATE_FILE="script/deployTemplate/DeployTemplate.s.sol"

# Create new deployment file from template only if it doesn't exist
if [ ! -f "$DEPLOY_FILE" ]; then
    echo "Creating deployment file for ${CHAIN_NAME}..."
    cp "$TEMPLATE_FILE" "$DEPLOY_FILE"

    # Replace template placeholders with chain-specific values
    sed -i '' "s/DeployTemplate/Deploy${CHAIN_PASCAL}/g" "$DEPLOY_FILE"
    sed -i '' "s/template.json/${CHAIN_NAME}.json/g" "$DEPLOY_FILE"
    sed -i '' "/\/\/\/ @title Deployment template for superchain use only/d" "$DEPLOY_FILE"
    echo "Created new deployment file at ${DEPLOY_FILE}"
else
    echo "Using existing deployment file at ${DEPLOY_FILE}"
fi

# Path to the deployment script
SCRIPT_PATH="${DEPLOY_FILE}:Deploy${CHAIN_PASCAL}"

echo "Running simulation for ${CHAIN_NAME}..."
# Run simulation first
if forge script ${SCRIPT_PATH} --slow --rpc-url ${CHAIN_NAME} -vvvv; then
    # If no verifier type is provided, exit after successful simulation
    if [ -z "$VERIFIER_TYPE" ]; then
        echo "Simulation completed successfully. No deployment performed (no verifier type provided)."
        exit 0
    fi
    
    # Set verifier arguments based on verifier type
    if [ "$VERIFIER_TYPE" = "blockscout" ]; then
        VERIFIER_ARG="--verifier blockscout"
    elif [ "$VERIFIER_TYPE" = "etherscan" ]; then
        VERIFIER_ARG="--verifier etherscan"
    else
        echo "Error: Unsupported verifier type. Use 'blockscout' or 'etherscan'"
        exit 1
    fi

    echo "Simulation successful! Proceeding with actual deployment..."
    
    # Run actual deployment with verification
    forge script ${SCRIPT_PATH} --slow --rpc-url ${CHAIN_NAME} --broadcast --verify ${VERIFIER_ARG} ${ADDITIONAL_ARGS} -vvvv
else
    echo "Simulation failed! Please check the output above for errors."
    exit 1
fi
