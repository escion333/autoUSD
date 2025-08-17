#!/usr/bin/env node

/**
 * Setup Hyperlane Domain Mappings
 * 
 * This script configures the domain mappings for Hyperlane V3 cross-chain messaging
 * between Base Sepolia, Ethereum Sepolia, and Katana Tatara testnets.
 */

const { ethers } = require('ethers');
require('dotenv').config();

// Domain configuration
const DOMAINS = {
    BASE_SEPOLIA: {
        id: 84532,
        name: 'Base Sepolia',
        rpc: process.env.BASE_SEPOLIA_RPC_URL || 'https://sepolia.base.org',
        mailbox: '0x6966b0E55883d49BFB24539356a2f8A673E02039',
        igp: '0x28B02B97a850872C4D33C3E024fab6499ad96564',
        ism: '0xC7Ee6061c213555033f414Ff1841c63e9fB0aFED'
    },
    ETHEREUM_SEPOLIA: {
        id: 11155111,
        name: 'Ethereum Sepolia',
        rpc: process.env.ETHEREUM_SEPOLIA_RPC_URL || 'https://eth-sepolia.g.alchemy.com/v2/demo',
        mailbox: '0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766',
        igp: '0x6f2756380FD49228ae25Aa7F2817993cB74Ecc56',
        ism: '0x4998C54633C45AC907F3465d8579ACB80E27AF1A'
    },
    KATANA_TATARA: {
        id: 129399,
        name: 'Katana Tatara',
        rpc: process.env.KATANA_TATARA_RPC_URL || 'https://rpc.tatara.katanarpc.com',
        mailbox: null, // To be deployed
        igp: null, // To be deployed
        ism: null // To be deployed
    }
};

// CCTP Domain mappings (for reference)
const CCTP_DOMAINS = {
    ETHEREUM: 0,
    BASE: 6,
    BASE_SEPOLIA: 10002
};

/**
 * Display domain configuration
 */
function displayDomainConfig() {
    console.log('\n=================================');
    console.log('Hyperlane Domain Configuration');
    console.log('=================================\n');
    
    for (const [key, domain] of Object.entries(DOMAINS)) {
        console.log(`${domain.name} (${key}):`);
        console.log(`  Domain ID: ${domain.id}`);
        console.log(`  RPC URL: ${domain.rpc}`);
        console.log(`  Mailbox: ${domain.mailbox || 'Not deployed'}`);
        console.log(`  IGP: ${domain.igp || 'Not deployed'}`);
        console.log(`  ISM: ${domain.ism || 'Not deployed'}`);
        console.log('');
    }
}

/**
 * Check if Hyperlane contracts are deployed on each network
 */
async function checkDeployments() {
    console.log('\n=================================');
    console.log('Checking Hyperlane Deployments');
    console.log('=================================\n');
    
    for (const [key, domain] of Object.entries(DOMAINS)) {
        if (!domain.mailbox) {
            console.log(`❌ ${domain.name}: Hyperlane not deployed`);
            continue;
        }
        
        try {
            const provider = new ethers.JsonRpcProvider(domain.rpc);
            
            // Check mailbox contract
            const mailboxCode = await provider.getCode(domain.mailbox);
            const hasMailbox = mailboxCode !== '0x' && mailboxCode !== '0x0';
            
            // Check IGP contract
            const igpCode = await provider.getCode(domain.igp);
            const hasIGP = igpCode !== '0x' && igpCode !== '0x0';
            
            if (hasMailbox && hasIGP) {
                console.log(`✅ ${domain.name}: Hyperlane deployed and active`);
                console.log(`   Mailbox: ${domain.mailbox}`);
                console.log(`   IGP: ${domain.igp}`);
            } else {
                console.log(`⚠️  ${domain.name}: Partial deployment`);
                if (!hasMailbox) console.log(`   Missing Mailbox at ${domain.mailbox}`);
                if (!hasIGP) console.log(`   Missing IGP at ${domain.igp}`);
            }
        } catch (error) {
            console.log(`❌ ${domain.name}: Failed to connect - ${error.message}`);
        }
    }
}

/**
 * Generate domain routing configuration for contracts
 */
function generateDomainRouting() {
    console.log('\n=================================');
    console.log('Domain Routing Configuration');
    console.log('=================================\n');
    
    console.log('For CrossChainMessenger.sol configuration:\n');
    
    // Base Sepolia routes
    console.log('Base Sepolia -> Ethereum Sepolia:');
    console.log(`  Source Domain: ${DOMAINS.BASE_SEPOLIA.id}`);
    console.log(`  Destination Domain: ${DOMAINS.ETHEREUM_SEPOLIA.id}`);
    console.log(`  Via: Hyperlane`);
    console.log('');
    
    console.log('Base Sepolia -> Katana Tatara:');
    console.log(`  Source Domain: ${DOMAINS.BASE_SEPOLIA.id}`);
    console.log(`  Destination Domain: ${DOMAINS.KATANA_TATARA.id}`);
    console.log(`  Via: Base -> Ethereum (Hyperlane) -> Katana (AggLayer)`);
    console.log('');
    
    // Ethereum Sepolia routes
    console.log('Ethereum Sepolia -> Base Sepolia:');
    console.log(`  Source Domain: ${DOMAINS.ETHEREUM_SEPOLIA.id}`);
    console.log(`  Destination Domain: ${DOMAINS.BASE_SEPOLIA.id}`);
    console.log(`  Via: Hyperlane`);
    console.log('');
    
    console.log('Ethereum Sepolia -> Katana Tatara:');
    console.log(`  Source Domain: ${DOMAINS.ETHEREUM_SEPOLIA.id}`);
    console.log(`  Destination Domain: ${DOMAINS.KATANA_TATARA.id}`);
    console.log(`  Via: AggLayer Unified Bridge`);
    console.log('');
    
    // Katana Tatara routes
    console.log('Katana Tatara -> Base Sepolia:');
    console.log(`  Source Domain: ${DOMAINS.KATANA_TATARA.id}`);
    console.log(`  Destination Domain: ${DOMAINS.BASE_SEPOLIA.id}`);
    console.log(`  Via: Katana -> Ethereum (AggLayer) -> Base (Hyperlane)`);
    console.log('');
}

/**
 * Generate environment variable configuration
 */
function generateEnvConfig() {
    console.log('\n=================================');
    console.log('Environment Variables');
    console.log('=================================\n');
    
    console.log('Add these to your .env files:\n');
    
    console.log('# Base Sepolia (.env.base.sepolia)');
    console.log(`HYPERLANE_MAILBOX_BASE=${DOMAINS.BASE_SEPOLIA.mailbox}`);
    console.log(`HYPERLANE_IGP_BASE=${DOMAINS.BASE_SEPOLIA.igp}`);
    console.log(`HYPERLANE_ISM_BASE=${DOMAINS.BASE_SEPOLIA.ism}`);
    console.log(`HYPERLANE_DOMAIN_BASE=${DOMAINS.BASE_SEPOLIA.id}`);
    console.log('');
    
    console.log('# Ethereum Sepolia (.env.ethereum.sepolia)');
    console.log(`HYPERLANE_MAILBOX_ETHEREUM=${DOMAINS.ETHEREUM_SEPOLIA.mailbox}`);
    console.log(`HYPERLANE_IGP_ETHEREUM=${DOMAINS.ETHEREUM_SEPOLIA.igp}`);
    console.log(`HYPERLANE_ISM_ETHEREUM=${DOMAINS.ETHEREUM_SEPOLIA.ism}`);
    console.log(`HYPERLANE_DOMAIN_ETHEREUM=${DOMAINS.ETHEREUM_SEPOLIA.id}`);
    console.log('');
    
    console.log('# Katana Tatara (.env.katana.tatara)');
    console.log(`# NOTE: Hyperlane not yet deployed on Katana`);
    console.log(`HYPERLANE_DOMAIN_KATANA=${DOMAINS.KATANA_TATARA.id}`);
    console.log('');
}

/**
 * Main execution
 */
async function main() {
    console.log('🚀 Hyperlane Domain Setup Tool');
    
    // Display configuration
    displayDomainConfig();
    
    // Check deployments
    await checkDeployments();
    
    // Generate routing config
    generateDomainRouting();
    
    // Generate env config
    generateEnvConfig();
    
    console.log('\n=================================');
    console.log('Next Steps');
    console.log('=================================\n');
    console.log('1. Update CrossChainMessenger.sol with domain mappings');
    console.log('2. Deploy MockMailbox for Katana Tatara testing');
    console.log('3. Configure trusted remotes in deployment scripts');
    console.log('4. Test message sending between chains');
    console.log('');
}

// Execute
main().catch(error => {
    console.error('Error:', error);
    process.exit(1);
});