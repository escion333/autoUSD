#!/bin/bash

# Setup script for Katana integration

echo "🚀 Setting up Katana integration for autoUSD..."

# Check if bun is installed
if ! command -v bun &> /dev/null; then
    echo "❌ Bun is not installed. Please install it first:"
    echo "curl -fsSL https://bun.sh/install | bash"
    exit 1
fi

# Check if katana-kit directory exists
if [ ! -d "katana-kit" ]; then
    echo "❌ katana-kit directory not found"
    echo "Please ensure you're in the autoUSD project root"
    exit 1
fi

# Navigate to katana-kit directory
cd katana-kit

# Copy environment template
if [ ! -f .env ]; then
    echo "📝 Creating .env file..."
    cp .env.example .env
    echo "⚠️  Please update .env with your API keys and RPC endpoints"
fi

# Install dependencies
echo "📦 Installing dependencies..."
bun install

# Build dependencies
echo "🔨 Building Forge dependencies..."
bun run forge:deps

# Build address utilities
echo "📍 Building address utilities..."
bun run build:addressutils

# Build ABIs
echo "📜 Building ABIs..."
bun run build:abi

# Build contract directory
echo "📂 Building contract directory..."
bun run build:contractdir

# Build everything
echo "🏗️ Building all components..."
bun run build

echo "✅ Katana setup complete!"
echo ""
echo "Next steps:"
echo "1. Update katana-kit/.env with your API keys"
echo "2. Run 'bun run start:anvil katana' to start local fork"
echo "3. Deploy contracts using deployment scripts"