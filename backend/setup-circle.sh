#!/bin/bash

# Circle Backend Setup Script
echo "🔐 Circle API Setup for autoUSD Backend"
echo "========================================"
echo ""
echo "This script will help you set up your Circle API credentials."
echo "You'll need your Circle sandbox credentials from console.circle.com"
echo ""

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "Creating backend/.env file..."
    
    # Prompt for Circle credentials
    echo "📝 Enter your Circle API credentials:"
    echo ""
    
    read -p "Circle API Key (TEST_API_KEY:xxx:yyy): " CIRCLE_API_KEY
    read -p "Circle Entity Secret: " CIRCLE_ENTITY_SECRET
    read -p "Circle Wallet Set ID (UUID format): " CIRCLE_WALLET_SET_ID
    read -p "Circle Paymaster API Key (optional, press Enter to skip): " CIRCLE_PAYMASTER_API_KEY
    
    # Create .env file
    cat > .env << EOF
# Backend Configuration
PORT=3001
FRONTEND_URL=http://localhost:3000

# Circle Developer Controlled Wallets
CIRCLE_API_KEY=$CIRCLE_API_KEY
CIRCLE_ENTITY_SECRET=$CIRCLE_ENTITY_SECRET
CIRCLE_WALLET_SET_ID=$CIRCLE_WALLET_SET_ID
CIRCLE_PAYMASTER_API_KEY=${CIRCLE_PAYMASTER_API_KEY:-$CIRCLE_API_KEY}

# Network Configuration
NEXT_PUBLIC_CHAIN_ID=84532
NEXT_PUBLIC_BASE_RPC_URL=https://sepolia.base.org
NEXT_PUBLIC_PAYMASTER_URL=https://api.circle.com/v1/w3s/paymaster
NEXT_PUBLIC_ENTRY_POINT_ADDRESS=0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789

# Contract Addresses (will be added after deployment)
MOTHER_VAULT_ADDRESS=

# Database (optional - uses in-memory by default)
DATABASE_URL=
EOF
    
    echo "✅ Created backend/.env file"
else
    echo "⚠️  .env file already exists. Skipping creation."
fi

echo ""
echo "🧪 Testing Circle API connection..."
echo ""

# Run the test
npm run test:circle

echo ""
echo "📋 Next steps:"
echo "1. If tests pass, start the server: npm run dev"
echo "2. Server will run on http://localhost:3001"
echo "3. Test endpoints with curl or Postman"
echo ""
echo "📚 Available endpoints:"
echo "   POST http://localhost:3001/api/circle/wallets/create"
echo "   GET  http://localhost:3001/api/circle/wallets/balance"
echo "   POST http://localhost:3001/api/circle/wallets/deposit"
echo ""