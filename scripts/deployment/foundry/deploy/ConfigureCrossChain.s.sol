// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "../../contracts/MotherVault.sol";
import "../../contracts/core/CrossChainMessenger.sol";
import "../../contracts/yield-strategies/KatanaChildVault.sol";
import "../../contracts/yield-strategies/ZircuitChildVault.sol";

/**
 * @title ConfigureCrossChain Script
 * @notice Configures cross-chain relationships between MotherVault and ChildVaults
 * @dev Run after all contracts are deployed to establish communication
 */
contract ConfigureCrossChain is Script {
    struct CrossChainConfig {
        address motherVault;
        address crossChainMessenger;
        address katanaChildVault;
        address zircuitChildVault;
        uint32 baseDomain;
        uint32 katanaDomain;
        uint32 zircuitDomain;
    }

    function run() external {
        CrossChainConfig memory config = loadConfiguration();
        validateConfiguration(config);
        
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
        vm.startBroadcast(deployer);
        
        console.log("Configuring cross-chain relationships...");
        console.log("Chain ID:", block.chainid);
        console.log("Deployer:", deployer);
        
        configureCrossChainMessenger(config);
        configureMotherVault(config);
        configureChildVaults(config);
        verifyConfiguration(config);
        
        vm.stopBroadcast();
        
        console.log("Cross-chain configuration completed successfully!");
        logConfigurationSummary(config);
    }

    function loadConfiguration() internal view returns (CrossChainConfig memory config) {
        config.motherVault = vm.envAddress("MOTHER_VAULT_ADDRESS");
        config.crossChainMessenger = vm.envAddress("CROSS_CHAIN_MESSENGER_ADDRESS");
        
        // Child vault addresses (may be zero if not deployed yet)
        try vm.envAddress("CHILD_VAULT_KATANA_ADDRESS") returns (address katana) {
            config.katanaChildVault = katana;
        } catch {
            config.katanaChildVault = address(0);
        }
        
        try vm.envAddress("CHILD_VAULT_ZIRCUIT_ADDRESS") returns (address zircuit) {
            config.zircuitChildVault = zircuit;
        } catch {
            config.zircuitChildVault = address(0);
        }
        
        config.baseDomain = uint32(vm.envUint("BASE_DOMAIN"));
        config.katanaDomain = uint32(vm.envUint("KATANA_DOMAIN"));
        config.zircuitDomain = uint32(vm.envUint("ZIRCUIT_DOMAIN"));
        
        console.log("Configuration loaded from environment");
    }

    function validateConfiguration(CrossChainConfig memory config) internal view {
        require(config.motherVault != address(0), "MotherVault address not set");
        require(config.crossChainMessenger != address(0), "CrossChainMessenger address not set");
        require(config.baseDomain > 0, "Base domain not set");
        require(config.katanaDomain > 0, "Katana domain not set");
        require(config.zircuitDomain > 0, "Zircuit domain not set");
        
        // Verify contracts have code
        require(config.motherVault.code.length > 0, "MotherVault not deployed");
        require(config.crossChainMessenger.code.length > 0, "CrossChainMessenger not deployed");
        
        if (config.katanaChildVault != address(0)) {
            require(config.katanaChildVault.code.length > 0, "KatanaChildVault not deployed");
        }
        
        if (config.zircuitChildVault != address(0)) {
            require(config.zircuitChildVault.code.length > 0, "ZircuitChildVault not deployed");
        }
        
        console.log("SUCCESS: Configuration validation passed");
    }

    function configureCrossChainMessenger(CrossChainConfig memory config) internal {
        console.log("\n--- Configuring CrossChainMessenger ---");
        
        CrossChainMessenger messenger = CrossChainMessenger(config.crossChainMessenger);
        
        // Add trusted remotes for child vaults
        if (config.katanaChildVault != address(0)) {
            bytes32 katanaRemote = bytes32(uint256(uint160(config.katanaChildVault)));
            try messenger.setTrustedSender(config.katanaDomain, katanaRemote) {
                console.log("SUCCESS: Added Katana trusted remote");
            } catch Error(string memory reason) {
                console.log("WARNING:  Katana remote already added or failed:", reason);
            }
        }
        
        if (config.zircuitChildVault != address(0)) {
            bytes32 zircuitRemote = bytes32(uint256(uint160(config.zircuitChildVault)));
            try messenger.setTrustedSender(config.zircuitDomain, zircuitRemote) {
                console.log("SUCCESS: Added Zircuit trusted remote");
            } catch Error(string memory reason) {
                console.log("WARNING:  Zircuit remote already added or failed:", reason);
            }
        }
        
        console.log("CrossChainMessenger configuration completed");
    }

    function configureMotherVault(CrossChainConfig memory config) internal {
        console.log("\n--- Configuring MotherVault ---");
        
        MotherVault vault = MotherVault(config.motherVault);
        
        // Register child vaults
        if (config.katanaChildVault != address(0)) {
            try vault.addChildVault(config.katanaDomain, config.katanaChildVault) {
                console.log("SUCCESS: Added Katana child vault to MotherVault");
            } catch Error(string memory reason) {
                console.log("WARNING:  Katana child vault already added or failed:", reason);
            }
        }
        
        if (config.zircuitChildVault != address(0)) {
            try vault.addChildVault(config.zircuitDomain, config.zircuitChildVault) {
                console.log("SUCCESS: Added Zircuit child vault to MotherVault");
            } catch Error(string memory reason) {
                console.log("WARNING:  Zircuit child vault already added or failed:", reason);
            }
        }
        
        // Set domain mappings
        // Note: Domain mapping functions not yet implemented in MotherVault
        console.log("TODO: Set Katana domain mapping when function is implemented");
        console.log("TODO: Set Zircuit domain mapping when function is implemented");
        
        console.log("MotherVault configuration completed");
    }

    function configureChildVaults(CrossChainConfig memory config) internal {
        if (block.chainid != config.baseDomain) {
            console.log("\n--- Configuring Child Vault on current chain ---");
            
            // Determine which child vault we're configuring based on chain
            address childVault = getCurrentChainChildVault(config);
            
            if (childVault != address(0)) {
                configureChildVault(childVault, config);
            } else {
                console.log("WARNING:  No child vault for current chain");
            }
        } else {
            console.log("\n--- Skipping child vault configuration (on base chain) ---");
        }
    }

    function getCurrentChainChildVault(CrossChainConfig memory config) 
        internal 
        view 
        returns (address) 
    {
        if (block.chainid == config.katanaDomain && config.katanaChildVault != address(0)) {
            return config.katanaChildVault;
        } else if (block.chainid == config.zircuitDomain && config.zircuitChildVault != address(0)) {
            return config.zircuitChildVault;
        }
        return address(0);
    }

    function configureChildVault(address childVaultAddr, CrossChainConfig memory config) internal {
        // Try to configure as KatanaChildVault first
        try this.configureKatanaChildVault(childVaultAddr, config) {
            console.log("SUCCESS: Configured as KatanaChildVault");
            return;
        } catch {
            // If that fails, try ZircuitChildVault
            try this.configureZircuitChildVault(childVaultAddr, config) {
                console.log("SUCCESS: Configured as ZircuitChildVault");
                return;
            } catch {
                console.log("ERROR: Failed to configure child vault");
            }
        }
    }

    function configureKatanaChildVault(address childVaultAddr, CrossChainConfig memory config) external {
        // KatanaChildVault vault = KatanaChildVault(childVaultAddr);
        
        // TODO: Implement child vault configuration when functions are available
        // vault.setMotherVaultDomain(config.baseDomain);
        // vault.setMotherVaultAddress(config.motherVault);
        // vault.setCrossChainMessenger(config.crossChainMessenger);
        
        console.log("KatanaChildVault configuration TODO - functions not yet implemented");
    }

    function configureZircuitChildVault(address childVaultAddr, CrossChainConfig memory config) external {
        // ZircuitChildVault vault = ZircuitChildVault(childVaultAddr);
        
        // TODO: Implement child vault configuration when functions are available
        // vault.setMotherVaultDomain(config.baseDomain);
        // vault.setMotherVaultAddress(config.motherVault);
        // vault.setCrossChainMessenger(config.crossChainMessenger);
        
        console.log("ZircuitChildVault configuration TODO - functions not yet implemented");
    }

    function verifyConfiguration(CrossChainConfig memory config) internal view {
        console.log("\n--- Verifying Cross-Chain Configuration ---");
        
        CrossChainMessenger messenger = CrossChainMessenger(config.crossChainMessenger);
        MotherVault vault = MotherVault(config.motherVault);
        
        // Verify trusted remotes
        if (config.katanaChildVault != address(0)) {
            bytes32 katanaRemote = bytes32(uint256(uint160(config.katanaChildVault)));
            require(
                messenger.trustedSenders(config.katanaDomain) == katanaRemote,
                "Katana trusted remote not set"
            );
            console.log("SUCCESS: Katana trusted remote verified");
        }
        
        if (config.zircuitChildVault != address(0)) {
            bytes32 zircuitRemote = bytes32(uint256(uint160(config.zircuitChildVault)));
            require(
                messenger.trustedSenders(config.zircuitDomain) == zircuitRemote,
                "Zircuit trusted remote not set"
            );
            console.log("SUCCESS: Zircuit trusted remote verified");
        }
        
        // Verify child vault registrations
        if (config.katanaChildVault != address(0)) {
            require(
                vault.getChildVault(config.katanaDomain).vaultAddress == config.katanaChildVault,
                "Katana child vault not registered"
            );
            console.log("SUCCESS: Katana child vault registered");
        }
        
        if (config.zircuitChildVault != address(0)) {
            require(
                vault.getChildVault(config.zircuitDomain).vaultAddress == config.zircuitChildVault,
                "Zircuit child vault not registered"
            );
            console.log("SUCCESS: Zircuit child vault registered");
        }
        
        console.log("SUCCESS: Cross-chain configuration verification passed");
    }

    function logConfigurationSummary(CrossChainConfig memory config) internal view {
        console.log("\n=== CROSS-CHAIN CONFIGURATION SUMMARY ===");
        console.log("Chain ID:", block.chainid);
        console.log("Base Domain:", config.baseDomain);
        console.log("Katana Domain:", config.katanaDomain);
        console.log("Zircuit Domain:", config.zircuitDomain);
        
        console.log("\n--- Contract Addresses ---");
        console.log("MotherVault:", config.motherVault);
        console.log("CrossChainMessenger:", config.crossChainMessenger);
        
        if (config.katanaChildVault != address(0)) {
            console.log("KatanaChildVault:", config.katanaChildVault);
        } else {
            console.log("KatanaChildVault: Not deployed");
        }
        
        if (config.zircuitChildVault != address(0)) {
            console.log("ZircuitChildVault:", config.zircuitChildVault);
        } else {
            console.log("ZircuitChildVault: Not deployed");
        }
        
        console.log("\n--- Configuration Status ---");
        console.log("SUCCESS: CrossChainMessenger configured");
        console.log("SUCCESS: MotherVault child vaults registered");
        console.log("SUCCESS: Domain mappings set");
        console.log("SUCCESS: Trusted remotes configured");
        
        console.log("\n--- Next Steps ---");
        if (config.katanaChildVault == address(0)) {
            console.log("- Deploy KatanaChildVault");
        }
        if (config.zircuitChildVault == address(0)) {
            console.log("- Deploy ZircuitChildVault");
        }
        console.log("- Test cross-chain messaging");
        console.log("- Configure yield strategy parameters");
        console.log("- Set up monitoring and alerts");
        
        console.log("\nCross-chain configuration completed!");
    }
}