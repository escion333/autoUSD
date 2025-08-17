#!/bin/bash

# Complete deployment script for autoUSD testnet
# Deploys to Base Sepolia, Ethereum Sepolia, and Katana Tatara

set -e # Exit on error

echo "🚀 autoUSD Testnet Deployment Script"
echo "===================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command -v forge &> /dev/null; then
    echo -e "${RED}❌ Foundry not installed${NC}"
    echo "Install with: curl -L https://foundry.paradigm.xyz | bash"
    exit 1
fi

if ! command -v bun &> /dev/null; then
    echo -e "${YELLOW}⚠️  Bun not installed (optional for Katana kit)${NC}"
    echo "Install with: curl -fsSL https://bun.sh/install | bash"
fi

# Load environment files
if [ ! -f .env.base.sepolia ]; then
    echo -e "${RED}❌ .env.base.sepolia not found${NC}"
    exit 1
fi

if [ ! -f .env.ethereum.sepolia ]; then
    echo -e "${RED}❌ .env.ethereum.sepolia not found${NC}"
    exit 1
fi

if [ ! -f .env.katana.tatara ]; then
    echo -e "${RED}❌ .env.katana.tatara not found${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites checked${NC}"
echo ""

# Deploy to Base Sepolia
echo "1️⃣  Deploying to Base Sepolia..."
echo "================================"
source .env.base.sepolia

DEPLOY_OUTPUT=$(forge script scripts/deployment/foundry/base/DeployBaseSepolia.s.sol \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast \
    --slow \
    -vv 2>&1)

echo "$DEPLOY_OUTPUT"

# Extract addresses from output (fixed regex)
MOTHER_VAULT_BASE=$(echo "$DEPLOY_OUTPUT" | grep "MotherVault deployed:" | grep -o '0x[a-fA-F0-9]\{40\}' | head -1)
CCTP_BRIDGE_BASE=$(echo "$DEPLOY_OUTPUT" | grep "CCTPBridge deployed:" | grep -o '0x[a-fA-F0-9]\{40\}' | head -1)
MESSENGER_BASE=$(echo "$DEPLOY_OUTPUT" | grep "CrossChainMessenger deployed:" | grep -o '0x[a-fA-F0-9]\{40\}' | head -1)

if [ -z "$MOTHER_VAULT_BASE" ]; then
    echo -e "${RED}❌ Failed to deploy MotherVault on Base Sepolia${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Base Sepolia deployment complete${NC}"
echo "MotherVault: $MOTHER_VAULT_BASE"
echo "CCTPBridge: $CCTP_BRIDGE_BASE"
echo "Messenger: $MESSENGER_BASE"
echo ""

# Export for next deployment
export MOTHER_VAULT_BASE

# Deploy to Ethereum Sepolia
echo "2️⃣  Deploying to Ethereum Sepolia..."
echo "===================================="
source .env.ethereum.sepolia

DEPLOY_OUTPUT=$(forge script scripts/deployment/foundry/ethereum/DeployEthereumSepolia.s.sol \
    --rpc-url $ETHEREUM_SEPOLIA_RPC_URL \
    --broadcast \
    --slow \
    -vv 2>&1)

echo "$DEPLOY_OUTPUT"

# Extract addresses (fixed regex)
ETHEREUM_BRIDGE_HUB=$(echo "$DEPLOY_OUTPUT" | grep "EthereumBridgeHub deployed:" | grep -o '0x[a-fA-F0-9]\{40\}' | head -1)
CCTP_BRIDGE_ETHEREUM=$(echo "$DEPLOY_OUTPUT" | grep "CCTPBridge deployed:" | grep -o '0x[a-fA-F0-9]\{40\}' | head -1)

if [ -z "$ETHEREUM_BRIDGE_HUB" ]; then
    echo -e "${RED}❌ Failed to deploy EthereumBridgeHub on Ethereum Sepolia${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Ethereum Sepolia deployment complete${NC}"
echo "EthereumBridgeHub: $ETHEREUM_BRIDGE_HUB"
echo "CCTPBridge: $CCTP_BRIDGE_ETHEREUM"
echo ""

# Export for next deployment
export ETHEREUM_BRIDGE_HUB

# Deploy to Katana Tatara
echo "3️⃣  Deploying to Katana Tatara..."
echo "================================"
source .env.katana.tatara

# Check if we have API key
if [[ "$KATANA_TATARA_RPC_URL" == *"<apikey>"* ]]; then
    echo -e "${YELLOW}⚠️  Warning: Katana RPC URL needs API key${NC}"
    echo "Get API key from Katana team or use public RPC"
    echo "Attempting with public RPC..."
    KATANA_TATARA_RPC_URL="https://rpc.tatara.katana.network"
fi

DEPLOY_OUTPUT=$(forge script scripts/deployment/foundry/katana/DeployKatanaTatara.s.sol \
    --rpc-url $KATANA_TATARA_RPC_URL \
    --broadcast \
    --slow \
    -vv 2>&1)

echo "$DEPLOY_OUTPUT"

# Extract addresses (fixed regex)
KATANA_CHILD_VAULT=$(echo "$DEPLOY_OUTPUT" | grep "KatanaChildVault deployed:" | grep -o '0x[a-fA-F0-9]\{40\}' | head -1)

if [ -z "$KATANA_CHILD_VAULT" ]; then
    echo -e "${RED}❌ Failed to deploy KatanaChildVault on Tatara${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Katana Tatara deployment complete${NC}"
echo "KatanaChildVault: $KATANA_CHILD_VAULT"
echo ""

# Save deployed addresses
echo "4️⃣  Saving deployed addresses..."
echo "================================"

cat > DEPLOYED_ADDRESSES.md << EOF
# Deployed Contract Addresses
Generated: $(date)

## Base Sepolia (Mother Vault)
- MotherVault: $MOTHER_VAULT_BASE
- CCTPBridge: $CCTP_BRIDGE_BASE
- CrossChainMessenger: $MESSENGER_BASE

## Ethereum Sepolia (Bridge Hub)
- EthereumBridgeHub: $ETHEREUM_BRIDGE_HUB
- CCTPBridge: $CCTP_BRIDGE_ETHEREUM

## Katana Tatara (Child Vault)
- KatanaChildVault: $KATANA_CHILD_VAULT

## Explorers
- Base Sepolia: https://sepolia.basescan.org/address/$MOTHER_VAULT_BASE
- Ethereum Sepolia: https://sepolia.etherscan.io/address/$ETHEREUM_BRIDGE_HUB
- Katana Tatara: https://explorer.tatara.katana.network/address/$KATANA_CHILD_VAULT
EOF

echo -e "${GREEN}✅ Addresses saved to DEPLOYED_ADDRESSES.md${NC}"
echo ""

# Update frontend env
echo "5️⃣  Updating frontend configuration..."
echo "======================================"

if [ -d "frontend" ]; then
    cat > frontend/.env.local << EOF
# autoUSD Frontend Configuration
NEXT_PUBLIC_MOTHER_VAULT=$MOTHER_VAULT_BASE
NEXT_PUBLIC_ETHEREUM_BRIDGE_HUB=$ETHEREUM_BRIDGE_HUB
NEXT_PUBLIC_KATANA_CHILD_VAULT=$KATANA_CHILD_VAULT

# Chain IDs
NEXT_PUBLIC_BASE_SEPOLIA_CHAIN_ID=84532
NEXT_PUBLIC_ETHEREUM_SEPOLIA_CHAIN_ID=11155111
NEXT_PUBLIC_KATANA_TATARA_CHAIN_ID=129399

# RPC URLs
NEXT_PUBLIC_BASE_RPC=$BASE_SEPOLIA_RPC_URL
NEXT_PUBLIC_ETHEREUM_RPC=$ETHEREUM_SEPOLIA_RPC_URL
NEXT_PUBLIC_KATANA_RPC=$KATANA_TATARA_RPC_URL
EOF
    echo -e "${GREEN}✅ Frontend configuration updated${NC}"
fi

echo ""
echo "🎉 Deployment Complete!"
echo "====================="
echo ""
echo "Next Steps:"
echo "1. Test deposit on Base Sepolia: https://sepolia.basescan.org/address/$MOTHER_VAULT_BASE"
echo "2. Bridge through Ethereum Hub: https://sepolia.etherscan.io/address/$ETHEREUM_BRIDGE_HUB"
echo "3. Monitor yield on Katana: https://explorer.tatara.katana.network/address/$KATANA_CHILD_VAULT"
echo ""
echo "To start local testing:"
echo "  cd katana-kit && bun run start:anvil katana"
echo ""
echo "To run frontend:"
echo "  cd frontend && npm run dev"
echo ""
echo -e "${GREEN}✨ Happy testing!${NC}"