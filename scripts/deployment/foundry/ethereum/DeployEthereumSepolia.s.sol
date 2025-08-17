// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "../../../../contracts/EthereumBridgeHub.sol";
import "../../../../contracts/core/CCTPBridge.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployEthereumSepolia is Script {
    // Ethereum Sepolia testnet addresses
    address constant USDC_ETHEREUM_SEPOLIA = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238; // Circle test USDC on Ethereum Sepolia
    
    // CCTP addresses on Ethereum Sepolia (from Circle docs)
    address constant TOKEN_MESSENGER = 0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5;
    address constant MESSAGE_TRANSMITTER = 0x7865fAfC2db2093669d92c0F33AeEF291086BEFD;
    
    // Unified Bridge address
    address constant UNIFIED_BRIDGE = 0x528e26b25a34a4A5d0dbDa1d57D318153d2ED582;
    
    // Hyperlane Mailbox on Ethereum Sepolia
    address constant HYPERLANE_MAILBOX = 0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766;
    
    // Domain IDs
    uint32 constant BASE_DOMAIN = 10002; // Base Sepolia domain for CCTP
    uint32 constant ETHEREUM_DOMAIN = 0; // Ethereum Sepolia domain for CCTP
    uint32 constant KATANA_NETWORK_ID = 29; // Katana network ID for Unified Bridge
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("\n===== ETHEREUM SEPOLIA DEPLOYMENT =====");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy CCTPBridge for Ethereum
        CCTPBridge cctpBridge = new CCTPBridge(
            TOKEN_MESSENGER,
            MESSAGE_TRANSMITTER,
            USDC_ETHEREUM_SEPOLIA,
            deployer // admin
        );
        console.log("CCTP Bridge deployed:", address(cctpBridge));
        
        // Deploy EthereumBridgeHub
        EthereumBridgeHub bridgeHub = new EthereumBridgeHub(
            USDC_ETHEREUM_SEPOLIA,
            address(cctpBridge),
            UNIFIED_BRIDGE,
            HYPERLANE_MAILBOX
        );
        console.log("Ethereum Bridge Hub deployed:", address(bridgeHub));
        
        // Configure CCTP Bridge for Base Sepolia
        cctpBridge.setSupportedDomain(BASE_DOMAIN, true);
        console.log("CCTP: Base Sepolia domain supported");
        
        console.log("\nEthereumBridgeHub Configuration:");
        console.log("- Supports Base Sepolia domain:", BASE_DOMAIN);
        console.log("- Supports Katana network ID:", KATANA_NETWORK_ID);
        console.log("- Minimal bridge coordination only");
        
        vm.stopBroadcast();
        
        console.log("\n===== DEPLOYMENT COMPLETE =====");
        console.log("\n--- Deployed Contracts ---");
        console.log("EthereumBridgeHub:", address(bridgeHub));
        console.log("CCTPBridge:", address(cctpBridge));
        
        console.log("\n--- Configuration ---");
        console.log("USDC Address:", USDC_ETHEREUM_SEPOLIA);
        console.log("Unified Bridge:", UNIFIED_BRIDGE);
        console.log("Hyperlane Mailbox:", HYPERLANE_MAILBOX);
        console.log("Token Messenger:", TOKEN_MESSENGER);
        console.log("Message Transmitter:", MESSAGE_TRANSMITTER);
        console.log("Base Domain:", BASE_DOMAIN);
        console.log("Ethereum Domain:", ETHEREUM_DOMAIN);
        console.log("Katana Network ID:", KATANA_NETWORK_ID);
        
        console.log("\n===== POST-DEPLOYMENT CONFIGURATION =====");
        console.log("Required steps to complete setup:");
        console.log("");
        console.log("1. Set Mother Vault address (after Base deployment):");
        console.log("   bridgeHub.setMotherVault(MOTHER_VAULT_ADDRESS)");
        console.log("");
        console.log("2. Set Katana Child Vault address (after Katana deployment):");
        console.log("   bridgeHub.setKatanaChildVault(KATANA_CHILD_VAULT_ADDRESS)");
        console.log("");
        console.log("3. Fund bridge hub with ETH for Unified Bridge gas fees:");
        console.log("   Send ~0.01 ETH to", address(bridgeHub));
        console.log("");
        console.log("4. Configure CCTP Bridge to recognize the hub:");
        console.log("   cctpBridge.setMotherVault(", address(bridgeHub), ")");
        console.log("");
        console.log("5. Test the complete flow:");
        console.log("   - CCTP bridge from Base to Ethereum");
        console.log("   - Unified Bridge from Ethereum to Katana");
        console.log("   - Return flow: Katana → Ethereum → Base");
        
        // Export for use in other scripts
        console.log("\n===== EXPORT COMMANDS =====");
        console.log("export ETHEREUM_BRIDGE_HUB=", address(bridgeHub));
        console.log("export CCTP_BRIDGE_ETHEREUM=", address(cctpBridge));
    }
}