#!/bin/bash

# Load environment variables
if [ -f .env ]; then
    source .env
fi

# Contract addresses (same on all chains due to deterministic deployment)
PERMIT2_ADDRESS="0x494bbD8A3302AcA833D307D11838f18DbAdA9C25" # TODO: update
UNSUPPORTED_PROTOCOL_ADDRESS="0x61fF070AD105D5aa6d8F9eA21212CB574EeFCAd5" # TODO: update

# Function to verify a contract
verify_contract() {
    local chain_name=$1
    local chain_id=$2
    local contract_address=$3
    local contract_path=$4
    local contract_name=$5
    
    # Get verifier URL for this chain (convert to uppercase)
    local verifier_url_var=$(echo "${chain_name}_VERIFIER_URL" | tr '[:lower:]' '[:upper:]')
    local verifier_url=$(eval echo \$${verifier_url_var})
    
    if [ -z "$verifier_url" ]; then
        echo "❌ Verifier URL not found for $chain_name (${verifier_url_var})"
        echo "   Make sure you have ${verifier_url_var} set in your .env file"
        return 1
    fi
    
    echo "🔍 Verifying $contract_name on $chain_name (Chain ID: $chain_id)"
    echo "   Address: $contract_address"
    echo "   Verifier URL: $verifier_url"
    
    forge verify-contract $contract_address \
        $contract_path:$contract_name \
        --chain-id $chain_id \
        --verifier blockscout \
        --verifier-url $verifier_url \
        --watch
    
    if [ $? -eq 0 ]; then
        echo "✅ Successfully verified $contract_name on $chain_name"
    else
        echo "❌ Failed to verify $contract_name on $chain_name"
    fi
    
    echo ""
}

# Function to process a chain
process_chain() {
    local chain_name=$1
    local chain_id=$2
    
    echo "🌐 Processing $chain_name (Chain ID: $chain_id)"
    echo "============================================"
    
    # Verify Permit2
    verify_contract "$chain_name" "$chain_id" "$PERMIT2_ADDRESS" "lib/permit2/src/Permit2.sol" "Permit2"
    
    # Verify UnsupportedProtocol
    verify_contract "$chain_name" "$chain_id" "$UNSUPPORTED_PROTOCOL_ADDRESS" "contracts/deploy/UnsupportedProtocol.sol" "UnsupportedProtocol"
    
    echo "============================================"
    echo ""
}

# Main verification loop
echo "🚀 Starting contract verification on multiple chains..."
echo "📋 Contracts to verify:"
echo "   - Permit2: $PERMIT2_ADDRESS"
echo "   - UnsupportedProtocol: $UNSUPPORTED_PROTOCOL_ADDRESS"
echo ""

# Chains from [rpc_endpoints] that are NOT in [etherscan] section
process_chain "ink" "57073"
process_chain "lisk" "1135"
process_chain "metal" "1750"
process_chain "mode" "34443"
process_chain "superseed" "5330"
process_chain "soneium" "1868"
process_chain "swell" "1923"
process_chain "unichain" "130"

echo "🎉 Verification process completed!" 