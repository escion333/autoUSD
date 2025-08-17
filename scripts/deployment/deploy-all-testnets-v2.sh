#!/bin/bash

# Simplified deployment script for autoUSD testnet
# Deploys to Base Sepolia and Katana Tatara only
# Ethereum Sepolia is just a passthrough for bridging

set -e # Exit on error

echo "🚀 autoUSD Testnet Deployment Script V2"
echo "======================================="
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

# Load environment files
if [ ! -f .env.base.sepolia ]; then
    echo -e "${RED}❌ .env.base.sepolia not found${NC}"
    exit 1
fi

if [ ! -f .env.ethereum.sepolia ]; then
    echo -e "${YELLOW}⚠️  Creating .env.ethereum.sepolia from .env.base.sepolia${NC}"
    cp .env.base.sepolia .env.ethereum.sepolia
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

# Extract addresses from output
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
export ETHEREUM_BRIDGE_HUB="0x0000000000000000000000000000000000000000" # No contract needed on Ethereum

# Deploy to Katana Tatara
echo "2️⃣  Deploying to Katana Tatara..."
echo "================================"
source .env.katana.tatara

DEPLOY_OUTPUT=$(forge script scripts/deployment/foundry/katana/DeployKatanaTatara.s.sol \
    --rpc-url $KATANA_TATARA_RPC_URL \
    --broadcast \
    --slow \
    -vv 2>&1)

echo "$DEPLOY_OUTPUT"

# Extract addresses
KATANA_CHILD_VAULT=$(echo "$DEPLOY_OUTPUT" | grep "KatanaChildVault deployed:" | grep -o '0x[a-fA-F0-9]\{40\}' | head -1)

if [ -z "$KATANA_CHILD_VAULT" ]; then
    echo -e "${RED}❌ Failed to deploy KatanaChildVault on Katana Tatara${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Katana Tatara deployment complete${NC}"
echo "KatanaChildVault: $KATANA_CHILD_VAULT"
echo ""

# Save deployment addresses
echo "💾 Saving deployment addresses..."
cat > DEPLOYED_ADDRESSES.md << EOF
# Deployed Contract Addresses
Generated: $(date)

## Base Sepolia
- MotherVault: $MOTHER_VAULT_BASE
- CCTPBridge: $CCTP_BRIDGE_BASE  
- CrossChainMessenger: $MESSENGER_BASE

## Ethereum Sepolia (Bridge Hub)
- Unified Bridge: 0x528e26b25a34a4A5d0dbDa1d57D318153d2ED582 (Pre-deployed)
- No custom contracts needed (passthrough only)

## Katana Tatara
- KatanaChildVault: $KATANA_CHILD_VAULT

## Bridge Flow
1. Base Sepolia -> Ethereum Sepolia: CCTP (Circle)
2. Ethereum Sepolia -> Katana Tatara: Unified Bridge (AggLayer)
EOF

echo -e "${GREEN}✅ Addresses saved to DEPLOYED_ADDRESSES.md${NC}"

# Update environment files
echo "📝 Updating environment files..."
echo "MOTHER_VAULT_BASE=$MOTHER_VAULT_BASE" >> .env.base.sepolia
echo "KATANA_CHILD_VAULT=$KATANA_CHILD_VAULT" >> .env.katana.tatara

echo ""
echo "====================================="
echo -e "${GREEN}🎉 DEPLOYMENT COMPLETE!${NC}"
echo "====================================="
echo ""
echo "Next Steps:"
echo "1. Fund the MotherVault with test USDC on Base Sepolia"
echo "2. Test deposit flow: Base -> Ethereum -> Katana"
echo "3. Monitor bridge transactions:"
echo "   - CCTP: https://testnet.circle.com/cctp"
echo "   - Unified Bridge: https://bridge.katana.network/"
echo ""
echo "Bridge Script Usage:"
echo "   cd scripts/bridge"
echo "   node bridgeToKatana.js <amount> <recipient>"