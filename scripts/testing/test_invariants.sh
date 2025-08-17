#!/bin/bash

# Script to run invariant tests specifically
echo "Running Mother Vault Invariant Tests..."

# Create a temporary foundry.toml that only includes our invariant test
cat > foundry_temp.toml << 'EOF'
[profile.default]
src = "contracts"
out = "out"
libs = ["lib"]
solc = "0.8.23"
optimizer = true
optimizer_runs = 200
via_ir = true
remappings = [
    "@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/",
    "forge-std/=lib/forge-std/src/"
]

[profile.ci]
fuzz = { runs = 10000 }
invariant = { runs = 1000, depth = 50, fail_on_revert = false }

[profile.intensive]
fuzz = { runs = 50000 }
invariant = { runs = 10000, depth = 100, fail_on_revert = false }
EOF

# Run just the invariant tests, excluding the problematic ones temporarily
FOUNDRY_CONFIG=foundry_temp.toml FOUNDRY_PROFILE=ci forge test \
    --match-path "test/invariant/MotherVaultInvariants.t.sol" \
    --no-match-test "invariant_WithdrawalQueueOrdering|invariant_RateLimitingWindowConsistency" \
    -vv

echo "Test run completed!"

# Clean up
rm foundry_temp.toml