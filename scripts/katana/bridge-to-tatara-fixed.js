#!/usr/bin/env node

/**
 * Bridge USDC from Polygon Amoy to Katana Tatara
 * FIXED VERSION - Properly handles imports and dependencies
 */

import { createWalletClient, createPublicClient, http, parseUnits } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { polygonAmoy } from 'viem/chains';
import dotenv from 'dotenv';

dotenv.config();

// Chain configuration
const TATARA_CHAIN_ID = 129399;
const POLYGON_AMOY_CHAIN_ID = 80002;
const TATARA_NETWORK_ID = 2; // Network ID in AggLayer (needs verification)

// Bridge ABI (instead of importing .sol file)
const BRIDGE_ABI = [
  {
    name: 'networkID',
    type: 'function',
    inputs: [],
    outputs: [{ type: 'uint32' }],
    stateMutability: 'view'
  },
  {
    name: 'bridgeAsset',
    type: 'function',
    inputs: [
      { name: 'destinationNetwork', type: 'uint32' },
      { name: 'destinationAddress', type: 'address' },
      { name: 'amount', type: 'uint256' },
      { name: 'token', type: 'address' },
      { name: 'forceUpdateGlobalExitRoot', type: 'bool' },
      { name: 'permitData', type: 'bytes' }
    ],
    outputs: [],
    stateMutability: 'payable'
  }
];

// Get configuration from environment
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const POLYGON_RPC = process.env.POLYGON_AMOY_RPC_URL || 'https://rpc-amoy.polygon.technology';
const USDC_POLYGON = '0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582';

// Bridge configuration (needs to be discovered)
const BRIDGE_ADDRESS = process.env.LXLY_BRIDGE_ADDRESS;

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
  
  // Setup account (handle both with and without 0x prefix)
  const privateKey = PRIVATE_KEY.startsWith('0x') ? PRIVATE_KEY : `0x${PRIVATE_KEY}`;
  const account = privateKeyToAccount(privateKey);
  
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
          outputs: [{ name: 'balance', type: 'uint256' }],
          stateMutability: 'view'
        }
      ],
      functionName: 'balanceOf',
      args: [account.address]
    });
    
    console.log(`Current USDC balance: ${Number(balance) / 1e6} USDC`);
    
    if (balance < amountWei) {
      throw new Error(`Insufficient balance. Have: ${Number(balance) / 1e6}, Need: ${amount}`);
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
          outputs: [{ name: 'success', type: 'bool' }],
          stateMutability: 'nonpayable'
        }
      ],
      functionName: 'approve',
      args: [BRIDGE_ADDRESS, amountWei]
    });
    
    console.log(`Approval tx: ${approveTx}`);
    
    // Get network ID for current network
    const networkId = await publicClient.readContract({
      address: BRIDGE_ADDRESS,
      abi: BRIDGE_ABI,
      functionName: 'networkID'
    });
    
    console.log(`Current network ID: ${networkId}`);
    
    // Bridge the assets
    console.log('🚀 Initiating bridge...');
    const bridgeTx = await walletClient.writeContract({
      address: BRIDGE_ADDRESS,
      abi: BRIDGE_ABI,
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
  console.log('Usage: node bridge-to-tatara-fixed.js <amount> <recipient>');
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