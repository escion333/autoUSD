#!/usr/bin/env node

/**
 * Post-deployment configuration script for EthereumBridgeHub
 * 
 * This script configures the deployed contracts to work together:
 * 1. Sets Mother Vault address on Ethereum Bridge Hub
 * 2. Sets Katana Child Vault address on Ethereum Bridge Hub
 * 3. Funds the bridge hub with ETH for gas fees
 * 4. Verifies the configuration
 */

const { ethers } = require('ethers');
require('dotenv').config({ path: '.env.ethereum.sepolia' });

// Contract ABIs (minimal)
const BRIDGE_HUB_ABI = [
    'function setMotherVault(address _motherVault) external',
    'function setKatanaChildVault(address _vault) external',
    'function motherVault() external view returns (address)',
    'function katanaChildVault() external view returns (address)',
    'function getETHBalance() external view returns (uint256)',
    'function owner() external view returns (address)'
];

const CCTP_BRIDGE_ABI = [
    'function setMotherVault(address vault) external'
];

async function configureBridgeHub() {
    // Load configuration from environment
    const PRIVATE_KEY = process.env.PRIVATE_KEY;
    const RPC_URL = process.env.ETHEREUM_SEPOLIA_RPC_URL || 'https://eth-sepolia.g.alchemy.com/v2/demo';
    
    // Contract addresses (should be set after deployment)
    const BRIDGE_HUB_ADDRESS = process.env.ETHEREUM_BRIDGE_HUB;
    const CCTP_BRIDGE_ADDRESS = process.env.CCTP_BRIDGE_ETHEREUM;
    const MOTHER_VAULT_ADDRESS = process.env.MOTHER_VAULT_BASE;
    const KATANA_CHILD_VAULT_ADDRESS = process.env.KATANA_CHILD_VAULT;
    
    if (!PRIVATE_KEY) {
        console.error('❌ PRIVATE_KEY not set in environment');
        process.exit(1);
    }
    
    if (!BRIDGE_HUB_ADDRESS) {
        console.error('❌ ETHEREUM_BRIDGE_HUB not set. Deploy first.');
        process.exit(1);
    }
    
    console.log('🔧 Configuring Ethereum Bridge Hub...');
    console.log('Bridge Hub:', BRIDGE_HUB_ADDRESS);
    
    // Connect to Ethereum Sepolia
    const provider = new ethers.JsonRpcProvider(RPC_URL);
    const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
    console.log('Connected as:', wallet.address);
    
    // Get contract instances
    const bridgeHub = new ethers.Contract(BRIDGE_HUB_ADDRESS, BRIDGE_HUB_ABI, wallet);
    
    // Check ownership
    const owner = await bridgeHub.owner();
    if (owner.toLowerCase() !== wallet.address.toLowerCase()) {
        console.error('❌ You are not the owner of the Bridge Hub');
        console.error('Owner:', owner);
        console.error('Your address:', wallet.address);
        process.exit(1);
    }
    
    // 1. Set Mother Vault address
    if (MOTHER_VAULT_ADDRESS) {
        console.log('\n1️⃣ Setting Mother Vault address...');
        const currentMotherVault = await bridgeHub.motherVault();
        
        if (currentMotherVault === ethers.ZeroAddress) {
            const tx = await bridgeHub.setMotherVault(MOTHER_VAULT_ADDRESS);
            console.log('   Transaction:', tx.hash);
            await tx.wait();
            console.log('   ✅ Mother Vault set to:', MOTHER_VAULT_ADDRESS);
        } else {
            console.log('   ℹ️ Mother Vault already set to:', currentMotherVault);
        }
    } else {
        console.log('\n⚠️ MOTHER_VAULT_BASE not set. Skipping Mother Vault configuration.');
    }
    
    // 2. Set Katana Child Vault address
    if (KATANA_CHILD_VAULT_ADDRESS) {
        console.log('\n2️⃣ Setting Katana Child Vault address...');
        const currentChildVault = await bridgeHub.katanaChildVault();
        
        if (currentChildVault === ethers.ZeroAddress) {
            const tx = await bridgeHub.setKatanaChildVault(KATANA_CHILD_VAULT_ADDRESS);
            console.log('   Transaction:', tx.hash);
            await tx.wait();
            console.log('   ✅ Katana Child Vault set to:', KATANA_CHILD_VAULT_ADDRESS);
        } else {
            console.log('   ℹ️ Katana Child Vault already set to:', currentChildVault);
        }
    } else {
        console.log('\n⚠️ KATANA_CHILD_VAULT not set. Skipping Child Vault configuration.');
    }
    
    // 3. Check ETH balance for gas fees
    console.log('\n3️⃣ Checking ETH balance for bridge fees...');
    const ethBalance = await bridgeHub.getETHBalance();
    const ethBalanceFormatted = ethers.formatEther(ethBalance);
    console.log('   Current ETH balance:', ethBalanceFormatted, 'ETH');
    
    if (ethBalance < ethers.parseEther('0.001')) {
        console.log('   ⚠️ Low ETH balance. Consider sending ~0.01 ETH to:', BRIDGE_HUB_ADDRESS);
        
        // Optional: Auto-fund if needed
        const fundAmount = ethers.parseEther('0.01');
        console.log('   Sending 0.01 ETH to bridge hub...');
        const fundTx = await wallet.sendTransaction({
            to: BRIDGE_HUB_ADDRESS,
            value: fundAmount
        });
        console.log('   Transaction:', fundTx.hash);
        await fundTx.wait();
        console.log('   ✅ Funded with 0.01 ETH');
    } else {
        console.log('   ✅ Sufficient ETH balance for bridge operations');
    }
    
    // 4. Configure CCTP Bridge if needed
    if (CCTP_BRIDGE_ADDRESS) {
        console.log('\n4️⃣ Configuring CCTP Bridge...');
        const cctpBridge = new ethers.Contract(CCTP_BRIDGE_ADDRESS, CCTP_BRIDGE_ABI, wallet);
        
        try {
            const tx = await cctpBridge.setMotherVault(BRIDGE_HUB_ADDRESS);
            console.log('   Transaction:', tx.hash);
            await tx.wait();
            console.log('   ✅ CCTP Bridge configured to recognize Bridge Hub');
        } catch (error) {
            console.log('   ℹ️ CCTP Bridge may already be configured or you lack permissions');
        }
    }
    
    // 5. Verify final configuration
    console.log('\n📋 Final Configuration:');
    console.log('   Bridge Hub:', BRIDGE_HUB_ADDRESS);
    console.log('   Mother Vault:', await bridgeHub.motherVault());
    console.log('   Katana Child Vault:', await bridgeHub.katanaChildVault());
    console.log('   ETH Balance:', ethers.formatEther(await bridgeHub.getETHBalance()), 'ETH');
    
    console.log('\n✅ Configuration complete!');
    console.log('\nNext steps:');
    console.log('1. Test CCTP bridging from Base to Ethereum');
    console.log('2. Test Unified Bridge from Ethereum to Katana');
    console.log('3. Monitor bridge operations');
}

// Run the configuration
configureBridgeHub()
    .then(() => {
        console.log('\n🎉 Bridge Hub configuration successful!');
        process.exit(0);
    })
    .catch((error) => {
        console.error('\n❌ Configuration failed:', error);
        process.exit(1);
    });