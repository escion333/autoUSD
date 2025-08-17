# MotherVault Invariant Tests

This directory contains comprehensive invariant and fuzz tests for the autoUSD MotherVault contract.

## Test Structure

### Invariant Tests (`MotherVaultInvariants.t.sol`)

The invariant test suite includes:

1. **Share Price Monotonicity**: Ensures share price doesn't decrease except during actual losses
2. **Buffer Management**: Verifies withdrawal restrictions maintain required buffer levels
3. **Rebalance Cooldown**: Ensures rebalance operations respect cooldown periods
4. **Rate Limit Enforcement**: Validates rate limiting prevents excessive rebalances
5. **Asset Conservation**: Checks total assets = idle + deployed funds
6. **USDC Balance Consistency**: Verifies contract USDC balance matches reported idle balance
7. **Share Supply Consistency**: Ensures share supply is consistent with asset backing
8. **Deposit Cap Enforcement**: Validates deposits don't exceed caps
9. **Share Price Floor**: Prevents unreasonable share price degradation
10. **Deployed Amount Consistency**: Ensures deployed amounts match child vault records

### Fuzz Tests (Added to `MotherVault.t.sol`)

Extended fuzz tests covering:

1. **Deposit Edge Cases**: Tests various deposit amounts and user scenarios
2. **Withdrawal with Buffer**: Tests withdrawal constraints with buffer requirements
3. **Rebalance Thresholds**: Validates rebalancing logic with different APY scenarios
4. **Fee Calculations**: Tests management fee calculations across time periods
5. **Rate Limit Enforcement**: Validates rate limiting under stress
6. **Buffer Management**: Tests buffer requirements under various deployment scenarios
7. **Multi-User Scenarios**: Complex scenarios with multiple users and time progression

## Running the Tests

### Basic Invariant Tests
```bash
# Run all invariant tests
forge test --match-contract "MotherVaultInvariantsTest"

# Run with higher iterations for thorough testing
forge test --match-contract "MotherVaultInvariantsTest" --fuzz-runs 10000

# Run specific invariant
forge test --match-test "invariant_SharePriceMonotonicity"
```

### Fuzz Tests
```bash
# Run all fuzz tests
forge test --match-test "testFuzz_"

# Run with CI profile (10,000 runs)
forge test --match-test "testFuzz_" --profile ci

# Run specific fuzz test
forge test --match-test "testFuzz_BufferManagement"
```

## Configuration

The tests are configured for:
- **Fuzz runs**: 10,000+ iterations (via foundry.toml profile.ci)
- **Invariant runs**: 256 sequences (via foundry.toml profile.ci)
- **Realistic bounds**: All inputs bounded to realistic ranges
- **Comprehensive coverage**: Tests cover all critical invariants and edge cases

## Test Results Expected

All tests should pass, demonstrating:
1. **Vault security**: No funds can be lost or stolen
2. **Buffer integrity**: 5% buffer is always maintained when enabled
3. **Rate limiting**: Prevents abuse through excessive rebalancing
4. **Share price stability**: Share price behaves predictably
5. **Multi-user fairness**: All users get proportional treatment

## Handler Contract

The `MotherVaultInvariantHandler` contract provides bounded operations for invariant testing:
- Manages multiple test actors
- Performs realistic operations with proper bounds
- Tracks historical data for invariant verification
- Simulates time progression and complex scenarios

This comprehensive test suite ensures the MotherVault contract maintains all critical invariants under stress testing and real-world usage scenarios.