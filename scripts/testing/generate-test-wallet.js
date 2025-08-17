#!/usr/bin/env node

// Simple script to generate a test wallet
const { ethers } = require('ethers');

// Generate a random wallet
const wallet = ethers.Wallet.createRandom();

console.log('=================================');
console.log('TEST WALLET GENERATED');
console.log('=================================');
console.log('Address:', wallet.address);
console.log('Private Key:', wallet.privateKey);
console.log('=================================');
console.log('⚠️  WARNING: This is for TESTNET only!');
console.log('⚠️  NEVER use this for mainnet!');
console.log('=================================');
console.log('\nTo use this wallet:');
console.log('1. Send this address to get test ETH from Tatara faucet:', wallet.address);
console.log('2. Add to your .env file:');
console.log(`PRIVATE_KEY=${wallet.privateKey}`);
console.log('\nFaucet URL: https://faucets.chain.link/polygon-testnet-tatara');