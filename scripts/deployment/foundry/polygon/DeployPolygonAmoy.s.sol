// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "../../contracts/BridgeVault.sol";
import "../../contracts/core/CCTPBridge.sol";
import "../../contracts/adapters/AggLayerAdapter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployPolygonAmoy is Script {
    // Polygon Amoy testnet addresses
    address constant USDC_POLYGON_AMOY = 0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582; // Circle test USDC on Polygon Amoy
    
    // CCTP addresses on Polygon Amoy (from Circle docs)
    address constant TOKEN_MESSENGER = 0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5;
    address constant MESSAGE_TRANSMITTER = 0x7865fAfC2db2093669d92c0F33AeEF291086BEFD;
    
    // AggLayer bridge will be set post-deployment using LxLy.js
    // See scripts/bridge/ for bridge configuration
    
    // Domain IDs
    uint32 constant BASE_DOMAIN = 10002; // Base Sepolia domain for CCTP
    uint32 constant POLYGON_DOMAIN = 7; // Polygon Amoy domain for CCTP
    uint32 constant KATANA_DOMAIN = 2; // Internal domain ID for Katana
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("\n===== POLYGON AMOY DEPLOYMENT =====");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Read mother vault address from env (should be deployed on Base Sepolia)
        address motherVault;
        try vm.envAddress("MOTHER_VAULT_BASE") returns (address addr) {
            motherVault = addr;
            require(motherVault != address(0), "Invalid MOTHER_VAULT_BASE address");
        } catch {
            revert("MOTHER_VAULT_BASE environment variable not set. Deploy Base Sepolia first.");
        }
        console.log("Mother Vault (Base):", motherVault);
        
        // Deploy CCTPBridge for Polygon
        CCTPBridge cctpBridge = new CCTPBridge(
            TOKEN_MESSENGER,
            MESSAGE_TRANSMITTER,
            USDC_POLYGON_AMOY,
            deployer // admin
        );
        console.log("CCTP Bridge deployed:", address(cctpBridge));
        
        // Deploy BridgeVault
        BridgeVault bridgeVault = new BridgeVault(
            USDC_POLYGON_AMOY,
            motherVault,
            address(cctpBridge)
        );
        console.log("Bridge Vault deployed:", address(bridgeVault));
        
        // Deploy AggLayerAdapter (bridge address will be set later)
        AggLayerAdapter aggAdapter = new AggLayerAdapter(
            USDC_POLYGON_AMOY,
            address(bridgeVault)
        );
        console.log("AggLayer Adapter deployed:", address(aggAdapter));
        console.log("NOTE: Bridge address must be set using setBridgeAddress() after obtaining from AggLayer");
        
        // Configure BridgeVault with AggLayer adapter
        bridgeVault.setAggLayerAdapter(address(aggAdapter));
        console.log("AggLayer Adapter configured in BridgeVault");
        
        // Configure CCTP Bridge
        cctpBridge.setSupportedDomain(BASE_DOMAIN, true);
        console.log("CCTP: Base Sepolia domain supported");
        
        // Configure BridgeVault
        bridgeVault.setMinBridgeAmount(1 * 1e6); // $1 minimum for testnet
        bridgeVault.setBridgeCooldown(300); // 5 minutes for testnet
        console.log("Bridge Vault configured: $1 min, 5 min cooldown");
        
        vm.stopBroadcast();
        
        console.log("\n===== DEPLOYMENT COMPLETE =====");
        console.log("\n--- Deployed Contracts ---");
        console.log("BridgeVault:", address(bridgeVault));
        console.log("CCTPBridge:", address(cctpBridge));
        console.log("AggLayerAdapter:", address(aggAdapter));
        
        console.log("\n--- Configuration ---");
        console.log("USDC Address:", USDC_POLYGON_AMOY);
        console.log("Token Messenger:", TOKEN_MESSENGER);
        console.log("Message Transmitter:", MESSAGE_TRANSMITTER);
        console.log("Base Domain:", BASE_DOMAIN);
        console.log("Polygon Domain:", POLYGON_DOMAIN);
        
        console.log("\n===== NEXT STEPS =====");
        console.log("1. Save BridgeVault address for Katana deployment");
        console.log("2. Deploy KatanaChildVault on Tatara");
        console.log("3. Connect BridgeVault to Katana via setKatanaChildVault");
        console.log("4. Configure AggLayer network IDs if needed");
        
        // Export for use in other scripts
        console.log("\n===== EXPORT COMMANDS =====");
        console.log("export BRIDGE_VAULT_POLYGON=", address(bridgeVault));
        console.log("export CCTP_BRIDGE_POLYGON=", address(cctpBridge));
        console.log("export AGGLAYER_ADAPTER=", address(aggAdapter));
    }
}