#!/bin/bash

# Compile Hyperlane Test Contracts
# This script ensures the test contracts are compiled before running tests

echo "🔨 Compiling Hyperlane test contracts..."

# Check if forge is installed
if ! command -v forge &> /dev/null; then
    echo "❌ Forge is not installed."
    echo ""
    echo "Please install Foundry first:"
    echo "  curl -L https://foundry.paradigm.xyz | bash"
    echo "  foundryup"
    exit 1
fi

# Navigate to project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Clean previous builds
echo "Cleaning previous builds..."
forge clean

# Compile contracts
echo "Compiling contracts..."
forge build --contracts test/hyperlane/HyperlaneTestMessage.sol

# Check if compilation was successful
if [ $? -eq 0 ]; then
    echo "✅ Compilation successful!"
    echo ""
    echo "Contract artifacts created at:"
    echo "  out/HyperlaneTestMessage.sol/HyperlaneTestMessage.json"
    echo ""
    echo "You can now run the test script:"
    echo "  node scripts/deployment/test-hyperlane-messaging.js"
else
    echo "❌ Compilation failed!"
    echo ""
    echo "Please check the error messages above and fix any issues."
    exit 1
fi