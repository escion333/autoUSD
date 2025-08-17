// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "../../contracts/yield-strategies/KatanaChildVault.sol";
import "../../contracts/yield-strategies/ZircuitChildVault.sol";

/**
 * @title DeployChildVaults Script
 * @notice Deploys child vaults on Katana and Zircuit networks
 * @dev Must be run after main deployment and configuration
 */
contract DeployChildVaults is Script {
    struct ChildVaultConfig {
        address deployer;
        address usdc;
        address motherVaultAddress;
        address crossChainMessengerAddress;
        uint32 baseDomain;
        // Network-specific addresses
        address router;
        address pair;
        address stakingContract;
        address rewardToken;
    }

    function run() external {
        ChildVaultConfig memory config = loadConfiguration();
        validateConfiguration(config);
        
        vm.startBroadcast(config.deployer);
        
        console.log("Starting Child Vault Deployment...");
        console.log("Chain ID:", block.chainid);
        console.log("Deployer:", config.deployer);
        
        address childVault = deployChildVault(config);
        configureChildVault(config, childVault);
        verifyChildVault(config, childVault);
        saveDeploymentData(childVault);
        
        vm.stopBroadcast();
        
        console.log("Child vault deployment completed!");
        console.log("Child Vault Address:", childVault);
    }

    function loadConfiguration() internal view returns (ChildVaultConfig memory config) {
        require(vm.envBytes32("PRIVATE_KEY").length > 0, "PRIVATE_KEY not set");
        
        config.deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
        config.usdc = vm.envAddress("USDC_ADDRESS");
        config.motherVaultAddress = vm.envAddress("MOTHER_VAULT_ADDRESS");
        config.crossChainMessengerAddress = vm.envAddress("CROSS_CHAIN_MESSENGER_ADDRESS");
        config.baseDomain = uint32(vm.envUint("BASE_DOMAIN"));
        
        // Network-specific configuration
        config.router = vm.envAddress("DEX_ROUTER");
        config.pair = vm.envAddress("USDC_PAIR");
        config.stakingContract = vm.envAddress("STAKING_CONTRACT");
        config.rewardToken = vm.envAddress("REWARD_TOKEN");
    }

    function validateConfiguration(ChildVaultConfig memory config) internal view {
        require(config.deployer != address(0), "Invalid deployer");
        require(config.usdc != address(0), "Invalid USDC address");
        require(config.motherVaultAddress != address(0), "Invalid MotherVault address");
        require(config.crossChainMessengerAddress != address(0), "Invalid messenger address");
        require(config.baseDomain > 0, "Invalid base domain");
        require(config.router != address(0), "Invalid router address");
        require(config.pair != address(0), "Invalid pair address");
        require(config.stakingContract != address(0), "Invalid staking contract");
        require(config.rewardToken != address(0), "Invalid reward token");
        
        console.log("Configuration validation passed");
    }

    function deployChildVault(ChildVaultConfig memory config) internal returns (address) {
        uint256 chainId = block.chainid;
        
        if (isKatanaNetwork(chainId)) {
            console.log("Deploying KatanaChildVault...");
            KatanaChildVault vault = new KatanaChildVault(
                config.usdc,
                config.router,
                config.pair,
                config.stakingContract,
                config.rewardToken,
                config.motherVaultAddress,
                config.crossChainMessengerAddress,
                config.baseDomain
            );
            return address(vault);
        } else if (isZircuitNetwork(chainId)) {
            console.log("Deploying ZircuitChildVault...");
            ZircuitChildVault vault = new ZircuitChildVault(
                config.usdc,
                config.router,
                config.pair,
                config.stakingContract,
                config.rewardToken,
                config.motherVaultAddress,
                config.crossChainMessengerAddress,
                config.baseDomain
            );
            return address(vault);
        } else {
            revert("Unsupported network for child vault deployment");
        }
    }

    function configureChildVault(ChildVaultConfig memory config, address childVault) internal {
        console.log("Configuring child vault...");
        
        if (isKatanaNetwork(block.chainid)) {
            KatanaChildVault vault = KatanaChildVault(childVault);
            vault.initialize();
            vault.setSlippageTolerance(100); // 1% slippage
            vault.setMinimumDeposit(1 * 1e6); // $1 minimum
        } else if (isZircuitNetwork(block.chainid)) {
            ZircuitChildVault vault = ZircuitChildVault(childVault);
            vault.initialize();
            vault.setSlippageTolerance(100); // 1% slippage
            vault.setMinimumDeposit(1 * 1e6); // $1 minimum
        }
        
        console.log("Child vault configured");
    }

    function verifyChildVault(ChildVaultConfig memory config, address childVault) internal view {
        console.log("Verifying child vault deployment...");
        
        // Basic verification that works for both vault types
        require(childVault.code.length > 0, "Child vault not deployed");
        
        // Type-specific verification
        if (isKatanaNetwork(block.chainid)) {
            KatanaChildVault vault = KatanaChildVault(childVault);
            require(vault.usdc() == config.usdc, "USDC address mismatch");
            require(vault.router() == config.router, "Router address mismatch");
            require(vault.pair() == config.pair, "Pair address mismatch");
            require(vault.motherVault() == config.motherVaultAddress, "MotherVault address mismatch");
        } else if (isZircuitNetwork(block.chainid)) {
            ZircuitChildVault vault = ZircuitChildVault(childVault);
            require(vault.usdc() == config.usdc, "USDC address mismatch");
            require(vault.router() == config.router, "Router address mismatch");
            require(vault.pair() == config.pair, "Pair address mismatch");
            require(vault.motherVault() == config.motherVaultAddress, "MotherVault address mismatch");
        }
        
        console.log("Child vault verification passed");
    }

    function saveDeploymentData(address childVault) internal {
        string memory network = getNetworkName();
        string memory vaultType = isKatanaNetwork(block.chainid) ? "KATANA" : "ZIRCUIT";
        
        string memory deploymentData = string.concat(
            "# ", vaultType, " Child Vault Deployment - ", network, "\n",
            "# Deployed at block: ", vm.toString(block.number), "\n",
            "# Timestamp: ", vm.toString(block.timestamp), "\n\n",
            "CHILD_VAULT_", vaultType, "=", vm.toString(childVault), "\n"
        );
        
        string memory filename = string.concat("deployments/", network, "_child_vault.env");
        vm.writeFile(filename, deploymentData);
        console.log("Child vault deployment data saved to:", filename);
    }

    function isKatanaNetwork(uint256 chainId) internal pure returns (bool) {
        // Add known Katana chain IDs
        return chainId == 1001; // Example Katana testnet
    }

    function isZircuitNetwork(uint256 chainId) internal pure returns (bool) {
        // Add known Zircuit chain IDs
        return chainId == 48900; // Example Zircuit testnet
    }

    function getNetworkName() internal view returns (string memory) {
        uint256 chainId = block.chainid;
        if (chainId == 1001) return "katana_testnet";
        if (chainId == 48900) return "zircuit_testnet";
        return string.concat("chain_", vm.toString(chainId));
    }
}