#!/bin/bash

# Anvil Multi-Chain Testing Setup Script
# This script starts 3 Anvil instances to simulate Base, Katana, and Zircuit chains

echo "🚀 Starting Anvil Multi-Chain Environment..."

# Check for required dependencies
if ! command -v jq &> /dev/null; then
    echo "Warning: jq is not installed. Chain ID verification will be skipped."
    echo "Install jq with: brew install jq (macOS) or apt-get install jq (Linux)"
    USE_JQ=false
else
    USE_JQ=true
fi

# Create logs directory if it doesn't exist
mkdir -p logs

# Kill any existing Anvil processes
echo "Cleaning up existing Anvil instances..."
pkill -f anvil || true
sleep 2

# Start Base chain (port 8545)
echo "Starting Base chain on port 8545..."
anvil \
    --port 8545 \
    --chain-id 31337 \
    --accounts 10 \
    --balance 10000 \
    --block-time 2 \
    > logs/anvil-base.log 2>&1 &

BASE_PID=$!
echo "Base chain started with PID: $BASE_PID"

# Start Katana chain (port 8546)
echo "Starting Katana chain on port 8546..."
anvil \
    --port 8546 \
    --chain-id 31338 \
    --accounts 10 \
    --balance 10000 \
    --block-time 2 \
    > logs/anvil-katana.log 2>&1 &

KATANA_PID=$!
echo "Katana chain started with PID: $KATANA_PID"

# Start Zircuit chain (port 8547)
echo "Starting Zircuit chain on port 8547..."
anvil \
    --port 8547 \
    --chain-id 31339 \
    --accounts 10 \
    --balance 10000 \
    --block-time 2 \
    > logs/anvil-zircuit.log 2>&1 &

ZIRCUIT_PID=$!
echo "Zircuit chain started with PID: $ZIRCUIT_PID"

# Wait for chains to be ready
echo "Waiting for chains to be ready..."
sleep 5

# Test connections
echo "Testing chain connections..."
if [ "$USE_JQ" = true ]; then
    echo -n "Base: "
    curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
        http://localhost:8545 | jq -r '.result' | xargs printf "%d\n"
    
    echo -n "Katana: "
    curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
        http://localhost:8546 | jq -r '.result' | xargs printf "%d\n"
    
    echo -n "Zircuit: "
    curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
        http://localhost:8547 | jq -r '.result' | xargs printf "%d\n"
else
    echo "Base: Chain should be running on 31337"
    echo "Katana: Chain should be running on 31338"
    echo "Zircuit: Chain should be running on 31339"
fi

echo ""
echo "✅ All chains are running!"
echo ""
echo "Chain Details:"
echo "=============="
echo "Base:    http://localhost:8545 (Chain ID: 31337)"
echo "Katana:  http://localhost:8546 (Chain ID: 31338)"
echo "Zircuit: http://localhost:8547 (Chain ID: 31339)"
echo ""
echo "Process IDs:"
echo "============"
echo "Base:    $BASE_PID"
echo "Katana:  $KATANA_PID"
echo "Zircuit: $ZIRCUIT_PID"
echo ""
echo "To stop all chains, run: ./script/anvil/stop-anvil.sh"
echo "To view logs: tail -f logs/anvil-*.log"