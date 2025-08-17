#!/usr/bin/env node

/**
 * Claim bridged USDC on Katana Tatara
 * Following official AggLayer documentation pattern
 */

const { getLxLyClient, tokens, waitForReadyToClaim } = require('./utils_lxly_official');
const config = require('./config_lxly');

const execute = async () => {
  try {
    console.log('\n===== CLAIMING BRIDGED USDC ON KATANA =====\n');
    
    // Get bridge transaction hash from command line or environment
    const bridgeTransactionHash = process.argv[2] || process.env.BRIDGE_TX_HASH;
    
    if (!bridgeTransactionHash) {
      console.error('❌ Error: Bridge transaction hash is required');
      console.log('\nUsage: node claim_asset.js <bridgeTxHash>');
      console.log('Or set BRIDGE_TX_HASH environment variable');
      process.exit(1);
    }
    
    console.log(`Bridge TX Hash: ${bridgeTransactionHash}`);
    
    // Initialize the lxly client
    console.log('\nInitializing LxLy client...');
    const client = await getLxLyClient();
    
    // Define network IDs
    const sourceNetworkId = 7;   // Polygon Amoy (where asset was bridged from)
    const destinationNetworkId = 100; // Katana Tatara (where we're claiming)
    
    console.log(`Source: Polygon Amoy (Network ID: ${sourceNetworkId})`);
    console.log(`Destination: Katana Tatara (Network ID: ${destinationNetworkId})`);
    
    // Wait for transaction to be ready to claim
    console.log('\n⏳ Checking if transaction is ready to claim...');
    const txStatus = await waitForReadyToClaim(bridgeTransactionHash);
    
    if (txStatus.status === 'CLAIMED') {
      console.log('✅ Asset already claimed!');
      return;
    }
    
    // Get the token API on destination network
    // Note: USDC becomes VBUSDC on Katana
    const token = client.erc20(tokens[destinationNetworkId].vbusdc, destinationNetworkId);
    
    // Claim the bridged asset
    console.log('\n💸 Claiming bridged asset...');
    const result = await token.claimAsset(
      bridgeTransactionHash,
      sourceNetworkId,
      { returnTransaction: false }
    );
    
    console.log('Claim initiated:', result);
    
    // Get transaction details
    const txHash = await result.getTransactionHash();
    console.log(`\n✅ Claim transaction submitted!`);
    console.log(`Transaction hash: ${txHash}`);
    
    const receipt = await result.getReceipt();
    console.log('\nTransaction receipt:', receipt);
    
    // Check final balance
    const balance = await token.getBalance(config.user1.address);
    console.log(`\n💰 New VBUSDC balance on Katana: ${balance / 1e6} VBUSDC`);
    
    console.log('\n🎉 Success! Your USDC has been bridged and claimed on Katana');
    
    // If this was for BridgeVault
    if (config.contracts.bridgeVault) {
      console.log('\n📦 Note: If bridged to BridgeVault:');
      console.log('- BridgeVault should now forward to Katana Child Vault');
      console.log(`- Child Vault: ${config.contracts.katanaChildVault}`);
      console.log('- Funds will be deployed to SushiSwap V3 pools');
    }
    
    return txHash;
    
  } catch (error) {
    console.error('\n❌ Error claiming asset:', error.message);
    
    // Provide helpful error messages
    if (error.message.includes('not ready')) {
      console.log('\n💡 Transaction not ready yet. Please wait and try again.');
      console.log('Typical wait time: 10-20 minutes after bridging');
    } else if (error.message.includes('already claimed')) {
      console.log('\n💡 This transaction was already claimed.');
    }
    
    process.exit(1);
  }
};

// Show usage if --help
if (process.argv.includes('--help')) {
  console.log(`
Usage: node claim_asset.js <bridgeTxHash>

Arguments:
  bridgeTxHash - Transaction hash from bridge_asset.js (required)

Examples:
  node claim_asset.js 0x123...abc
  
  Or with environment variable:
  export BRIDGE_TX_HASH=0x123...abc
  node claim_asset.js

Environment variables required:
  PRIVATE_KEY - Private key of the claimer
  USER_ADDRESS - Address derived from private key
  POLYGON_API_KEY - API key from Polygon portal

Note: 
- Claims must be made on the destination network (Katana)
- Wait for READY_TO_CLAIM status before attempting to claim
- Check status with: node check_status.js
  `);
  process.exit(0);
}

// Execute the claim
execute()
  .then(() => {
    console.log('\n✨ Claim operation completed successfully');
  })
  .catch(err => {
    console.error('Fatal error:', err);
  })
  .finally(() => {
    process.exit(0);
  });