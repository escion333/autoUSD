// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "../../contracts/MotherVault.sol";
import "../../contracts/core/CCTPBridge.sol";
import "../../contracts/core/CrossChainMessenger.sol";
import "../../contracts/core/Rebalancer.sol";
import "../../contracts/core/YieldDistributor.sol";
import "../../contracts/core/HealthMonitor.sol";

/**
 * @title Base Sepolia Deployment Script
 * @notice Deploy autoUSD Mother Vault to Base Sepolia testnet
 * @dev Simplified deployment focusing on Base + Katana integration only
 */
contract DeployBaseSepolia is Script {
    // Base Sepolia addresses
    address constant USDC_BASE_SEPOLIA = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    address constant HYPERLANE_MAILBOX = 0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766;
    address constant CCTP_TOKEN_MESSENGER = 0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5;
    address constant CCTP_MESSAGE_TRANSMITTER = 0x7865fAfC2db2093669d92c0F33AeEF291086BEFD;
    address constant INTERCHAIN_GAS_PAYMASTER = 0x931ca6CE4d0c93F3625c317C5A6a9618e2b0E8a3;
    
    // Domain IDs
    uint32 constant BASE_DOMAIN = 10002; // Base Sepolia CCTP domain
    uint32 constant POLYGON_DOMAIN = 7; // Polygon PoS CCTP domain (Amoy testnet uses same domain)
    
    // Protocol parameters
    uint256 constant DEPOSIT_CAP = 100e6; // $100 USDC cap
    uint256 constant MANAGEMENT_FEE = 50; // 0.5%
    uint256 constant REBALANCE_THRESHOLD = 500; // 5%

    struct DeployedContracts {
        address motherVault;
        address cctpBridge;
        address crossChainMessenger;
        address rebalancer;
        address yieldDistributor;
        address healthMonitor;
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        require(deployerPrivateKey != 0, "Private key not set");
        address deployer = vm.addr(deployerPrivateKey);
        require(deployer != address(0), "Invalid deployer address");
        address treasury = deployer; // Treasury defaults to deployer for testnet
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Starting Base Sepolia Deployment...");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        require(block.chainid == 84532, "Must deploy to Base Sepolia (84532)");
        
        DeployedContracts memory contracts = deployContracts(deployer, treasury);
        configureContracts(contracts, deployer);
        verifyDeployment(contracts, deployer);
        saveDeploymentData(contracts);
        
        vm.stopBroadcast();
        
        console.log("\n[SUCCESS] Base Sepolia deployment completed successfully!");
        logDeploymentSummary(contracts);
    }

    function deployContracts(address deployer, address treasury) 
        internal 
        returns (DeployedContracts memory contracts) 
    {
        console.log("\n--- Deploying Core Contracts ---");
        
        // Deploy MotherVault
        console.log("Deploying MotherVault...");
        require(USDC_BASE_SEPOLIA != address(0), "Invalid USDC address");
        MotherVault motherVault = new MotherVault(
            USDC_BASE_SEPOLIA,
            "autoUSD Vault Testnet",
            "aUSD-T"
        );
        contracts.motherVault = address(motherVault);
        require(contracts.motherVault != address(0), "MotherVault deployment failed");
        
        // Deploy CCTPBridge
        console.log("Deploying CCTPBridge...");
        require(CCTP_TOKEN_MESSENGER != address(0), "Invalid token messenger");
        require(CCTP_MESSAGE_TRANSMITTER != address(0), "Invalid message transmitter");
        CCTPBridge cctpBridge = new CCTPBridge(
            CCTP_TOKEN_MESSENGER,
            CCTP_MESSAGE_TRANSMITTER,
            USDC_BASE_SEPOLIA,
            deployer
        );
        contracts.cctpBridge = address(cctpBridge);
        require(contracts.cctpBridge != address(0), "CCTPBridge deployment failed");
        
        // Deploy CrossChainMessenger
        console.log("Deploying CrossChainMessenger...");
        CrossChainMessenger messenger = new CrossChainMessenger(
            HYPERLANE_MAILBOX,
            INTERCHAIN_GAS_PAYMASTER,
            contracts.cctpBridge,
            contracts.motherVault,
            deployer
        );
        contracts.crossChainMessenger = address(messenger);
        
        // Deploy Rebalancer
        console.log("Deploying Rebalancer...");
        Rebalancer rebalancer = new Rebalancer(
            contracts.motherVault
        );
        contracts.rebalancer = address(rebalancer);
        
        // Deploy YieldDistributor
        console.log("Deploying YieldDistributor...");
        YieldDistributor yieldDist = new YieldDistributor(
            USDC_BASE_SEPOLIA,
            contracts.motherVault,
            treasury,
            MANAGEMENT_FEE
        );
        contracts.yieldDistributor = address(yieldDist);
        
        // Deploy HealthMonitor
        console.log("Deploying HealthMonitor...");
        HealthMonitor healthMon = new HealthMonitor(
            contracts.motherVault,
            contracts.crossChainMessenger,
            contracts.rebalancer,
            deployer
        );
        contracts.healthMonitor = address(healthMon);
        
        console.log("[SUCCESS] Core contracts deployed");
    }

    function configureContracts(
        DeployedContracts memory contracts,
        address deployer
    ) internal {
        console.log("\n--- Configuring Contracts ---");
        
        // Initialize MotherVault with messenger and bridge
        MotherVault vault = MotherVault(contracts.motherVault);
        vault.initialize(contracts.crossChainMessenger, contracts.cctpBridge);
        
        // Configure MotherVault parameters
        vault.setDepositCap(DEPOSIT_CAP);
        vault.setManagementFee(MANAGEMENT_FEE);
        vault.setRebalanceCooldown(3600); // 1 hour
        vault.setMinAPYDifferential(REBALANCE_THRESHOLD);
        vault.setBufferManagement(true);
        
        // Configure CCTP Bridge for Polygon domain (not Katana - CCTP goes to Polygon)
        CCTPBridge(contracts.cctpBridge).setSupportedDomain(POLYGON_DOMAIN, true);
        
        console.log("[SUCCESS] Contract configuration completed");
    }

    function verifyDeployment(
        DeployedContracts memory contracts,
        address deployer
    ) internal view {
        console.log("\n--- Verifying Deployment ---");
        
        // Verify MotherVault
        MotherVault vault = MotherVault(contracts.motherVault);
        require(vault.asset() == USDC_BASE_SEPOLIA, "Vault asset mismatch");
        require(vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), deployer), "Vault admin mismatch");
        require(vault.depositCap() == DEPOSIT_CAP, "Deposit cap mismatch");
        
        // Verify CCTPBridge
        CCTPBridge bridge = CCTPBridge(contracts.cctpBridge);
        require(address(bridge.tokenMessenger()) == CCTP_TOKEN_MESSENGER, "Token messenger mismatch");
        require(address(bridge.messageTransmitter()) == CCTP_MESSAGE_TRANSMITTER, "Message transmitter mismatch");
        require(address(bridge.usdc()) == USDC_BASE_SEPOLIA, "USDC address mismatch");
        
        // Verify CrossChainMessenger
        CrossChainMessenger messenger = CrossChainMessenger(contracts.crossChainMessenger);
        require(address(messenger.gasPaymaster()) == INTERCHAIN_GAS_PAYMASTER, "Gas paymaster mismatch");
        
        console.log("[SUCCESS] Deployment verification passed");
    }

    function saveDeploymentData(DeployedContracts memory contracts) internal {
        string memory deploymentData = string.concat(
            "# autoUSD Protocol Deployment - Base Sepolia\n",
            "# Deployed at block: ", vm.toString(block.number), "\n",
            "# Timestamp: ", vm.toString(block.timestamp), "\n\n",
            "MOTHER_VAULT=", vm.toString(contracts.motherVault), "\n",
            "CCTP_BRIDGE=", vm.toString(contracts.cctpBridge), "\n",
            "CROSS_CHAIN_MESSENGER=", vm.toString(contracts.crossChainMessenger), "\n",
            "REBALANCER=", vm.toString(contracts.rebalancer), "\n",
            "YIELD_DISTRIBUTOR=", vm.toString(contracts.yieldDistributor), "\n",
            "HEALTH_MONITOR=", vm.toString(contracts.healthMonitor), "\n\n",
            "# Protocol Parameters\n",
            "DEPOSIT_CAP=", vm.toString(DEPOSIT_CAP), "\n",
            "MANAGEMENT_FEE=", vm.toString(MANAGEMENT_FEE), "\n",
            "REBALANCE_THRESHOLD=", vm.toString(REBALANCE_THRESHOLD), "\n\n",
            "# Infrastructure\n",
            "USDC_ADDRESS=", vm.toString(USDC_BASE_SEPOLIA), "\n",
            "HYPERLANE_MAILBOX=", vm.toString(HYPERLANE_MAILBOX), "\n",
            "CCTP_TOKEN_MESSENGER=", vm.toString(CCTP_TOKEN_MESSENGER), "\n",
            "CCTP_MESSAGE_TRANSMITTER=", vm.toString(CCTP_MESSAGE_TRANSMITTER), "\n",
            "INTERCHAIN_GAS_PAYMASTER=", vm.toString(INTERCHAIN_GAS_PAYMASTER), "\n"
        );
        
        vm.writeFile("deployments/base_sepolia.env", deploymentData);
        console.log("[SUCCESS] Deployment data saved to: deployments/base_sepolia.env");
    }

    function logDeploymentSummary(DeployedContracts memory contracts) internal view {
        console.log("\n=== BASE SEPOLIA DEPLOYMENT SUMMARY ===");
        console.log("Network: Base Sepolia (Chain ID: 84532)");
        console.log("Block Number:", block.number);
        console.log("\n--- Contract Addresses ---");
        console.log("MotherVault:", contracts.motherVault);
        console.log("CCTPBridge:", contracts.cctpBridge);
        console.log("CrossChainMessenger:", contracts.crossChainMessenger);
        console.log("Rebalancer:", contracts.rebalancer);
        console.log("YieldDistributor:", contracts.yieldDistributor);
        console.log("HealthMonitor:", contracts.healthMonitor);
        console.log("\n--- Protocol Config ---");
        console.log("Deposit Cap: $100 USDC");
        console.log("Management Fee: 0.5% (50 bps)");
        console.log("Rebalance Threshold: 5%");
        console.log("\n--- Next Steps ---");
        console.log("1. Deploy BridgeVault on Polygon Amoy testnet");
        console.log("2. Deploy KatanaChildVault on Katana Network testnet");
        console.log("3. Test Circle wallet integration");
        console.log("4. Obtain Base Sepolia test USDC for testing");
        console.log("5. Update frontend with testnet contract addresses");
    }
}