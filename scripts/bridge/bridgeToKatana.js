#!/usr/bin/env node

const { ethers } = require('ethers');
const { getLxLyClient, waitForBridgeReady } = require('./utils_lxly');
const config = require('./config');

/**
 * Bridge USDC from Polygon Amoy to Katana Tatara
 */
async function bridgeToKatana() {
  try {
    console.log('\n===== BRIDGING USDC: POLYGON AMOY → KATANA TATARA =====\n');
    
    // Parse command line arguments
    const args = process.argv.slice(2);
    const amount = args[0] || '10'; // Default 10 USDC
    const recipient = args[1] || config.user.address;
    
    if (!config.user.privateKey) {
      throw new Error('PRIVATE_KEY not set in environment');
    }
    
    // Convert amount to wei (USDC has 6 decimals)
    const amountWei = ethers.parseUnits(amount, 6);
    console.log(`Amount to bridge: ${amount} USDC (${amountWei.toString()} wei)`);
    
    // Initialize bridge client
    const bridgeClient = await getLxLyClient('polygonAmoy', 'katanaTatara');
    
    // Get provider and wallet for Polygon
    const provider = new ethers.JsonRpcProvider(config.polygonAmoy.rpcUrl);
    const wallet = new ethers.Wallet(config.user.privateKey, provider);
    const userAddress = await wallet.getAddress();
    
    // Check USDC balance on Polygon
    const usdcContract = new ethers.Contract(
      config.tokens.usdcPolygon,
      ['function balanceOf(address) view returns (uint256)'],
      provider
    );
    
    const balance = await usdcContract.balanceOf(userAddress);
    console.log(`Current USDC balance on Polygon: ${ethers.formatUnits(balance, 6)} USDC`);
    
    if (balance < amountWei) {
      throw new Error(`Insufficient USDC balance. Have: ${ethers.formatUnits(balance, 6)}, Need: ${amount}`);
    }
    
    // Check if we're bridging through BridgeVault or directly
    const targetAddress = config.contracts.bridgeVault || recipient;
    console.log(`Recipient address on Katana: ${targetAddress}`);
    
    // Execute bridge transaction
    console.log('\nInitiating bridge transaction...');
    const result = await bridgeClient.bridgeAsset(
      config.tokens.usdcPolygon,
      amountWei.toString(),
      targetAddress
    );
    
    if (result.success) {
      console.log('✅ Bridge transaction initiated successfully!');
      console.log('Transaction details:', result.data);
      
      // Note: In production, we would get the actual tx hash from the result
      // and wait for it to be ready to claim
      console.log('\n⏳ Waiting for bridge to complete...');
      console.log('This typically takes 10-20 minutes for testnet');
      console.log('\nTo check status, run:');
      console.log(`npm run check:status -- <txHash>`);
      
      // If using BridgeVault, it should automatically forward to Katana
      if (config.contracts.bridgeVault) {
        console.log('\n📦 BridgeVault will automatically forward funds to Katana');
        console.log(`Katana Child Vault: ${config.contracts.katanaChildVault}`);
      }
    } else {
      console.error('❌ Bridge transaction failed:', result.message);
    }
    
  } catch (error) {
    console.error('\n❌ Error bridging to Katana:', error.message);
    process.exit(1);
  }
}

// Show usage if --help
if (process.argv.includes('--help')) {
  console.log(`
Usage: node bridgeToKatana.js [amount] [recipient]

Arguments:
  amount     - Amount of USDC to bridge (default: 10)
  recipient  - Recipient address on Katana (default: sender address)

Examples:
  node bridgeToKatana.js 100
  node bridgeToKatana.js 50 0x123...abc

Environment variables required:
  PRIVATE_KEY - Private key of the sender
  POLYGON_AMOY_RPC_URL - Polygon Amoy RPC endpoint
  KATANA_TATARA_RPC_URL - Katana Tatara RPC endpoint
  `);
  process.exit(0);
}

// Run the bridge function
bridgeToKatana().catch(console.error);