#!/bin/bash

# autoUSD Environment Setup Script
# This script helps set up all environment files

echo "🚀 autoUSD Environment Setup"
echo "============================="
echo ""

# Function to prompt for input with default
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    read -p "$prompt [$default]: " input
    if [ -z "$input" ]; then
        eval "$var_name='$default'"
    else
        eval "$var_name='$input'"
    fi
}

# Check if .env.example exists
if [ ! -f .env.example ]; then
    echo "❌ Error: .env.example not found"
    exit 1
fi

echo "📝 Setting up environment files..."
echo ""

# 1. Setup deployment private key
echo "1️⃣ Deployment Configuration"
echo "----------------------------"
prompt_with_default "Enter your deployment private key (with 0x prefix)" "0x..." PRIVATE_KEY
prompt_with_default "Enter your treasury address" "0x..." TREASURY_ADDRESS
echo ""

# 2. Setup RPC URLs
echo "2️⃣ RPC Configuration"
echo "--------------------"
prompt_with_default "Enter Alchemy API key (for Ethereum Sepolia)" "your_api_key" ALCHEMY_KEY
echo ""

# 3. Setup Circle credentials
echo "3️⃣ Circle Configuration"
echo "-----------------------"
echo "Get these from: https://console.circle.com/wallets/developer"
prompt_with_default "Enter Circle API Key" "TEST_API_KEY:xxx:yyy" CIRCLE_API_KEY
prompt_with_default "Enter Circle Entity Secret" "xxx" CIRCLE_ENTITY_SECRET
prompt_with_default "Enter Circle Wallet Set ID" "xxx-xxx-xxx" CIRCLE_WALLET_SET_ID
prompt_with_default "Enter Circle Paymaster API Key" "TEST_API_KEY:xxx:yyy" CIRCLE_PAYMASTER_API_KEY
echo ""

# 4. Setup Etherscan/Basescan API keys
echo "4️⃣ Block Explorer Configuration"
echo "--------------------------------"
prompt_with_default "Enter Basescan API key" "your_key" BASESCAN_API_KEY
prompt_with_default "Enter Etherscan API key" "your_key" ETHERSCAN_API_KEY
echo ""

# Create .env.base.sepolia
echo "📄 Creating .env.base.sepolia..."
cat > .env.base.sepolia << EOF
# Base Sepolia Configuration
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
BASESCAN_API_KEY=$BASESCAN_API_KEY

# Deployment
PRIVATE_KEY=$PRIVATE_KEY
TREASURY_ADDRESS=$TREASURY_ADDRESS

# USDC
USDC_ADDRESS_TESTNET=0x036CbD53842c5426634e7929541eC2318f3dCF7e

# Circle
CIRCLE_API_KEY=$CIRCLE_API_KEY
CIRCLE_ENTITY_SECRET=$CIRCLE_ENTITY_SECRET
CIRCLE_WALLET_SET_ID=$CIRCLE_WALLET_SET_ID
CIRCLE_PAYMASTER_API_KEY=$CIRCLE_PAYMASTER_API_KEY

# CCTP
CCTP_MESSAGE_TRANSMITTER=0x7865fAfC2db2093669d92c0F33AeEF291086BEFD
CCTP_TOKEN_MESSENGER=0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5

# Contracts (will be added after deployment)
MOTHER_VAULT_ADDRESS=
EOF

# Create .env.ethereum.sepolia
echo "📄 Creating .env.ethereum.sepolia..."
cat > .env.ethereum.sepolia << EOF
# Ethereum Sepolia Configuration
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_KEY
ETHERSCAN_API_KEY=$ETHERSCAN_API_KEY

# Deployment
PRIVATE_KEY=$PRIVATE_KEY

# CCTP
CCTP_MESSAGE_TRANSMITTER=0x7865fAfC2db2093669d92c0F33AeEF291086BEFD
CCTP_TOKEN_MESSENGER=0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5

# USDC
USDC_ADDRESS=0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
EOF

# Create .env.katana.tatara
echo "📄 Creating .env.katana.tatara..."
cat > .env.katana.tatara << EOF
# Katana Tatara Configuration
KATANA_TESTNET_RPC_URL=https://rpc.api.tatara.katana.network

# Deployment
PRIVATE_KEY=$PRIVATE_KEY

# Chain ID
KATANA_CHAIN_ID=129399

# Contracts (will be added after deployment)
KATANA_CHILD_VAULT_ADDRESS=
EOF

# Create backend/.env
echo "📄 Creating backend/.env..."
mkdir -p backend
cat > backend/.env << EOF
# Backend Configuration
PORT=3001
FRONTEND_URL=http://localhost:3000

# Circle Configuration
CIRCLE_API_KEY=$CIRCLE_API_KEY
CIRCLE_ENTITY_SECRET=$CIRCLE_ENTITY_SECRET
CIRCLE_WALLET_SET_ID=$CIRCLE_WALLET_SET_ID
CIRCLE_PAYMASTER_API_KEY=$CIRCLE_PAYMASTER_API_KEY

# Network
NEXT_PUBLIC_CHAIN_ID=84532
NEXT_PUBLIC_BASE_RPC_URL=https://sepolia.base.org
NEXT_PUBLIC_ENTRY_POINT_ADDRESS=0x0000000071727De22E5E9d8BAf0edAc6f37da032

# Contracts (will be added after deployment)
MOTHER_VAULT_ADDRESS=
EOF

# Create frontend/.env.local
echo "📄 Creating frontend/.env.local..."
mkdir -p frontend
cat > frontend/.env.local << EOF
# Frontend Configuration
NEXT_PUBLIC_API_URL=http://localhost:3001
NEXT_PUBLIC_CHAIN_ID=84532
NEXT_PUBLIC_BASE_RPC_URL=https://sepolia.base.org

# Circle (optional - for frontend SDK)
NEXT_PUBLIC_CIRCLE_APP_ID=

# Fern (will be configured later)
NEXT_PUBLIC_FERN_API_KEY=
NEXT_PUBLIC_FERN_ENVIRONMENT=sandbox

# Contracts (will be added after deployment)
NEXT_PUBLIC_MOTHER_VAULT_ADDRESS=
EOF

echo ""
echo "✅ Environment files created successfully!"
echo ""
echo "📋 Created files:"
echo "   - .env.base.sepolia"
echo "   - .env.ethereum.sepolia"
echo "   - .env.katana.tatara"
echo "   - backend/.env"
echo "   - frontend/.env.local"
echo ""
echo "⚠️  IMPORTANT: Never commit these files to git!"
echo ""
echo "📝 Next steps:"
echo "   1. Review and update any placeholder values"
echo "   2. Deploy contracts: ./scripts/deployment/deploy-all-testnets.sh"
echo "   3. Update MOTHER_VAULT_ADDRESS in .env files after deployment"
echo "   4. Start backend: cd backend && npm run dev"
echo "   5. Start frontend: cd frontend && npm run dev"
echo ""
echo "🔒 Security reminder: Add all .env files to .gitignore!"