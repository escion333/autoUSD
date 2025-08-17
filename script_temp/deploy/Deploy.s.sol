// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "../../contracts/MotherVault.sol";
import "../../contracts/core/CCTPBridge.sol";
import "../../contracts/core/CrossChainMessenger.sol";
import "../../contracts/core/Rebalancer.sol";
import "../../contracts/core/YieldDistributor.sol";
import "../../contracts/core/HealthMonitor.sol";
import "../../contracts/yield-strategies/KatanaChildVault.sol";
import "../../contracts/yield-strategies/ZircuitChildVault.sol";

/**
 * @title Deploy Script
 * @notice Comprehensive deployment script for autoUSD protocol
 * @dev Supports both testnet and mainnet deployments with proper validation
 */
contract Deploy is Script {
    // Environment variable validation
    struct DeploymentConfig {
        address deployer;
        address treasury;
        address usdc;
        address hyperlaneMailbox;
        address cctpTokenMessenger;
        address cctpMessageTransmitter;
        address interchainGasPaymaster;
        uint32 baseDomain;
        uint32 katanaDomain;
        uint32 zircuitDomain;
        uint256 depositCap;
        uint256 managementFee;
        uint256 performanceFee;
        uint256 rebalanceThreshold;
    }

    // Deployment state
    struct DeployedContracts {
        address motherVault;
        address cctpBridge;
        address crossChainMessenger;
        address rebalancer;
        address yieldDistributor;
        address healthMonitor;
        address katanaChildVault;
        address zircuitChildVault;
    }

    function run() external {
        DeploymentConfig memory config = loadConfiguration();
        validateConfiguration(config);
        
        vm.startBroadcast(config.deployer);
        
        console.log("Starting autoUSD Protocol Deployment...");
        console.log("Deployer:", config.deployer);
        console.log("Treasury:", config.treasury);
        console.log("Chain ID:", block.chainid);
        
        DeployedContracts memory contracts = deployContracts(config);
        configureContracts(config, contracts);
        verifyDeployment(config, contracts);
        saveDeploymentData(contracts);
        
        vm.stopBroadcast();
        
        console.log("\\n Deployment completed successfully!");
        logDeploymentSummary(contracts);
    }

    function loadConfiguration() internal view returns (DeploymentConfig memory config) {
        // Load and validate all required environment variables
        require(vm.envBytes32("PRIVATE_KEY").length > 0, "PRIVATE_KEY not set");
        
        config.deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
        
        // Treasury address (defaults to deployer if not set)
        try vm.envAddress("TREASURY_ADDRESS") returns (address treasury) {
            config.treasury = treasury;
        } catch {
            config.treasury = config.deployer;
            console.log("Warning: TREASURY_ADDRESS not set, using deployer");
        }

        // Token and infrastructure addresses
        config.usdc = vm.envAddress("USDC_ADDRESS");
        config.hyperlaneMailbox = vm.envAddress("HYPERLANE_MAILBOX");
        config.cctpTokenMessenger = vm.envAddress("CCTP_TOKEN_MESSENGER");
        config.cctpMessageTransmitter = vm.envAddress("CCTP_MESSAGE_TRANSMITTER");
        config.interchainGasPaymaster = vm.envAddress("INTERCHAIN_GAS_PAYMASTER");

        // Domain IDs
        config.baseDomain = uint32(vm.envUint("BASE_DOMAIN"));
        config.katanaDomain = uint32(vm.envUint("KATANA_DOMAIN"));
        config.zircuitDomain = uint32(vm.envUint("ZIRCUIT_DOMAIN"));

        // Protocol parameters
        config.depositCap = vm.envUint("DEPOSIT_CAP");
        config.managementFee = vm.envUint("MANAGEMENT_FEE");
        config.performanceFee = vm.envUint("PERFORMANCE_FEE");
        config.rebalanceThreshold = vm.envUint("REBALANCE_THRESHOLD");
    }

    function validateConfiguration(DeploymentConfig memory config) internal view {
        require(config.deployer != address(0), "Invalid deployer address");
        require(config.treasury != address(0), "Invalid treasury address");
        require(config.usdc != address(0), "Invalid USDC address");
        require(config.hyperlaneMailbox != address(0), "Invalid Hyperlane mailbox");
        require(config.cctpTokenMessenger != address(0), "Invalid CCTP token messenger");
        require(config.cctpMessageTransmitter != address(0), "Invalid CCTP message transmitter");
        require(config.interchainGasPaymaster != address(0), "Invalid gas paymaster");
        
        require(config.baseDomain > 0, "Invalid base domain");
        require(config.katanaDomain > 0, "Invalid katana domain");
        require(config.zircuitDomain > 0, "Invalid zircuit domain");
        require(config.baseDomain != config.katanaDomain, "Base and Katana domains must be different");
        require(config.baseDomain != config.zircuitDomain, "Base and Zircuit domains must be different");
        require(config.katanaDomain != config.zircuitDomain, "Katana and Zircuit domains must be different");
        
        require(config.depositCap > 0, "Deposit cap must be greater than 0");
        require(config.managementFee <= 1000, "Management fee too high (max 10%)");
        require(config.performanceFee <= 2000, "Performance fee too high (max 20%)");
        require(config.rebalanceThreshold > 0 && config.rebalanceThreshold <= 2000, "Invalid rebalance threshold");
        
        console.log("Configuration validation passed");
    }

    function deployContracts(DeploymentConfig memory config) 
        internal 
        returns (DeployedContracts memory contracts) 
    {
        console.log("\n--- Deploying Core Contracts ---");
        
        // Deploy MotherVault
        console.log("Deploying MotherVault...");
        MotherVault motherVault = new MotherVault(
            config.usdc,
            "autoUSD Vault",
            "aUSD"
        );
        contracts.motherVault = address(motherVault);
        
        // Deploy CCTPBridge
        console.log("Deploying CCTPBridge...");
        CCTPBridge cctpBridge = new CCTPBridge(
            config.cctpTokenMessenger,
            config.cctpMessageTransmitter,
            config.usdc,
            config.deployer
        );
        contracts.cctpBridge = address(cctpBridge);
        
        // Deploy CrossChainMessenger
        console.log("Deploying CrossChainMessenger...");
        CrossChainMessenger messenger = new CrossChainMessenger(
            config.hyperlaneMailbox,
            config.interchainGasPaymaster,
            contracts.cctpBridge,
            contracts.motherVault,
            config.deployer
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
            config.usdc,
            contracts.motherVault,
            config.treasury,
            config.managementFee
        );
        contracts.yieldDistributor = address(yieldDist);
        
        // Deploy HealthMonitor
        console.log("Deploying HealthMonitor...");
        HealthMonitor healthMon = new HealthMonitor(
            contracts.motherVault,
            contracts.crossChainMessenger,
            contracts.rebalancer,
            config.deployer
        );
        contracts.healthMonitor = address(healthMon);
        
        console.log("Core contracts deployed");
    }

    function configureContracts(
        DeploymentConfig memory config, 
        DeployedContracts memory contracts
    ) internal {
        console.log("\n--- Configuring Contracts ---");
        
        // Initialize MotherVault
        MotherVault(contracts.motherVault).initialize(
            config.usdc,
            config.deployer
        );
        
        // Configure MotherVault parameters
        MotherVault(contracts.motherVault).setDepositCap(config.depositCap);
        MotherVault(contracts.motherVault).setManagementFee(config.managementFee);
        MotherVault(contracts.motherVault).setRebalanceCooldown(3600); // 1 hour
        MotherVault(contracts.motherVault).setMinAPYDifferential(config.rebalanceThreshold);
        MotherVault(contracts.motherVault).setBufferManagement(true);
        
        // Configure CCTP Bridge domains
        CCTPBridge(contracts.cctpBridge).setSupportedDomain(config.katanaDomain, true);
        CCTPBridge(contracts.cctpBridge).setSupportedDomain(config.zircuitDomain, true);
        
        // Set up contract relationships
        MotherVault(contracts.motherVault).initialize(contracts.crossChainMessenger, contracts.cctpBridge);
        
        console.log("Contract configuration completed");
    }

    function verifyDeployment(
        DeploymentConfig memory config,
        DeployedContracts memory contracts
    ) internal view {
        console.log("\n--- Verifying Deployment ---");
        
        // Verify MotherVault
        MotherVault vault = MotherVault(contracts.motherVault);
        require(vault.asset() == config.usdc, "Vault asset mismatch");
        require(vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), config.deployer), "Vault admin mismatch");
        require(vault.depositCap() == config.depositCap, "Deposit cap mismatch");
        
        // Verify CCTPBridge
        CCTPBridge bridge = CCTPBridge(contracts.cctpBridge);
        require(address(bridge.tokenMessenger()) == config.cctpTokenMessenger, "Token messenger mismatch");
        require(address(bridge.messageTransmitter()) == config.cctpMessageTransmitter, "Message transmitter mismatch");
        require(address(bridge.usdc()) == config.usdc, "USDC address mismatch");
        
        // Verify CrossChainMessenger
        CrossChainMessenger messenger = CrossChainMessenger(contracts.crossChainMessenger);
        // Skip mailbox check as it's internal to CrossChainMessenger
        require(messenger.gasPaymaster() == config.interchainGasPaymaster, "Gas paymaster mismatch");
        
        console.log("Deployment verification passed");
    }

    function saveDeploymentData(DeployedContracts memory contracts) internal {
        string memory network = getNetworkName();
        string memory deploymentData = string.concat(
            "# autoUSD Protocol Deployment - ", network, "\n",
            "# Deployed at block: ", vm.toString(block.number), "\n",
            "# Timestamp: ", vm.toString(block.timestamp), "\n\n",
            "MOTHER_VAULT=", vm.toString(contracts.motherVault), "\n",
            "CCTP_BRIDGE=", vm.toString(contracts.cctpBridge), "\n",
            "CROSS_CHAIN_MESSENGER=", vm.toString(contracts.crossChainMessenger), "\n",
            "REBALANCER=", vm.toString(contracts.rebalancer), "\n",
            "YIELD_DISTRIBUTOR=", vm.toString(contracts.yieldDistributor), "\n",
            "HEALTH_MONITOR=", vm.toString(contracts.healthMonitor), "\n"
        );
        
        string memory filename = string.concat("deployments/", network, ".env");
        vm.writeFile(filename, deploymentData);
        console.log("Deployment data saved to:", filename);
    }

    function getNetworkName() internal view returns (string memory) {
        uint256 chainId = block.chainid;
        if (chainId == 1) return "mainnet";
        if (chainId == 8453) return "base";
        if (chainId == 84532) return "base_sepolia";
        if (chainId == 11155111) return "sepolia";
        return string.concat("chain_", vm.toString(chainId));
    }

    function logDeploymentSummary(DeployedContracts memory contracts) internal view {
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Network:", getNetworkName());
        console.log("Block Number:", block.number);
        console.log("\n--- Contract Addresses ---");
        console.log("MotherVault:", contracts.motherVault);
        console.log("CCTPBridge:", contracts.cctpBridge);
        console.log("CrossChainMessenger:", contracts.crossChainMessenger);
        console.log("Rebalancer:", contracts.rebalancer);
        console.log("YieldDistributor:", contracts.yieldDistributor);
        console.log("HealthMonitor:", contracts.healthMonitor);
        console.log("\n--- Next Steps ---");
        console.log("1. Deploy child vaults on Katana and Zircuit");
        console.log("2. Configure cross-chain relationships");
        console.log("3. Verify contracts on block explorers");
        console.log("4. Update frontend configuration");
    }
}