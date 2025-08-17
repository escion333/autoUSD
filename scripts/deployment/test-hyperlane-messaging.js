#!/usr/bin/env node

/**
 * Test Hyperlane Messaging Between Testnets
 * 
 * This script deploys and tests simple Hyperlane message passing
 * between Base Sepolia and Ethereum Sepolia.
 */

const { ethers } = require('ethers');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

// Network configurations
const NETWORKS = {
    BASE_SEPOLIA: {
        name: 'Base Sepolia',
        rpc: process.env.BASE_SEPOLIA_RPC_URL || 'https://sepolia.base.org',
        chainId: 84532,
        domain: 84532,
        mailbox: '0x6966b0E55883d49BFB24539356a2f8A673E02039',
        igp: '0x28B02B97a850872C4D33C3E024fab6499ad96564',
        explorer: 'https://sepolia.basescan.org'
    },
    ETHEREUM_SEPOLIA: {
        name: 'Ethereum Sepolia',
        rpc: process.env.ETHEREUM_SEPOLIA_RPC_URL || 'https://eth-sepolia.g.alchemy.com/v2/demo',
        chainId: 11155111,
        domain: 11155111,
        mailbox: '0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766',
        igp: '0x6f2756380FD49228ae25Aa7F2817993cB74Ecc56',
        explorer: 'https://sepolia.etherscan.io'
    }
};

// Contract ABI (simplified for testing)
const TEST_MESSAGE_ABI = [
    'constructor(address _mailbox, address _igp)',
    'function sendMessage(uint32 _destination, string calldata _message) external payable',
    'function setRemoteDomain(uint32 _domain, address _address) external',
    'function quoteTotalPayment(uint32 _destination, string calldata _message) external view returns (uint256 dispatchPayment, uint256 igpPayment, uint256 totalPayment)',
    'function getReceivedMessageCount() external view returns (uint256)',
    'function receivedMessages(uint256) external view returns (uint32 origin, bytes32 sender, string message, uint256 timestamp)',
    'event MessageSent(uint32 indexed destination, string message, bytes32 messageId)',
    'event MessageReceived(uint32 indexed origin, bytes32 sender, string message)'
];

/**
 * Deploy test contract on a network
 */
async function deployTestContract(network, signer) {
    console.log(`\nDeploying on ${network.name}...`);
    
    // Read compiled contract
    const artifactPath = path.join(
        __dirname,
        '../../out/HyperlaneTestMessage.sol/HyperlaneTestMessage.json'
    );
    
    if (!fs.existsSync(artifactPath)) {
        console.error('❌ Contract not compiled. Please run:');
        console.error('   forge build');
        console.error('');
        console.error('If forge is not installed, install it with:');
        console.error('   curl -L https://foundry.paradigm.xyz | bash');
        console.error('   foundryup');
        throw new Error('Contract artifacts not found');
    }
    
    let artifact;
    try {
        artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));
    } catch (error) {
        console.error('❌ Failed to parse contract artifact:', error.message);
        throw new Error('Invalid contract artifact format');
    }
    
    if (!artifact.abi || !artifact.bytecode || !artifact.bytecode.object) {
        console.error('❌ Invalid contract artifact structure');
        console.error('   Expected: abi, bytecode.object');
        console.error('   Found:', Object.keys(artifact));
        throw new Error('Incomplete contract artifact');
    }
    
    // Deploy contract
    let factory;
    try {
        factory = new ethers.ContractFactory(
            artifact.abi,
            artifact.bytecode.object,
            signer
        );
    } catch (error) {
        console.error('❌ Failed to create contract factory:', error.message);
        throw new Error('Contract factory creation failed');
    }
    
    let contract;
    try {
        console.log(`   Deploying with mailbox: ${network.mailbox}`);
        console.log(`   Deploying with IGP: ${network.igp}`);
        contract = await factory.deploy(network.mailbox, network.igp);
        const deployTx = contract.deploymentTransaction || contract.deployTransaction;
        if (deployTx) {
            console.log(`   Transaction hash: ${deployTx.hash}`);
        }
        console.log(`   Waiting for confirmation...`);
        await contract.waitForDeployment();
    } catch (error) {
        console.error('❌ Deployment failed:', error.message);
        if (error.reason) console.error('   Reason:', error.reason);
        if (error.data) console.error('   Data:', error.data);
        throw new Error('Contract deployment failed');
    }
    
    const address = await contract.getAddress();
    console.log(`✅ Deployed at: ${address}`);
    console.log(`   Explorer: ${network.explorer}/address/${address}`);
    
    return contract;
}

/**
 * Setup remote domains
 */
async function setupRemoteDomains(contractBase, contractEth, baseNetwork, ethNetwork) {
    console.log('\n📋 Setting up remote domains...');
    
    try {
        // Set Ethereum as remote for Base
        const ethAddress = await contractEth.getAddress();
        console.log(`   Setting Ethereum (${ethNetwork.domain}) remote to ${ethAddress}...`);
        const tx1 = await contractBase.setRemoteDomain(ethNetwork.domain, ethAddress);
        await tx1.wait();
        console.log(`✅ Base -> Ethereum remote set`);
        
        // Set Base as remote for Ethereum
        const baseAddress = await contractBase.getAddress();
        console.log(`   Setting Base (${baseNetwork.domain}) remote to ${baseAddress}...`);
        const tx2 = await contractEth.setRemoteDomain(baseNetwork.domain, baseAddress);
        await tx2.wait();
        console.log(`✅ Ethereum -> Base remote set`);
    } catch (error) {
        console.error('❌ Failed to setup remote domains:', error.message);
        if (error.reason) console.error('   Reason:', error.reason);
        throw error;
    }
}

/**
 * Send test message
 */
async function sendTestMessage(contract, fromNetwork, toNetwork, message) {
    console.log(`\n📤 Sending message from ${fromNetwork.name} to ${toNetwork.name}`);
    console.log(`   Message: "${message}"`);
    
    try {
        // Quote total payment (dispatch + IGP)
        const { dispatchPayment, igpPayment, totalPayment } = await contract.quoteTotalPayment(toNetwork.domain, message);
        console.log(`   Dispatch payment: ${ethers.formatEther(dispatchPayment)} ETH`);
        console.log(`   IGP payment: ${ethers.formatEther(igpPayment)} ETH`);
        console.log(`   Total payment required: ${ethers.formatEther(totalPayment)} ETH`);
        
        // Check balance is sufficient
        const signer = contract.runner;
        const balance = await signer.provider.getBalance(signer.address);
        if (balance < totalPayment) {
            throw new Error(`Insufficient balance. Have ${ethers.formatEther(balance)} ETH, need ${ethers.formatEther(totalPayment)} ETH`);
        }
        
        // Send message
        const tx = await contract.sendMessage(toNetwork.domain, message, {
            value: totalPayment
        });
        
        console.log(`   Tx hash: ${tx.hash}`);
        const receipt = await tx.wait();
        
        if (!receipt.status) {
            throw new Error('Transaction reverted');
        }
    
        // Find MessageSent event
        const event = receipt.logs.find(log => {
            try {
                const parsed = contract.interface.parseLog(log);
                return parsed && parsed.name === 'MessageSent';
            } catch {
                return false;
            }
        });
        
        if (event) {
            const parsed = contract.interface.parseLog(event);
            console.log(`✅ Message sent! ID: ${parsed.args.messageId}`);
            console.log(`   Track on Hyperlane Explorer:`);
            console.log(`   https://explorer.hyperlane.xyz/message/${parsed.args.messageId}`);
            return parsed.args.messageId;
        }
        
        console.warn('⚠️  Message sent but no MessageSent event found');
        return null;
    } catch (error) {
        console.error(`❌ Failed to send message:`, error.message);
        if (error.reason) console.error('   Reason:', error.reason);
        if (error.data) console.error('   Data:', error.data);
        throw error;
    }
}

/**
 * Check for received messages
 */
async function checkReceivedMessages(contract, network) {
    console.log(`\n📥 Checking received messages on ${network.name}...`);
    
    const count = await contract.getReceivedMessageCount();
    console.log(`   Total messages received: ${count}`);
    
    if (count > 0) {
        // Convert BigInt to Number for array indexing
        const latestIndex = Number(count) - 1;
        const message = await contract.receivedMessages(latestIndex);
        console.log(`   Latest message:`);
        console.log(`     From domain: ${message.origin}`);
        console.log(`     Message: "${message.message}"`);
        console.log(`     Timestamp: ${new Date(Number(message.timestamp) * 1000).toISOString()}`);
    }
    
    return count;
}

/**
 * Main execution
 */
async function main() {
    console.log('🚀 Hyperlane Messaging Test');
    console.log('==========================\n');
    
    // Check for private key
    const privateKey = process.env.PRIVATE_KEY;
    if (!privateKey) {
        console.error('❌ Error: PRIVATE_KEY not set in environment');
        process.exit(1);
    }
    
    // Setup providers and signers
    const providerBase = new ethers.JsonRpcProvider(NETWORKS.BASE_SEPOLIA.rpc);
    const providerEth = new ethers.JsonRpcProvider(NETWORKS.ETHEREUM_SEPOLIA.rpc);
    
    const signerBase = new ethers.Wallet(privateKey, providerBase);
    const signerEth = new ethers.Wallet(privateKey, providerEth);
    
    console.log(`Wallet address: ${signerBase.address}`);
    
    // Check balances
    const balanceBase = await providerBase.getBalance(signerBase.address);
    const balanceEth = await providerEth.getBalance(signerEth.address);
    
    console.log(`\nBalances:`);
    console.log(`  Base Sepolia: ${ethers.formatEther(balanceBase)} ETH`);
    console.log(`  Ethereum Sepolia: ${ethers.formatEther(balanceEth)} ETH`);
    
    if (balanceBase === 0n || balanceEth === 0n) {
        console.error('\n❌ Error: Insufficient balance. Get testnet ETH from faucets:');
        console.error('   Base Sepolia: https://www.alchemy.com/faucets/base-sepolia');
        console.error('   Ethereum Sepolia: https://www.alchemy.com/faucets/ethereum-sepolia');
        process.exit(1);
    }
    
    // Deploy contracts
    console.log('\n📦 Deploying test contracts...');
    let contractBase, contractEth;
    
    try {
        contractBase = await deployTestContract(NETWORKS.BASE_SEPOLIA, signerBase);
        contractEth = await deployTestContract(NETWORKS.ETHEREUM_SEPOLIA, signerEth);
    } catch (error) {
        console.error('\n❌ Deployment failed:', error.message);
        console.error('\nTroubleshooting tips:');
        console.error('1. Ensure you have enough ETH on both networks');
        console.error('2. Check that the RPC URLs are correct');
        console.error('3. Verify the contract compiles: forge build');
        console.error('4. Check network status on:');
        console.error('   - https://sepolia.basescan.org');
        console.error('   - https://sepolia.etherscan.io');
        process.exit(1);
    }
    
    // Setup remote domains
    await setupRemoteDomains(contractBase, contractEth, NETWORKS.BASE_SEPOLIA, NETWORKS.ETHEREUM_SEPOLIA);
    
    // Send test messages
    console.log('\n🔄 Testing bidirectional messaging...');
    
    // Base -> Ethereum
    const messageId1 = await sendTestMessage(
        contractBase,
        NETWORKS.BASE_SEPOLIA,
        NETWORKS.ETHEREUM_SEPOLIA,
        'Hello from Base Sepolia!'
    );
    
    // Ethereum -> Base
    const messageId2 = await sendTestMessage(
        contractEth,
        NETWORKS.ETHEREUM_SEPOLIA,
        NETWORKS.BASE_SEPOLIA,
        'Hello from Ethereum Sepolia!'
    );
    
    // Wait for messages to be delivered
    console.log('\n⏳ Waiting 30 seconds for message delivery...');
    await new Promise(resolve => setTimeout(resolve, 30000));
    
    // Check received messages
    await checkReceivedMessages(contractBase, NETWORKS.BASE_SEPOLIA);
    await checkReceivedMessages(contractEth, NETWORKS.ETHEREUM_SEPOLIA);
    
    console.log('\n✅ Test complete!');
    console.log('\nDeployed contracts:');
    console.log(`  Base Sepolia: ${await contractBase.getAddress()}`);
    console.log(`  Ethereum Sepolia: ${await contractEth.getAddress()}`);
    
    if (messageId1) {
        console.log(`\nTrack messages:`);
        console.log(`  https://explorer.hyperlane.xyz/message/${messageId1}`);
        console.log(`  https://explorer.hyperlane.xyz/message/${messageId2}`);
    }
}

// Execute
main().catch(error => {
    console.error('❌ Error:', error);
    process.exit(1);
});