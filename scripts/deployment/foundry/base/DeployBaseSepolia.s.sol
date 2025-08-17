// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "../../contracts/MotherVault.sol";
import "../../contracts/core/CCTPBridge.sol";
import "../../contracts/core/CrossChainMessenger.sol";
import "../../contracts/core/Rebalancer.sol";
import "../../contracts/core/YieldDistributor.sol";
import "../../contracts/core/HealthMonitor.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployBaseSepolia is Script {
    // Base Sepolia testnet addresses
    address constant USDC_BASE_SEPOLIA = 0x036CbD53842c5426634e7929541eC2318f3dCF7e; // Circle test USDC on Base Sepolia
    
    // CCTP addresses on Base Sepolia (from Circle docs)
    address constant TOKEN_MESSENGER = 0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5;
    address constant MESSAGE_TRANSMITTER = 0x7865fAfC2db2093669d92c0F33AeEF291086BEFD;
    
    // Hyperlane V3 addresses on Base Sepolia
    address constant HYPERLANE_MAILBOX = 0x6966b0E55883d49BFB24539356a2f8A673E02039;
    address constant HYPERLANE_IGP = 0x0dD20e410bdB95404f71c5a4e7Fa67B892A5f949; // Interchain Gas Paymaster
    
    // Domain IDs
    uint32 constant BASE_DOMAIN = 10002; // Base Sepolia domain for CCTP
    uint32 constant POLYGON_DOMAIN = 7; // Polygon Amoy domain for CCTP
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address treasury = deployer; // Use deployer as treasury for testnet
        
        console.log("\n===== BASE SEPOLIA DEPLOYMENT =====");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy MotherVault
        MotherVault motherVault = new MotherVault(
            USDC_BASE_SEPOLIA,
            "autoUSD Vault",
            "aUSD"
        );
        console.log("MotherVault deployed:", address(motherVault));
        
        // Check USDC balance
        uint256 usdcBalance = IERC20(USDC_BASE_SEPOLIA).balanceOf(deployer);
        console.log("Deployer USDC balance:", usdcBalance / 1e6, "USDC");
        
        // Note: MotherVault will be initialized after deploying CrossChainMessenger and CCTPBridge
        
        // Deploy CCTPBridge
        CCTPBridge cctpBridge = new CCTPBridge(
            TOKEN_MESSENGER,
            MESSAGE_TRANSMITTER,
            USDC_BASE_SEPOLIA,
            deployer // admin
        );
        console.log("CCTPBridge deployed:", address(cctpBridge));
        
        // Deploy CrossChainMessenger
        CrossChainMessenger messenger = new CrossChainMessenger(
            HYPERLANE_MAILBOX,
            HYPERLANE_IGP,
            address(cctpBridge),
            address(motherVault),
            deployer // admin
        );
        console.log("CrossChainMessenger deployed:", address(messenger));
        
        // Deploy Rebalancer
        Rebalancer rebalancer = new Rebalancer(
            address(motherVault)
        );
        console.log("Rebalancer deployed:", address(rebalancer));
        
        // Deploy YieldDistributor
        YieldDistributor yieldDist = new YieldDistributor(
            USDC_BASE_SEPOLIA,
            address(motherVault),
            treasury,
            50 // 0.5% management fee
        );
        console.log("YieldDistributor deployed:", address(yieldDist));
        
        // Deploy HealthMonitor
        HealthMonitor healthMon = new HealthMonitor(
            address(motherVault),
            address(messenger),
            address(rebalancer),
            deployer // admin
        );
        console.log("HealthMonitor deployed:", address(healthMon));
        
        // Initialize MotherVault with CrossChainMessenger and CCTPBridge
        if (usdcBalance >= 100 * 1e6) {
            IERC20(USDC_BASE_SEPOLIA).approve(address(motherVault), 100 * 1e6);
            motherVault.initialize(
                address(messenger),
                address(cctpBridge)
            );
            console.log("MotherVault initialized with CrossChainMessenger and CCTPBridge");
        } else {
            console.log("WARNING: Insufficient USDC for initialization. Need 100 USDC.");
            console.log("Get test USDC from: https://faucet.circle.com/");
        }
        
        // Configure MotherVault
        motherVault.setDepositCap(100 * 1e6); // $100 cap for testnet
        motherVault.setManagementFee(50); // 0.5% fee
        motherVault.setRebalanceCooldown(3600); // 1 hour
        motherVault.setMinAPYDifferential(500); // 5% APY differential
        motherVault.setBufferManagement(true); // Enable buffer
        console.log("MotherVault configured");
        
        // Configure CCTP Bridge
        cctpBridge.setSupportedDomain(POLYGON_DOMAIN, true);
        console.log("CCTP: Polygon Amoy domain supported");
        
        // Configure CrossChainMessenger
        messenger.setSupportedDomain(POLYGON_DOMAIN, true);
        console.log("Messenger: Polygon domain supported");
        
        vm.stopBroadcast();
        
        console.log("\n===== DEPLOYMENT COMPLETE =====");
        console.log("\n--- Core Contracts ---");
        console.log("MotherVault:", address(motherVault));
        console.log("CCTPBridge:", address(cctpBridge));
        console.log("CrossChainMessenger:", address(messenger));
        console.log("Rebalancer:", address(rebalancer));
        console.log("YieldDistributor:", address(yieldDist));
        console.log("HealthMonitor:", address(healthMon));
        
        console.log("\n--- External Infrastructure ---");
        console.log("USDC:", USDC_BASE_SEPOLIA);
        console.log("Token Messenger:", TOKEN_MESSENGER);
        console.log("Message Transmitter:", MESSAGE_TRANSMITTER);
        console.log("Hyperlane Mailbox:", HYPERLANE_MAILBOX);
        console.log("Hyperlane IGP:", HYPERLANE_IGP);
        
        console.log("\n--- Configuration ---");
        console.log("Deposit Cap: $100");
        console.log("Management Fee: 0.5%");
        console.log("Rebalance Cooldown: 1 hour");
        console.log("Min APY Differential: 5%");
        console.log("Buffer Management: Enabled");
        
        console.log("\n===== NEXT STEPS =====");
        console.log("1. Get test USDC from https://faucet.circle.com/ if needed");
        console.log("2. Deploy BridgeVault on Polygon Amoy");
        console.log("3. Deploy KatanaChildVault on Tatara");
        console.log("4. Configure cross-chain connections");
        
        // Export for use in other scripts
        console.log("\n===== EXPORT COMMANDS =====");
        console.log("export MOTHER_VAULT_BASE=", address(motherVault));
        console.log("export CCTP_BRIDGE_BASE=", address(cctpBridge));
        console.log("export MESSENGER_BASE=", address(messenger));
        console.log("export REBALANCER_BASE=", address(rebalancer));
        console.log("export YIELD_DIST_BASE=", address(yieldDist));
        console.log("export HEALTH_MON_BASE=", address(healthMon));
    }
}