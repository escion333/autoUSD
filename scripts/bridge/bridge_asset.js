#!/usr/bin/env node

/**
 * Bridge USDC from Polygon Amoy to Katana Tatara
 * Following official AggLayer documentation pattern
 */

const { getLxLyClient, tokens } = require('./utils_lxly_official');
const config = require('./config_lxly');

const execute = async () => {
  try {
    console.log('\n===== BRIDGING USDC: POLYGON AMOY → KATANA TATARA =====\n');
    
    // Parse command line arguments
    const args = process.argv.slice(2);
    const amount = args[0] || '10'; // Default 10 USDC
    const recipient = args[1] || config.user1.address;
    
    // Initialize the lxly client
    console.log('Initializing LxLy client...');
    const client = await getLxLyClient();
    
    // Define network IDs
    const sourceNetworkId = 7;   // Polygon Amoy
    const destinationNetworkId = 100; // Katana Tatara (placeholder - needs AggLayer registration)
    
    console.log(`Source: Polygon Amoy (Network ID: ${sourceNetworkId})`);
    console.log(`Destination: Katana Tatara (Network ID: ${destinationNetworkId})`);
    console.log(`Amount: ${amount} USDC`);
    console.log(`Recipient: ${recipient}`);
    
    // Get the USDC token API on source network
    const token = client.erc20(tokens[sourceNetworkId].usdc, sourceNetworkId);
    
    // Convert USDC amount to wei (6 decimals for USDC)
    // Using BigInt to avoid precision loss
    const amountWei = (BigInt(amount) * BigInt(1000000)).toString();
    console.log(`Amount in wei: ${amountWei}`);
    
    // Check balance before bridging
    const balance = await token.getBalance(config.user1.address);
    console.log(`Current USDC balance: ${balance / 1e6} USDC`);
    
    if (BigInt(balance) < BigInt(amountWei)) {
      throw new Error(`Insufficient balance. Have: ${balance / 1e6} USDC, Need: ${amount} USDC`);
    }
    
    // Bridge the asset
    console.log('\n📤 Initiating bridge transaction...');
    const result = await token.bridgeAsset(
      amountWei,
      recipient,
      destinationNetworkId
    );
    
    // Get transaction details
    const txHash = await result.getTransactionHash();
    console.log(`\n✅ Bridge transaction submitted!`);
    console.log(`Transaction hash: ${txHash}`);
    
    const receipt = await result.getReceipt();
    console.log('\nTransaction receipt:', receipt);
    
    // Save transaction hash for claiming
    console.log('\n💾 IMPORTANT: Save this transaction hash for claiming:');
    console.log(`export BRIDGE_TX_HASH=${txHash}`);
    
    console.log('\n⏳ Bridge Status:');
    console.log('1. Transaction is now in BRIDGED state');
    console.log('2. Wait 10-20 minutes for READY_TO_CLAIM state');
    console.log('3. Check status: node check_status.js');
    console.log('4. Claim on destination: node claim_asset.js');
    
    // If bridging to BridgeVault contract
    if (recipient === config.contracts.bridgeVault) {
      console.log('\n📦 Note: Bridging to BridgeVault contract');
      console.log('BridgeVault will forward to Katana Child Vault automatically');
    }
    
    return txHash;
    
  } catch (error) {
    console.error('\n❌ Error bridging asset:', error.message);
    process.exit(1);
  }
};

// Show usage if --help
if (process.argv.includes('--help')) {
  console.log(`
Usage: node bridge_asset.js [amount] [recipient]

Arguments:
  amount     - Amount of USDC to bridge (default: 10)
  recipient  - Recipient address on Katana (default: sender address)

Examples:
  node bridge_asset.js
  node bridge_asset.js 100
  node bridge_asset.js 50 0x123...abc

Environment variables required:
  PRIVATE_KEY - Private key of the sender
  USER_ADDRESS - Address derived from private key
  POLYGON_API_KEY - API key from Polygon portal

Note: This follows the official AggLayer bridge pattern using LxLy.js
  `);
  process.exit(0);
}

// Execute the bridge
execute()
  .then(() => {
    console.log('\n✨ Bridge operation completed successfully');
  })
  .catch(err => {
    console.error('Fatal error:', err);
  })
  .finally(() => {
    process.exit(0);
  });