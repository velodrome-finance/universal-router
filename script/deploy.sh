#!/bin/bash

# Exit on error
set -e

echo "⚠️  DEPLOYMENT SCRIPT - Safety checks enabled!"
echo "    🔍 Before deploying, please verify these parameters in your deployment file:"
echo "       • WETH address (non-standard superchain chains may use different addresses)"
echo "       • Uniswap parameters (set to address(0) by default - update for live Uniswap deployments)"
echo "       • Velodrome parameters (configured for superchain - update for non-superchain deployments)"
echo "    ✅ Script will NOT broadcast newly created template files - review first!"
echo ""

# Load environment variables
if [ -f .env ]; then
    source .env
fi

# Check if required arguments are provided
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <chain-name> [additional_args]"
    echo "Example (simulation only): $0 soneium"
    echo "Example (with deployment): $0 soneium --broadcast"
    echo "Example with additional args: $0 soneium \"--broadcast --with-gas-price 1000000000\""
    exit 1
fi

CHAIN_NAME=$1
ADDITIONAL_ARGS="${@:2}"

# Capitalize first letter of chain name for Solidity file and class names
CHAIN_PASCAL="$(echo "${CHAIN_NAME:0:1}" | tr '[:lower:]' '[:upper:]')${CHAIN_NAME:1}"

# Setup paths
DEPLOY_FILE="script/deployParameters/Deploy${CHAIN_PASCAL}.s.sol"
TEMPLATE_FILE="script/deployTemplate/DeployTemplate.s.sol"
ADDRESSES_FILE="deployment-addresses/${CHAIN_NAME}.json"

# Create new deployment file from template if it doesn't exist
FILE_CREATED_FROM_TEMPLATE=false
if [ ! -f "$DEPLOY_FILE" ]; then
    echo "Creating deployment file for ${CHAIN_NAME}..."
    cp "$TEMPLATE_FILE" "$DEPLOY_FILE"

    # Replace template placeholders with chain-specific values
    sed -i '' "s/DeployTemplate/Deploy${CHAIN_PASCAL}/g" "$DEPLOY_FILE"
    sed -i '' "s/{CHAIN_NAME}/${CHAIN_NAME}/g" "$DEPLOY_FILE"
    sed -i '' "/\/\/\/ @title Deployment template for superchain use only/d" "$DEPLOY_FILE"
    echo "Created new deployment file at ${DEPLOY_FILE}"
    FILE_CREATED_FROM_TEMPLATE=true
else
    echo "Using existing deployment file at ${DEPLOY_FILE}"
fi

# Create deployment addresses file if it doesn't exist
if [ ! -f "$ADDRESSES_FILE" ]; then
    echo "Creating deployment addresses file for ${CHAIN_NAME}..."
    touch "$ADDRESSES_FILE"
    echo "Created new addresses file at ${ADDRESSES_FILE}"
else
    echo "Using existing addresses file at ${ADDRESSES_FILE}"
fi

SCRIPT_PATH="${DEPLOY_FILE}:Deploy${CHAIN_PASCAL}"

echo "Running simulation for ${CHAIN_NAME}..."
if forge script ${SCRIPT_PATH} --slow --rpc-url ${CHAIN_NAME} -vvvv; then
    # Check if --broadcast is in additional args
    if [[ "$ADDITIONAL_ARGS" != *"--broadcast"* ]]; then
        echo "Simulation completed successfully. No deployment performed (--broadcast not specified)."
        exit 0
    fi
    
    # Prevent broadcasting if file was just created from template
    if [ "$FILE_CREATED_FROM_TEMPLATE" = true ]; then
        echo "❌ Cannot broadcast with a newly created deployment file from template!"
        echo "   Please review and customize ${DEPLOY_FILE} before deploying."
        exit 1
    fi
    
    # Determine verifier based on chain name
    case "$CHAIN_NAME" in
        "base"|"optimism"|"fraxtal"|"celo")
            echo "Using etherscan verifier for ${CHAIN_NAME}"
            VERIFIER_ARGS="--verify --verifier etherscan"
            ;;
        *)
            echo "Using blockscout verifier for ${CHAIN_NAME}"
            VERIFIER_URL_VAR=$(echo "${CHAIN_NAME}_VERIFIER_URL" | tr '[:lower:]' '[:upper:]')
            VERIFIER_URL=$(eval echo \$${VERIFIER_URL_VAR})
            
            if [ -z "$VERIFIER_URL" ]; then
                echo "❌ Verifier URL not found for $CHAIN_NAME (${VERIFIER_URL_VAR})"
                echo "   Make sure you have ${VERIFIER_URL_VAR} set in your .env file"
                exit 1
            fi
            
            echo "Using verifier URL: $VERIFIER_URL"
            VERIFIER_ARGS="--verify --verifier blockscout --verifier-url $VERIFIER_URL"
            ;;
    esac

    echo "Simulation successful! Proceeding with deployment..."
    forge script ${SCRIPT_PATH} --slow --rpc-url ${CHAIN_NAME} ${VERIFIER_ARGS} ${ADDITIONAL_ARGS} -vvvv
else
    echo "Simulation failed! Please check the output above for errors."
    exit 1
fi
