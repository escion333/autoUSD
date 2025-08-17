#!/usr/bin/env node

const { ethers } = require('ethers');
const config = require('./config');

/**
 * Configure the AggLayer bridge address after deployment
 * This script should be run after obtaining the correct bridge address from AggLayer docs
 */
async function configureBridge() {
  try {
    console.log('\n===== CONFIGURING AGGLAYER BRIDGE =====\n');
    
    // Parse command line arguments
    const args = process.argv.slice(2);
    const bridgeAddress = args[0];
    const aggAdapterAddress = args[1] || process.env.AGGLAYER_ADAPTER;
    
    if (!bridgeAddress) {
      console.error('❌ Error: Bridge address is required');
      console.log('\nUsage: node configureBridge.js <bridgeAddress> [aggAdapterAddress]');
      console.log('\nTo find the bridge address:');
      console.log('1. Check https://docs.agglayer.dev for testnet addresses');
      console.log('2. Look for "Polygon zkEVM Bridge V2" or "Unified Bridge" contract');
      console.log('3. Use the address for Polygon Amoy testnet\n');
      process.exit(1);
    }
    
    if (!aggAdapterAddress) {
      console.error('❌ Error: AggLayerAdapter address is required');
      console.log('Set AGGLAYER_ADAPTER environment variable or pass as second argument');
      process.exit(1);
    }
    
    if (!config.user.privateKey) {
      throw new Error('PRIVATE_KEY not set in environment');
    }
    
    console.log(`Bridge Address: ${bridgeAddress}`);
    console.log(`AggLayerAdapter Address: ${aggAdapterAddress}`);
    
    // Connect to Polygon Amoy
    const provider = new ethers.JsonRpcProvider(config.polygonAmoy.rpcUrl);
    const wallet = new ethers.Wallet(config.user.privateKey, provider);
    
    console.log(`Connected to: ${config.polygonAmoy.name}`);
    console.log(`Wallet address: ${await wallet.getAddress()}`);
    
    // AggLayerAdapter ABI
    const aggAdapterAbi = [
      'function setBridgeAddress(address _bridge) external',
      'function bridge() view returns (address)',
      'function owner() view returns (address)'
    ];
    
    // Create contract instance
    const aggAdapter = new ethers.Contract(aggAdapterAddress, aggAdapterAbi, wallet);
    
    // Check if we're the owner
    const owner = await aggAdapter.owner();
    const walletAddress = await wallet.getAddress();
    
    if (owner.toLowerCase() !== walletAddress.toLowerCase()) {
      throw new Error(`Only owner can set bridge. Owner: ${owner}, Your address: ${walletAddress}`);
    }
    
    // Check if bridge is already set
    const currentBridge = await aggAdapter.bridge();
    if (currentBridge !== ethers.ZeroAddress) {
      console.log(`⚠️  Bridge already set to: ${currentBridge}`);
      console.log('Bridge can only be set once. Exiting.');
      return;
    }
    
    // Set the bridge address
    console.log('\n📝 Setting bridge address...');
    const tx = await aggAdapter.setBridgeAddress(bridgeAddress);
    
    console.log(`Transaction submitted: ${tx.hash}`);
    console.log('⏳ Waiting for confirmation...');
    
    const receipt = await tx.wait();
    
    if (receipt.status === 1) {
      console.log('\n✅ Bridge address configured successfully!');
      console.log(`Transaction hash: ${receipt.hash}`);
      console.log(`Gas used: ${receipt.gasUsed.toString()}`);
      
      // Verify the bridge was set
      const newBridge = await aggAdapter.bridge();
      console.log(`\nVerified bridge address: ${newBridge}`);
      
      // Save to environment
      console.log('\n📋 Add this to your .env file:');
      console.log(`POLYGON_BRIDGE_ADDRESS=${bridgeAddress}`);
      
      console.log('\n🎯 Next steps:');
      console.log('1. Deploy contracts to Katana Tatara');
      console.log('2. Configure cross-chain connections');
      console.log('3. Test bridge functionality using bridgeToKatana.js');
    } else {
      console.error('❌ Transaction failed');
    }
    
  } catch (error) {
    console.error('\n❌ Error configuring bridge:', error.message);
    process.exit(1);
  }
}

// Show usage if --help
if (process.argv.includes('--help')) {
  console.log(`
Usage: node configureBridge.js <bridgeAddress> [aggAdapterAddress]

Arguments:
  bridgeAddress      - AggLayer bridge contract address (required)
  aggAdapterAddress  - AggLayerAdapter contract address (optional if set in env)

Example:
  node configureBridge.js 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe

Environment variables required:
  PRIVATE_KEY - Private key of the deployer/owner
  POLYGON_AMOY_RPC_URL - Polygon Amoy RPC endpoint
  AGGLAYER_ADAPTER - AggLayerAdapter address (optional if passed as argument)

Note: The bridge address can only be set once. Make sure you have the correct address.
  `);
  process.exit(0);
}

// Run the configuration
configureBridge().catch(console.error);