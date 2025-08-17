#!/usr/bin/env node

const { ethers } = require('ethers');

async function checkBalance() {
    // Tatara testnet RPC
    const rpcUrl = 'https://rpc.tatara.katanarpc.com/';
    const provider = new ethers.JsonRpcProvider(rpcUrl);
    
    // Our test wallet address
    const address = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';
    
    try {
        // Get balance
        const balance = await provider.getBalance(address);
        const balanceInEth = ethers.formatEther(balance);
        
        // Get network info
        const network = await provider.getNetwork();
        const blockNumber = await provider.getBlockNumber();
        
        console.log('=================================');
        console.log('TATARA TESTNET BALANCE CHECK');
        console.log('=================================');
        console.log('Network:', network.name);
        console.log('Chain ID:', network.chainId.toString());
        console.log('Current Block:', blockNumber);
        console.log('=================================');
        console.log('Address:', address);
        console.log('Balance:', balanceInEth, 'ETH');
        console.log('Balance (Wei):', balance.toString());
        console.log('=================================');
        
        if (balance > 0n) {
            console.log('✅ Wallet has funds! Ready to deploy.');
            
            // Estimate deployment costs
            const estimatedGasPrice = await provider.getFeeData();
            console.log('\nGas Estimates:');
            console.log('Gas Price:', ethers.formatUnits(estimatedGasPrice.gasPrice || 0n, 'gwei'), 'gwei');
            
            // Rough estimate for contract deployment
            const deploymentGas = 3000000n; // 3M gas units for complex contract
            const estimatedCost = (estimatedGasPrice.gasPrice || 0n) * deploymentGas;
            console.log('Estimated deployment cost:', ethers.formatEther(estimatedCost), 'ETH');
            
            const deployments = balance / estimatedCost;
            console.log('Approximate deployments possible:', deployments.toString());
        } else {
            console.log('⚠️  No balance yet. Waiting for faucet...');
        }
        
    } catch (error) {
        console.error('Error checking balance:', error.message);
    }
}

checkBalance();