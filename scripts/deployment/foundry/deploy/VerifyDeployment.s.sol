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
 * @title VerifyDeployment Script
 * @notice Verifies deployed contracts and their configuration
 * @dev Run after deployment to ensure everything is properly configured
 */
contract VerifyDeployment is Script {
    struct DeployedContracts {
        address motherVault;
        address cctpBridge;
        address crossChainMessenger;
        address rebalancer;
        address yieldDistributor;
        address healthMonitor;
    }

    function run() external view {
        console.log("Verifying autoUSD Protocol Deployment...");
        console.log("Network:", getNetworkName());
        console.log("Chain ID:", block.chainid);
        
        DeployedContracts memory contracts = loadDeployedContracts();
        
        verifyContractDeployment(contracts);
        verifyContractConfiguration(contracts);
        verifyPermissions(contracts);
        verifyIntegration(contracts);
        
        console.log("\nDeployment verification completed successfully!");
        logDeploymentStatus(contracts);
    }

    function loadDeployedContracts() internal view returns (DeployedContracts memory contracts) {
        contracts.motherVault = vm.envAddress("MOTHER_VAULT_ADDRESS");
        contracts.cctpBridge = vm.envAddress("CCTP_BRIDGE_ADDRESS");
        contracts.crossChainMessenger = vm.envAddress("CROSS_CHAIN_MESSENGER_ADDRESS");
        contracts.rebalancer = vm.envAddress("REBALANCER_ADDRESS");
        contracts.yieldDistributor = vm.envAddress("YIELD_DISTRIBUTOR_ADDRESS");
        contracts.healthMonitor = vm.envAddress("HEALTH_MONITOR_ADDRESS");
        
        console.log("Loaded deployment addresses from environment");
    }

    function verifyContractDeployment(DeployedContracts memory contracts) internal view {
        console.log("\n--- Contract Deployment Verification ---");
        
        verifyContract(contracts.motherVault, "MotherVault");
        verifyContract(contracts.cctpBridge, "CCTPBridge");
        verifyContract(contracts.crossChainMessenger, "CrossChainMessenger");
        verifyContract(contracts.rebalancer, "Rebalancer");
        verifyContract(contracts.yieldDistributor, "YieldDistributor");
        verifyContract(contracts.healthMonitor, "HealthMonitor");
        
        console.log("SUCCESS: All contracts deployed and have code");
    }

    function verifyContract(address contractAddr, string memory name) internal view {
        require(contractAddr != address(0), string.concat(name, " address is zero"));
        require(contractAddr.code.length > 0, string.concat(name, " has no code"));
        console.log(string.concat("SUCCESS: ", name, ":"), contractAddr);
    }

    function verifyContractConfiguration(DeployedContracts memory contracts) internal view {
        console.log("\n--- Contract Configuration Verification ---");
        
        // Verify MotherVault configuration
        verifyMotherVaultConfig(contracts.motherVault);
        
        // Verify CCTPBridge configuration
        verifyCCTPBridgeConfig(contracts.cctpBridge);
        
        // Verify CrossChainMessenger configuration
        verifyCrossChainMessengerConfig(contracts.crossChainMessenger);
        
        // Verify YieldDistributor configuration
        verifyYieldDistributorConfig(contracts.yieldDistributor);
        
        console.log("SUCCESS: All contract configurations verified");
    }

    function verifyMotherVaultConfig(address vaultAddr) internal view {
        MotherVault vault = MotherVault(vaultAddr);
        
        // Verify asset
        address expectedUSDC = vm.envAddress("USDC_ADDRESS");
        require(vault.asset() == expectedUSDC, "MotherVault asset mismatch");
        
        // Verify vault parameters
        uint256 expectedDepositCap = vm.envUint("DEPOSIT_CAP");
        require(vault.depositCap() == expectedDepositCap, "Deposit cap mismatch");
        
        uint256 expectedManagementFee = vm.envUint("MANAGEMENT_FEE");
        require(vault.managementFee() == expectedManagementFee, "Management fee mismatch");
        
        // Verify vault is initialized
        require(vault.owner() != address(0), "MotherVault not initialized");
        
        console.log("SUCCESS: MotherVault configuration verified");
        console.log("  Asset:", vault.asset());
        console.log("  Deposit Cap:", vault.depositCap() / 1e6, "USDC");
        console.log("  Management Fee:", vault.managementFee(), "bps");
        console.log("  Owner:", vault.owner());
    }

    function verifyCCTPBridgeConfig(address bridgeAddr) internal view {
        CCTPBridge bridge = CCTPBridge(bridgeAddr);
        
        // Verify CCTP addresses
        address expectedTokenMessenger = vm.envAddress("CCTP_TOKEN_MESSENGER");
        address expectedMessageTransmitter = vm.envAddress("CCTP_MESSAGE_TRANSMITTER");
        address expectedUSDC = vm.envAddress("USDC_ADDRESS");
        
        require(bridge.tokenMessenger() == expectedTokenMessenger, "Token messenger mismatch");
        require(bridge.messageTransmitter() == expectedMessageTransmitter, "Message transmitter mismatch");
        require(bridge.usdc() == expectedUSDC, "USDC address mismatch");
        
        // Verify supported domains
        uint32 katanaDomain = uint32(vm.envUint("KATANA_DOMAIN"));
        uint32 zircuitDomain = uint32(vm.envUint("ZIRCUIT_DOMAIN"));
        
        require(bridge.supportedDomains(katanaDomain), "Katana domain not supported");
        require(bridge.supportedDomains(zircuitDomain), "Zircuit domain not supported");
        
        console.log("SUCCESS: CCTPBridge configuration verified");
        console.log("  Token Messenger:", bridge.tokenMessenger());
        console.log("  Message Transmitter:", bridge.messageTransmitter());
        console.log("  USDC:", bridge.usdc());
    }

    function verifyCrossChainMessengerConfig(address messengerAddr) internal view {
        CrossChainMessenger messenger = CrossChainMessenger(messengerAddr);
        
        // Verify Hyperlane addresses
        address expectedMailbox = vm.envAddress("HYPERLANE_MAILBOX");
        address expectedGasPaymaster = vm.envAddress("INTERCHAIN_GAS_PAYMASTER");
        
        require(messenger.mailbox() == expectedMailbox, "Mailbox mismatch");
        require(messenger.gasPaymaster() == expectedGasPaymaster, "Gas paymaster mismatch");
        
        console.log("SUCCESS: CrossChainMessenger configuration verified");
        console.log("  Mailbox:", messenger.mailbox());
        console.log("  Gas Paymaster:", messenger.gasPaymaster());
    }

    function verifyYieldDistributorConfig(address distributorAddr) internal view {
        YieldDistributor distributor = YieldDistributor(distributorAddr);
        
        // Verify configuration
        address expectedUSDC = vm.envAddress("USDC_ADDRESS");
        uint256 expectedManagementFee = vm.envUint("MANAGEMENT_FEE");
        
        require(distributor.usdc() == expectedUSDC, "YieldDistributor USDC mismatch");
        require(distributor.managementFee() == expectedManagementFee, "YieldDistributor fee mismatch");
        
        console.log("SUCCESS: YieldDistributor configuration verified");
        console.log("  USDC:", distributor.usdc());
        console.log("  Management Fee:", distributor.managementFee(), "bps");
        console.log("  Treasury:", distributor.treasury());
    }

    function verifyPermissions(DeployedContracts memory contracts) internal view {
        console.log("\n--- Permission Verification ---");
        
        // Load expected admin/owner
        address expectedAdmin = vm.addr(vm.envUint("PRIVATE_KEY"));
        
        // Verify MotherVault ownership
        MotherVault vault = MotherVault(contracts.motherVault);
        require(vault.owner() == expectedAdmin, "MotherVault owner mismatch");
        
        // Verify CCTPBridge admin
        CCTPBridge bridge = CCTPBridge(contracts.cctpBridge);
        require(bridge.hasRole(bridge.DEFAULT_ADMIN_ROLE(), expectedAdmin), "CCTPBridge admin mismatch");
        
        // Verify CrossChainMessenger admin
        CrossChainMessenger messenger = CrossChainMessenger(contracts.crossChainMessenger);
        require(messenger.hasRole(messenger.DEFAULT_ADMIN_ROLE(), expectedAdmin), "Messenger admin mismatch");
        
        // Verify HealthMonitor admin
        HealthMonitor healthMon = HealthMonitor(contracts.healthMonitor);
        require(healthMon.hasRole(healthMon.DEFAULT_ADMIN_ROLE(), expectedAdmin), "HealthMonitor admin mismatch");
        
        console.log("SUCCESS: All permissions verified");
        console.log("  Admin/Owner:", expectedAdmin);
    }

    function verifyIntegration(DeployedContracts memory contracts) internal view {
        console.log("\n--- Integration Verification ---");
        
        MotherVault vault = MotherVault(contracts.motherVault);
        
        // Verify contract relationships
        require(vault.crossChainMessenger() == contracts.crossChainMessenger, "Messenger not set");
        require(vault.rebalancer() == contracts.rebalancer, "Rebalancer not set");
        require(vault.yieldDistributor() == contracts.yieldDistributor, "YieldDistributor not set");
        require(vault.healthMonitor() == contracts.healthMonitor, "HealthMonitor not set");
        
        // Verify vault state
        require(vault.totalAssets() == 0, "Vault should have zero assets initially");
        require(vault.totalSupply() == 0, "Vault should have zero shares initially");
        
        console.log("SUCCESS: Contract integration verified");
        console.log("  All contracts properly linked");
        console.log("  Vault initialized with zero assets/shares");
    }

    function logDeploymentStatus(DeployedContracts memory contracts) internal view {
        console.log("\n=== DEPLOYMENT STATUS ===");
        console.log("Network:", getNetworkName());
        console.log("Chain ID:", block.chainid);
        console.log("Block Number:", block.number);
        console.log("Timestamp:", block.timestamp);
        
        console.log("\n--- Deployed Contracts ---");
        console.log("MotherVault:", contracts.motherVault);
        console.log("CCTPBridge:", contracts.cctpBridge);
        console.log("CrossChainMessenger:", contracts.crossChainMessenger);
        console.log("Rebalancer:", contracts.rebalancer);
        console.log("YieldDistributor:", contracts.yieldDistributor);
        console.log("HealthMonitor:", contracts.healthMonitor);
        
        console.log("\n--- Configuration Summary ---");
        MotherVault vault = MotherVault(contracts.motherVault);
        console.log("Asset:", vault.asset());
        console.log("Deposit Cap:", vault.depositCap() / 1e6, "USDC");
        console.log("Management Fee:", vault.managementFee(), "bps");
        console.log("Owner:", vault.owner());
        
        console.log("\n--- Next Steps ---");
        console.log("1. Deploy child vaults on Katana and Zircuit");
        console.log("2. Configure cross-chain relationships");
        console.log("3. Set up monitoring and alerts");
        console.log("4. Update frontend configuration");
        console.log("5. Conduct final testing");
        
        console.log("\nDeployment verification completed successfully!");
    }

    function getNetworkName() internal view returns (string memory) {
        uint256 chainId = block.chainid;
        if (chainId == 1) return "ethereum_mainnet";
        if (chainId == 8453) return "base_mainnet";
        if (chainId == 84532) return "base_sepolia";
        if (chainId == 11155111) return "sepolia";
        return string.concat("chain_", vm.toString(chainId));
    }
}