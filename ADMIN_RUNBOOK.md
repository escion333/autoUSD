# autoUSD Admin Recovery Runbook

## Overview

This runbook provides step-by-step procedures for autoUSD administrators to handle emergency situations, recover from failures, and maintain system health. The autoUSD platform consists of multiple components across different chains that require coordinated recovery procedures.

## Prerequisites

### Access Requirements
- **Default Admin Role**: Required for most emergency operations
- **Pauser Role**: Required for emergency pause/unpause operations  
- **Retrier Role**: Required for manual retry operations
- **Private Keys**: Secure access to admin wallets on all deployed chains
- **RPC Endpoints**: Reliable connection to Base, Katana, and Zircuit networks

### Tools Required
- **Foundry (forge/cast)**: For smart contract interactions
- **Environment Setup**: Properly configured `.env` file with admin private keys
- **Monitoring Dashboard**: Access to system health metrics

### Contract Addresses
Store these in your `.env` file for each network:
```bash
# Base L2 (Main contracts)
MOTHER_VAULT_ADDRESS=0x...
CCTP_BRIDGE_ADDRESS=0x...
CROSS_CHAIN_MESSENGER_ADDRESS=0x...
HEALTH_MONITOR_ADDRESS=0x...
REBALANCER_ADDRESS=0x...

# Katana L2
KATANA_CHILD_VAULT_ADDRESS=0x...

# Zircuit L2  
ZIRCUIT_CHILD_VAULT_ADDRESS=0x...
```

## Emergency Recovery Functions

### 1. Emergency Bridge Recovery (emergencyBridgeRecovery)

**When to Use:**
- CCTP bridge transfers stuck for >2 hours
- Bridge reached maximum retry attempts (3)
- User funds are trapped in a failed bridge operation
- Bridge marked as permanently failed

**Symptoms:**
- `BridgeTimedOut` or `BridgeFailed` events emitted
- User complaining about stuck USDC transfer
- Bridge nonce appears in failed bridges mapping

**Prerequisites:**
- Must have `DEFAULT_ADMIN_ROLE`
- Bridge must meet recovery criteria (timeout OR max retries OR explicitly failed)

**Execution Steps:**

1. **Identify the failed bridge:**
```bash
# Check if bridge is eligible for recovery
cast call $CCTP_BRIDGE_ADDRESS "pendingTransfers(uint64)" $NONCE --rpc-url $BASE_RPC

# Check failed bridge status
cast call $CCTP_BRIDGE_ADDRESS "failedBridges(uint64)" $NONCE --rpc-url $BASE_RPC
```

2. **Verify recovery eligibility:**
```bash
# Get bridge details
cast call $CCTP_BRIDGE_ADDRESS "canRetryBridge(uint64)" $NONCE --rpc-url $BASE_RPC
```

3. **Execute emergency recovery:**
```bash
# This refunds USDC to the original recipient
cast send $CCTP_BRIDGE_ADDRESS "emergencyBridgeRecovery(uint64)" $NONCE \
  --private-key $ADMIN_PRIVATE_KEY \
  --rpc-url $BASE_RPC \
  --gas-limit 200000
```

**Expected Outcomes:**
- USDC refunded to original sender/recipient
- Bridge marked as permanently failed
- `BridgeFailed` event emitted
- Pending transfer removed from mapping

**Verification:**
```bash
# Confirm bridge is cleaned up
cast call $CCTP_BRIDGE_ADDRESS "pendingTransfers(uint64)" $NONCE --rpc-url $BASE_RPC

# Check recipient balance increased
cast call $USDC_ADDRESS "balanceOf(address)" $RECIPIENT_ADDRESS --rpc-url $BASE_RPC
```

### 2. Manual Bridge Retry (manualRetryBridge)

**When to Use:**
- Automatic retry has failed but bridge is still recoverable
- Admin intervention needed to force retry outside normal delays
- Bridge infrastructure temporarily unavailable but now restored

**Symptoms:**
- Bridge stuck in pending state
- Retry delays preventing automatic recovery
- Bridge nonce not yet timed out or failed

**Prerequisites:**
- Must have `RETRIER_ROLE` 
- Transfer must exist in pendingTransfers mapping
- Bridge not in failed state

**Execution Steps:**

1. **Check bridge status:**
```bash
# Get current bridge state
cast call $CCTP_BRIDGE_ADDRESS "pendingTransfers(uint64)" $NONCE --rpc-url $BASE_RPC

# Check retry eligibility  
cast call $CCTP_BRIDGE_ADDRESS "canRetryBridge(uint64)" $NONCE --rpc-url $BASE_RPC
```

2. **Execute manual retry:**
```bash
# Force retry regardless of delays
cast send $CCTP_BRIDGE_ADDRESS "manualRetryBridge(uint64)" $NONCE \
  --private-key $RETRIER_PRIVATE_KEY \
  --rpc-url $BASE_RPC \
  --gas-limit 300000
```

**Expected Outcomes:**
- New bridge nonce generated
- Old pending transfer removed
- `BridgeRetried` event emitted with old and new nonces
- Bridge attempt continues with fresh nonce

**Verification:**
```bash
# Check for BridgeRetried event
cast logs --from-block latest --address $CCTP_BRIDGE_ADDRESS \
  "BridgeRetried(uint64,uint64,uint8)" --rpc-url $BASE_RPC

# Verify new pending transfer exists
cast call $CCTP_BRIDGE_ADDRESS "pendingTransfers(uint64)" $NEW_NONCE --rpc-url $BASE_RPC
```

### 3. Manual Message Retry (manualRetryMessage)

**When to Use:**
- Hyperlane messages failed to deliver
- Cross-chain communication stuck
- Message reached max automatic retries

**Symptoms:**
- `MessageRetryFailed` events in CrossChainMessenger
- User operations not completing cross-chain
- Messages in failed state in messenger contract

**Prerequisites:**
- Must have `RETRIER_ROLE`
- Message must exist in failedMessages mapping
- Not already resolved

**Execution Steps:**

1. **Identify failed message:**
```bash
# Get user's failed messages
cast call $CROSS_CHAIN_MESSENGER_ADDRESS "getUserFailedMessages(address)" $USER_ADDRESS --rpc-url $BASE_RPC

# Get specific message details
cast call $CROSS_CHAIN_MESSENGER_ADDRESS "getFailedMessage(bytes32)" $MESSAGE_ID --rpc-url $BASE_RPC
```

2. **Check message retry eligibility:**
```bash
cast call $CROSS_CHAIN_MESSENGER_ADDRESS "canRetryMessage(bytes32)" $MESSAGE_ID --rpc-url $BASE_RPC
```

3. **Calculate required gas payment:**
```bash
# Get gas quote for target chain
cast call $CROSS_CHAIN_MESSENGER_ADDRESS "estimateMessageFee(uint32)" $TARGET_CHAIN_ID --rpc-url $BASE_RPC
```

4. **Execute manual retry:**
```bash
cast send $CROSS_CHAIN_MESSENGER_ADDRESS "manualRetryMessage(bytes32)" $MESSAGE_ID \
  --private-key $RETRIER_PRIVATE_KEY \
  --rpc-url $BASE_RPC \
  --value $GAS_PAYMENT \
  --gas-limit 500000
```

**Expected Outcomes:**
- New message ID generated for retry
- Original message marked as resolved
- `MessageManuallyRetried` event emitted
- Message delivered to target chain

**Verification:**
```bash
# Check for successful retry event
cast logs --from-block latest --address $CROSS_CHAIN_MESSENGER_ADDRESS \
  "MessageManuallyRetried(bytes32,bytes32)" --rpc-url $BASE_RPC

# Verify message status updated
cast call $CROSS_CHAIN_MESSENGER_ADDRESS "getMessageStatus(bytes32)" $MESSAGE_ID --rpc-url $BASE_RPC
```

## Emergency Pause Procedures

### System-Wide Emergency Pause

**When to Use:**
- Critical security vulnerability discovered
- Major operational failure affecting user funds
- Coordinated attack detected
- Need to halt all operations immediately

**Execution Order:**
Execute in this specific order to ensure complete system shutdown:

1. **Pause Mother Vault (Base):**
```bash
cast send $MOTHER_VAULT_ADDRESS "emergencyPause()" \
  --private-key $PAUSER_PRIVATE_KEY \
  --rpc-url $BASE_RPC
```

2. **Pause CCTP Bridge (Base):**
```bash
cast send $CCTP_BRIDGE_ADDRESS "pause()" \
  --private-key $PAUSER_PRIVATE_KEY \
  --rpc-url $BASE_RPC
```

3. **Pause Cross Chain Messenger (Base):**
```bash
cast send $CROSS_CHAIN_MESSENGER_ADDRESS "pause()" \
  --private-key $PAUSER_PRIVATE_KEY \
  --rpc-url $BASE_RPC
```

4. **Pause Rebalancer (Base):**
```bash
cast send $REBALANCER_ADDRESS "pause()" \
  --private-key $PAUSER_PRIVATE_KEY \
  --rpc-url $BASE_RPC
```

5. **Pause Child Vaults:**
```bash
# Katana Child Vault
cast send $KATANA_CHILD_VAULT_ADDRESS "pause()" \
  --private-key $PAUSER_PRIVATE_KEY \
  --rpc-url $KATANA_RPC

# Zircuit Child Vault  
cast send $ZIRCUIT_CHILD_VAULT_ADDRESS "pause()" \
  --private-key $PAUSER_PRIVATE_KEY \
  --rpc-url $ZIRCUIT_RPC
```

**Verification:**
```bash
# Check all contracts are paused
cast call $MOTHER_VAULT_ADDRESS "paused()" --rpc-url $BASE_RPC
cast call $CCTP_BRIDGE_ADDRESS "paused()" --rpc-url $BASE_RPC
cast call $CROSS_CHAIN_MESSENGER_ADDRESS "paused()" --rpc-url $BASE_RPC
cast call $REBALANCER_ADDRESS "paused()" --rpc-url $BASE_RPC
cast call $KATANA_CHILD_VAULT_ADDRESS "paused()" --rpc-url $KATANA_RPC
cast call $ZIRCUIT_CHILD_VAULT_ADDRESS "paused()" --rpc-url $ZIRCUIT_RPC
```

### System-Wide Unpause

**Prerequisites:**
- All issues resolved and verified
- Security audit completed if applicable
- Team approval for resume operations

**Execution Order:**
Reverse order of pause to ensure dependencies are available:

1. **Unpause Child Vaults first:**
```bash
cast send $KATANA_CHILD_VAULT_ADDRESS "unpause()" \
  --private-key $PAUSER_PRIVATE_KEY \
  --rpc-url $KATANA_RPC

cast send $ZIRCUIT_CHILD_VAULT_ADDRESS "unpause()" \
  --private-key $PAUSER_PRIVATE_KEY \
  --rpc-url $ZIRCUIT_RPC
```

2. **Unpause Core Infrastructure:**
```bash
cast send $REBALANCER_ADDRESS "unpause()" \
  --private-key $PAUSER_PRIVATE_KEY \
  --rpc-url $BASE_RPC

cast send $CROSS_CHAIN_MESSENGER_ADDRESS "unpause()" \
  --private-key $PAUSER_PRIVATE_KEY \
  --rpc-url $BASE_RPC

cast send $CCTP_BRIDGE_ADDRESS "unpause()" \
  --private-key $PAUSER_PRIVATE_KEY \
  --rpc-url $BASE_RPC
```

3. **Unpause Mother Vault last:**
```bash
cast send $MOTHER_VAULT_ADDRESS "emergencyUnpause()" \
  --private-key $PAUSER_PRIVATE_KEY \
  --rpc-url $BASE_RPC
```

## Monitoring and Alerting Setup

### Health Check Commands

**System Health:**
```bash
# Get overall system health
cast call $HEALTH_MONITOR_ADDRESS "getSystemHealth()" --rpc-url $BASE_RPC

# Check specific child vault health
cast call $HEALTH_MONITOR_ADDRESS "getChildVaultHealth(uint32)" $DOMAIN_ID --rpc-url $BASE_RPC
```

**Bridge Health:**
```bash
# Check pending transfers
cast call $CCTP_BRIDGE_ADDRESS "getBridgeRetryConfiguration()" --rpc-url $BASE_RPC

# Get user failed bridges
cast call $CCTP_BRIDGE_ADDRESS "getUserFailedBridges(address)" $USER_ADDRESS --rpc-url $BASE_RPC
```

**Message Health:**
```bash
# Check message retry config
cast call $CROSS_CHAIN_MESSENGER_ADDRESS "getRetryConfiguration()" --rpc-url $BASE_RPC

# Get user failed messages
cast call $CROSS_CHAIN_MESSENGER_ADDRESS "getUserFailedMessages(address)" $USER_ADDRESS --rpc-url $BASE_RPC
```

### Automated Monitoring Script

Create a monitoring script that runs every 5 minutes:

```bash
#!/bin/bash
# monitor.sh

# Check if any contracts are paused
check_paused() {
  local contract=$1
  local rpc=$2
  local paused=$(cast call $contract "paused()" --rpc-url $rpc 2>/dev/null)
  if [ "$paused" == "true" ]; then
    echo "ALERT: $contract is paused"
    # Send alert to monitoring system
  fi
}

# Check for failed operations
check_failures() {
  # Monitor for BridgeFailed events in last hour
  local recent_block=$(($(cast block-number --rpc-url $BASE_RPC) - 300))
  local failures=$(cast logs --from-block $recent_block \
    --address $CCTP_BRIDGE_ADDRESS \
    "BridgeFailed(uint64)" \
    --rpc-url $BASE_RPC)
  
  if [ -n "$failures" ]; then
    echo "ALERT: Bridge failures detected: $failures"
  fi
}

# Execute checks
check_paused $MOTHER_VAULT_ADDRESS $BASE_RPC
check_paused $CCTP_BRIDGE_ADDRESS $BASE_RPC
check_failures
```

### Key Metrics to Monitor

1. **Bridge Metrics:**
   - Pending transfer count
   - Failed bridge rate
   - Average bridge time
   - Retry attempts per bridge

2. **Message Metrics:**
   - Failed message count
   - Message delivery success rate
   - Cross-chain latency
   - Gas payment failures

3. **Vault Metrics:**
   - Total TVL
   - Child vault response times
   - Rebalance frequency
   - Fee collection status

## Recovery Verification Steps

### Post-Recovery Checklist

After any recovery procedure:

1. **Verify Contract States:**
```bash
# Ensure no contracts are unexpectedly paused
./scripts/check_contract_states.sh

# Verify bridge queues are clear
cast call $CCTP_BRIDGE_ADDRESS "pendingTransfers(uint64)" $NONCE --rpc-url $BASE_RPC
```

2. **Test Basic Operations:**
```bash
# Test small deposit/withdraw
forge script script/anvil/TestDeposit.s.sol --rpc-url $BASE_RPC

# Test cross-chain message
# (Use integration test script)
```

3. **Monitor for 24 Hours:**
   - Watch for new failures
   - Monitor success rates
   - Check user operations completing

### Rollback Procedures

If recovery fails or causes additional issues:

1. **Immediate Actions:**
   - Re-pause affected contracts
   - Document the failure cause
   - Preserve logs and state

2. **Rollback Steps:**
```bash
# Emergency pause the problematic component
cast send $AFFECTED_CONTRACT "pause()" \
  --private-key $PAUSER_PRIVATE_KEY \
  --rpc-url $RELEVANT_RPC

# If bridge recovery failed, may need emergency withdrawal
cast send $CCTP_BRIDGE_ADDRESS "emergencyWithdraw(address,uint256)" \
  $RECOVERY_ADDRESS $AMOUNT \
  --private-key $ADMIN_PRIVATE_KEY \
  --rpc-url $BASE_RPC
```

3. **Investigation:**
   - Review transaction traces
   - Check event logs
   - Identify root cause
   - Plan alternative recovery

## Troubleshooting Common Issues

### Bridge Issues

**Issue: Bridge stuck in pending state**
- **Cause**: Network congestion, attestation delays
- **Solution**: Wait for automatic retry or use `manualRetryBridge`
- **Prevention**: Monitor bridge success rates

**Issue: Bridge immediately fails**
- **Cause**: Insufficient USDC balance, invalid recipient
- **Solution**: Check contract USDC balance, verify recipient address
- **Prevention**: Implement balance checks before bridging

**Issue: Attestation unavailable**
- **Cause**: Circle attestation service issues
- **Solution**: Wait for Circle service recovery, escalate if prolonged
- **Prevention**: Monitor Circle service status

### Message Issues

**Issue: Messages not reaching target chain**
- **Cause**: Insufficient gas payment, validator issues
- **Solution**: Use `manualRetryMessage` with higher gas payment
- **Prevention**: Monitor gas price fluctuations

**Issue: Message delivery reverts**
- **Cause**: Target contract state changed, invalid payload
- **Solution**: Investigate target contract state, may need manual intervention
- **Prevention**: Add message validation layers

### Vault Issues

**Issue: Child vault not responding**
- **Cause**: RPC issues, contract paused, network problems
- **Solution**: Check network status, verify RPC connectivity
- **Prevention**: Use multiple RPC endpoints

**Issue: Rebalancing stuck**
- **Cause**: Cross-chain latency, insufficient buffers
- **Solution**: Check cross-chain bridge health, verify buffer levels
- **Prevention**: Monitor rebalance success rates

## Contact Escalation Paths

### Internal Team
1. **Primary Admin**: Immediate response for critical issues
2. **Security Lead**: For potential security incidents
3. **Development Team**: For complex technical issues
4. **Operations Lead**: For user-facing problems

### External Contacts
1. **Circle Support**: For CCTP/attestation issues
2. **Hyperlane Team**: For message delivery problems
3. **RPC Providers**: For network connectivity issues
4. **Chain Teams**: For chain-specific problems (Base, Katana, Zircuit)

### Emergency Procedures
- **Critical Security Issue**: Pause all systems immediately, notify security lead
- **User Funds at Risk**: Execute emergency withdrawals, document all actions
- **Extended Downtime**: Communicate with users, prepare incident report

### Documentation Requirements
- Log all admin actions with timestamps
- Document decision rationale
- Preserve transaction hashes and block numbers
- Create incident reports for post-mortem analysis

---

## Appendix: Quick Reference

### Key Contract Functions
- `emergencyBridgeRecovery(uint64)` - Refund stuck bridge
- `manualRetryBridge(uint64)` - Force bridge retry
- `manualRetryMessage(bytes32)` - Force message retry
- `emergencyPause()` - Pause operations
- `emergencyUnpause()` - Resume operations

### Important Events to Monitor
- `BridgeFailed(uint64)`
- `BridgeTimedOut(uint64,uint256)`
- `MessageRetryFailed(bytes32,uint256)`
- `HealthCheckFailed(string)`

### Emergency Pause Order
1. Mother Vault
2. CCTP Bridge  
3. Cross Chain Messenger
4. Rebalancer
5. Child Vaults

### Emergency Unpause Order (Reverse)
1. Child Vaults
2. Rebalancer
3. Cross Chain Messenger
4. CCTP Bridge
5. Mother Vault

This runbook should be updated as the system evolves and new recovery procedures are identified.