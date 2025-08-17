#!/usr/bin/env node

/**
 * Bridge USDC from Polygon Amoy to Katana Tatara using SpecialK
 */

import { createWalletClient, createPublicClient, http, parseUnits } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { polygonAmoy } from 'viem/chains';
import { ILxLyBridge } from '../../katana-kit/contracts/ILxLyBridge.sol';

// Chain configuration
const TATARA_CHAIN_ID = 129399;
const POLYGON_AMOY_CHAIN_ID = 80002;

// Get configuration from environment
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const POLYGON_RPC = process.env.POLYGON_AMOY_RPC_URL || 'https://rpc-amoy.polygon.technology';
const USDC_POLYGON = '0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582';

// Bridge configuration (to be discovered)
const BRIDGE_ADDRESS = process.env.LXLY_BRIDGE_ADDRESS; // Need to find this

async function bridgeToTatara(amount, recipient) {
  console.log('🌉 Bridging USDC from Polygon Amoy to Katana Tatara');
  console.log(`Amount: ${amount} USDC`);
  console.log(`Recipient: ${recipient}`);
  
  if (!PRIVATE_KEY) {
    throw new Error('PRIVATE_KEY not set in environment');
  }
  
  if (!BRIDGE_ADDRESS) {
    console.error('❌ Bridge address not found');
    console.log('Options:');
    console.log('1. Use the bridge UI: https://bridge.katana.network/');
    console.log('2. Check katana-kit address mappings after building');
    console.log('3. Contact Katana team for bridge address');
    return;
  }
  
  // Setup account
  const account = privateKeyToAccount(PRIVATE_KEY);
  
  // Setup clients
  const publicClient = createPublicClient({
    chain: polygonAmoy,
    transport: http(POLYGON_RPC)
  });
  
  const walletClient = createWalletClient({
    account,
    chain: polygonAmoy,
    transport: http(POLYGON_RPC)
  });
  
  // Convert amount to wei (USDC has 6 decimals)
  const amountWei = parseUnits(amount.toString(), 6);
  
  try {
    // Check USDC balance
    const balance = await publicClient.readContract({
      address: USDC_POLYGON,
      abi: [
        {
          name: 'balanceOf',
          type: 'function',
          inputs: [{ name: 'account', type: 'address' }],
          outputs: [{ name: 'balance', type: 'uint256' }]
        }
      ],
      functionName: 'balanceOf',
      args: [account.address]
    });
    
    console.log(`Current USDC balance: ${balance / 1e6} USDC`);
    
    if (balance < amountWei) {
      throw new Error(`Insufficient balance. Have: ${balance / 1e6}, Need: ${amount}`);
    }
    
    // Approve bridge to spend USDC
    console.log('📝 Approving USDC...');
    const approveTx = await walletClient.writeContract({
      address: USDC_POLYGON,
      abi: [
        {
          name: 'approve',
          type: 'function',
          inputs: [
            { name: 'spender', type: 'address' },
            { name: 'amount', type: 'uint256' }
          ],
          outputs: [{ name: 'success', type: 'bool' }]
        }
      ],
      functionName: 'approve',
      args: [BRIDGE_ADDRESS, amountWei]
    });
    
    console.log(`Approval tx: ${approveTx}`);
    
    // Get network ID for Tatara
    const networkId = await publicClient.readContract({
      address: BRIDGE_ADDRESS,
      abi: ILxLyBridge.abi,
      functionName: 'networkID'
    });
    
    console.log(`Current network ID: ${networkId}`);
    
    // Bridge the assets
    console.log('🚀 Initiating bridge...');
    const bridgeTx = await walletClient.writeContract({
      address: BRIDGE_ADDRESS,
      abi: ILxLyBridge.abi,
      functionName: 'bridgeAsset',
      args: [
        TATARA_NETWORK_ID, // destination network
        recipient,         // recipient address
        amountWei,        // amount
        USDC_POLYGON,     // token
        true,             // force update global exit root
        '0x'              // no permit data
      ],
      value: 0n // No ETH needed for ERC20 bridging
    });
    
    console.log(`✅ Bridge transaction: ${bridgeTx}`);
    console.log(`View on explorer: https://amoy.polygonscan.com/tx/${bridgeTx}`);
    
    console.log('\n⏳ Bridge process started!');
    console.log('1. Wait 10-20 minutes for bridge to complete');
    console.log('2. Check status on bridge UI: https://bridge.katana.network/');
    console.log('3. Claim on Tatara if needed');
    
  } catch (error) {
    console.error('❌ Bridge failed:', error.message);
    throw error;
  }
}

// Parse command line arguments
const args = process.argv.slice(2);
const amount = args[0] || '10';
const recipient = args[1] || process.env.USER_ADDRESS;

if (!recipient) {
  console.error('❌ Recipient address required');
  console.log('Usage: node bridge-to-tatara.js <amount> <recipient>');
  process.exit(1);
}

// Execute bridge
bridgeToTatara(amount, recipient)
  .then(() => {
    console.log('✨ Bridge script completed');
    process.exit(0);
  })
  .catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });