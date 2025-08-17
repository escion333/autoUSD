// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";

/**
 * @title ValidateEnvironment Script
 * @notice Validates deployment environment and configuration before deployment
 * @dev Should be run before any deployment to ensure all requirements are met
 */
contract ValidateEnvironment is Script {
    struct EnvironmentConfig {
        // Network configuration
        uint256 chainId;
        string networkName;
        
        // Required addresses
        address deployer;
        address treasury;
        address usdc;
        address hyperlaneMailbox;
        address cctpTokenMessenger;
        address cctpMessageTransmitter;
        address interchainGasPaymaster;
        
        // Domain configuration
        uint32 baseDomain;
        uint32 katanaDomain;
        uint32 zircuitDomain;
        
        // Protocol parameters
        uint256 depositCap;
        uint256 managementFee;
        uint256 performanceFee;
        uint256 rebalanceThreshold;
        
        // API keys and verification
        string basescanApiKey;
        string etherscanApiKey;
    }

    function run() external view {
        console.log("Validating deployment environment...");
        console.log("Chain ID:", block.chainid);
        
        EnvironmentConfig memory config = loadEnvironmentConfig();
        
        validateNetworkConfiguration(config);
        validateAddresses(config);
        validateDomains(config);
        validateProtocolParameters(config);
        validateApiKeys(config);
        validateBalances(config);
        
        console.log("\\nEnvironment validation completed successfully!");
        console.log("Ready for deployment on", config.networkName);
        
        logConfiguration(config);
    }

    function loadEnvironmentConfig() internal view returns (EnvironmentConfig memory config) {
        config.chainId = block.chainid;
        config.networkName = getNetworkName(config.chainId);
        
        // Load deployer
        bytes32 privateKeyBytes = vm.envBytes32("PRIVATE_KEY");
        require(privateKeyBytes != bytes32(0), "PRIVATE_KEY not set or invalid");
        config.deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
        
        // Load treasury (optional, defaults to deployer)
        try vm.envAddress("TREASURY_ADDRESS") returns (address treasury) {
            config.treasury = treasury;
        } catch {
            config.treasury = config.deployer;
        }
        
        // Load required addresses
        config.usdc = loadAddress("USDC_ADDRESS");
        config.hyperlaneMailbox = loadAddress("HYPERLANE_MAILBOX");
        config.cctpTokenMessenger = loadAddress("CCTP_TOKEN_MESSENGER");
        config.cctpMessageTransmitter = loadAddress("CCTP_MESSAGE_TRANSMITTER");
        config.interchainGasPaymaster = loadAddress("INTERCHAIN_GAS_PAYMASTER");
        
        // Load domains
        config.baseDomain = uint32(vm.envUint("BASE_DOMAIN"));
        config.katanaDomain = uint32(vm.envUint("KATANA_DOMAIN"));
        config.zircuitDomain = uint32(vm.envUint("ZIRCUIT_DOMAIN"));
        
        // Load protocol parameters
        config.depositCap = vm.envUint("DEPOSIT_CAP");
        config.managementFee = vm.envUint("MANAGEMENT_FEE");
        config.performanceFee = vm.envUint("PERFORMANCE_FEE");
        config.rebalanceThreshold = vm.envUint("REBALANCE_THRESHOLD");
        
        // Load API keys
        config.basescanApiKey = vm.envString("BASESCAN_API_KEY");
        config.etherscanApiKey = vm.envString("ETHERSCAN_API_KEY");
    }

    function loadAddress(string memory envVar) internal view returns (address) {
        try vm.envAddress(envVar) returns (address addr) {
            require(addr != address(0), string.concat(envVar, " is zero address"));
            return addr;
        } catch {
            revert(string.concat(envVar, " not set or invalid"));
        }
    }

    function validateNetworkConfiguration(EnvironmentConfig memory config) internal view {
        console.log("\n--- Network Configuration ---");
        console.log("Network:", config.networkName);
        console.log("Chain ID:", config.chainId);
        
        // Validate supported networks
        require(
            config.chainId == 1 ||      // Ethereum mainnet
            config.chainId == 8453 ||   // Base mainnet  
            config.chainId == 84532 ||  // Base Sepolia
            config.chainId == 11155111, // Sepolia
            "Unsupported network"
        );
        
        // Check if mainnet
        bool isMainnet = config.chainId == 1 || config.chainId == 8453;
        if (isMainnet) {
            console.log("WARNING: MAINNET DEPLOYMENT DETECTED");
            console.log("WARNING: Ensure all parameters are production-ready");
        } else {
            console.log("Testnet deployment");
        }
        
        console.log("Network configuration valid");
    }

    function validateAddresses(EnvironmentConfig memory config) internal view {
        console.log("\n--- Address Validation ---");
        
        // Validate deployer has code if it's a contract
        if (config.deployer.code.length > 0) {
            console.log("WARNING: Deployer is a contract address");
        }
        
        // Validate infrastructure addresses have code
        validateContract(config.usdc, "USDC");
        validateContract(config.hyperlaneMailbox, "Hyperlane Mailbox");
        validateContract(config.cctpTokenMessenger, "CCTP Token Messenger");
        validateContract(config.cctpMessageTransmitter, "CCTP Message Transmitter");
        validateContract(config.interchainGasPaymaster, "Interchain Gas Paymaster");
        
        console.log("Deployer:", config.deployer);
        console.log("Treasury:", config.treasury);
        console.log("All addresses validated");
    }

    function validateContract(address addr, string memory name) internal view {
        require(addr.code.length > 0, string.concat(name, " has no code"));
        console.log(string.concat("VALID ", name, ":"), addr);
    }

    function validateDomains(EnvironmentConfig memory config) internal pure {
        console.log("\n--- Domain Configuration ---");
        
        require(config.baseDomain > 0, "Base domain must be greater than 0");
        require(config.katanaDomain > 0, "Katana domain must be greater than 0");
        require(config.zircuitDomain > 0, "Zircuit domain must be greater than 0");
        
        require(config.baseDomain != config.katanaDomain, "Base and Katana domains must be different");
        require(config.baseDomain != config.zircuitDomain, "Base and Zircuit domains must be different");
        require(config.katanaDomain != config.zircuitDomain, "Katana and Zircuit domains must be different");
        
        console.log("Base Domain:", config.baseDomain);
        console.log("Katana Domain:", config.katanaDomain);
        console.log("Zircuit Domain:", config.zircuitDomain);
        console.log("Domain configuration valid");
    }

    function validateProtocolParameters(EnvironmentConfig memory config) internal view {
        console.log("\n--- Protocol Parameters ---");
        
        require(config.depositCap > 0, "Deposit cap must be greater than 0");
        require(config.managementFee <= 1000, "Management fee too high (max 10%)");
        require(config.performanceFee <= 2000, "Performance fee too high (max 20%)");
        require(config.rebalanceThreshold > 0 && config.rebalanceThreshold <= 2000, "Invalid rebalance threshold");
        
        // Mainnet parameter validation
        bool isMainnet = config.chainId == 1 || config.chainId == 8453;
        if (isMainnet) {
            require(config.depositCap >= 100 * 1e6, "Mainnet deposit cap too low (min $100)");
            require(config.managementFee <= 100, "Mainnet management fee too high (max 1%)");
        }
        
        console.log("Deposit Cap: $", config.depositCap / 1e6);
        console.log("Management Fee:", config.managementFee, "bps");
        console.log("Performance Fee:", config.performanceFee, "bps");
        console.log("Rebalance Threshold:", config.rebalanceThreshold, "bps");
        console.log("Protocol parameters valid");
    }

    function validateApiKeys(EnvironmentConfig memory config) internal view {
        console.log("\n--- API Key Validation ---");
        
        bool hasBasescan = bytes(config.basescanApiKey).length > 0;
        bool hasEtherscan = bytes(config.etherscanApiKey).length > 0;
        
        if (config.chainId == 8453 || config.chainId == 84532) {
            // Base networks need Basescan API key
            require(hasBasescan, "Basescan API key required for Base networks");
            console.log("Basescan API key provided");
        } else {
            // Ethereum networks need Etherscan API key
            require(hasEtherscan, "Etherscan API key required for Ethereum networks");
            console.log("Etherscan API key provided");
        }
        
        if (!hasBasescan) console.log("WARNING: Basescan API key not provided");
        if (!hasEtherscan) console.log("WARNING: Etherscan API key not provided");
    }

    function validateBalances(EnvironmentConfig memory config) internal view {
        console.log("\n--- Balance Validation ---");
        
        uint256 deployerBalance = config.deployer.balance;
        console.log("Deployer ETH Balance:", deployerBalance / 1e18, "ETH");
        
        // Estimate deployment gas costs
        uint256 estimatedGasCost = estimateDeploymentCost();
        console.log("Estimated Deployment Cost:", estimatedGasCost / 1e18, "ETH");
        
        require(deployerBalance >= estimatedGasCost, "Insufficient ETH for deployment");
        
        if (deployerBalance < estimatedGasCost * 2) {
            console.log("WARNING: Low ETH balance, consider adding more for safety");
        }
        
        console.log("Sufficient balance for deployment");
    }

    function estimateDeploymentCost() internal view returns (uint256) {
        // Rough estimate: 0.01 ETH for main deployment + 0.005 ETH buffer
        uint256 baseGasCost = 15_000_000; // ~15M gas for full deployment
        uint256 gasPrice = tx.gasprice > 0 ? tx.gasprice : 20 gwei;
        return baseGasCost * gasPrice;
    }

    function logConfiguration(EnvironmentConfig memory config) internal view {
        console.log("\n=== DEPLOYMENT CONFIGURATION ===");
        console.log("Network:", config.networkName, "Chain ID:", config.chainId);
        console.log("Deployer:", config.deployer);
        console.log("Treasury:", config.treasury);
        console.log("\n--- Infrastructure ---");
        console.log("USDC:", config.usdc);
        console.log("Hyperlane Mailbox:", config.hyperlaneMailbox);
        console.log("CCTP Token Messenger:", config.cctpTokenMessenger);
        console.log("\n--- Parameters ---");
        console.log("Deposit Cap: $", config.depositCap / 1e6);
        console.log("Management Fee:", config.managementFee, "bps");
        console.log("Rebalance Threshold:", config.rebalanceThreshold, "bps");
    }

    function getNetworkName(uint256 chainId) internal pure returns (string memory) {
        if (chainId == 1) return "ethereum_mainnet";
        if (chainId == 8453) return "base_mainnet";
        if (chainId == 84532) return "base_sepolia";
        if (chainId == 11155111) return "sepolia";
        return string.concat("chain_", vm.toString(chainId));
    }
}