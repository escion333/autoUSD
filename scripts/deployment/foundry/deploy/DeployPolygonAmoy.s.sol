// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "../../contracts/core/CCTPBridge.sol";
// CrossChainMessenger not needed on Polygon - only on Base
import "../../contracts/interfaces/IChildVault.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Polygon Amoy BridgeVault Deployment
 * @notice Deploys intermediate bridge vault for Base → Polygon → Katana flow
 * @dev Acts as bridge between CCTP (from Base) and AggLayer (to Katana)
 */
contract DeployPolygonAmoy is Script {
    // Polygon Amoy Testnet Configuration
    address constant USDC_POLYGON_AMOY = 0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582;
    address constant HYPERLANE_MAILBOX = 0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766;
    address constant CCTP_TOKEN_MESSENGER = 0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5;
    address constant CCTP_MESSAGE_TRANSMITTER = 0x26413e8157CD32011E726065a5462e97dD4d03D9;
    address constant INTERCHAIN_GAS_PAYMASTER = 0x6cA0B6D22da47f091B7613223cD4BB03a2d77918;
    
    // Domain IDs
    uint32 constant BASE_DOMAIN = 10002; // Base Sepolia CCTP domain
    uint32 constant POLYGON_DOMAIN = 7; // Polygon PoS CCTP domain (Amoy testnet uses same domain)
    uint32 constant KATANA_DOMAIN = 129399; // Tatara testnet Hyperlane domain
    
    // Protocol parameters
    uint256 constant MIN_BRIDGE_AMOUNT = 10e6; // $10 minimum
    uint256 constant BRIDGE_COOLDOWN = 3600; // 1 hour

    struct DeployedContracts {
        address bridgeVault;
        address cctpBridge;
        address aggLayerAdapter;
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Starting Polygon Amoy BridgeVault Deployment...");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        require(block.chainid == 80002, "Must deploy to Polygon Amoy (80002)");
        
        DeployedContracts memory contracts = deployContracts(deployer);
        configureContracts(contracts, deployer);
        verifyDeployment(contracts, deployer);
        saveDeploymentData(contracts);
        
        vm.stopBroadcast();
        
        console.log("\n[SUCCESS] Polygon Amoy deployment completed!");
        logDeploymentSummary(contracts);
    }

    function deployContracts(address deployer) 
        internal 
        returns (DeployedContracts memory contracts) 
    {
        console.log("\n--- Deploying Bridge Infrastructure ---");
        
        // Deploy BridgeVault
        console.log("Deploying BridgeVault...");
        BridgeVault bridgeVault = new BridgeVault(
            USDC_POLYGON_AMOY,
            deployer
        );
        contracts.bridgeVault = address(bridgeVault);
        
        // Deploy CCTPBridge for receiving from Base
        console.log("Deploying CCTPBridge...");
        CCTPBridge cctpBridge = new CCTPBridge(
            CCTP_TOKEN_MESSENGER,
            CCTP_MESSAGE_TRANSMITTER,
            USDC_POLYGON_AMOY,
            deployer
        );
        contracts.cctpBridge = address(cctpBridge);
        
        // CrossChainMessenger not needed on Polygon - messages come from Base
        
        // Deploy AggLayerAdapter for Katana bridging
        console.log("Deploying AggLayerAdapter...");
        AggLayerAdapter aggAdapter = new AggLayerAdapter(
            contracts.bridgeVault,
            USDC_POLYGON_AMOY,
            deployer
        );
        contracts.aggLayerAdapter = address(aggAdapter);
        
        console.log("[SUCCESS] Bridge infrastructure deployed");
    }

    function configureContracts(
        DeployedContracts memory contracts,
        address deployer
    ) internal {
        console.log("\n--- Configuring Contracts ---");
        
        // Configure BridgeVault
        BridgeVault vault = BridgeVault(contracts.bridgeVault);
        vault.setCCTPBridge(contracts.cctpBridge);
        vault.setAggLayerAdapter(contracts.aggLayerAdapter);
        vault.setMinBridgeAmount(MIN_BRIDGE_AMOUNT);
        vault.setBridgeCooldown(BRIDGE_COOLDOWN);
        
        // Configure CCTP Bridge for Base domain
        CCTPBridge(contracts.cctpBridge).setSupportedDomain(BASE_DOMAIN, true);
        
        // Set supported domain for CCTP to receive from Base
        // Additional domain configuration handled by Base's CrossChainMessenger
        
        console.log("[SUCCESS] Contract configuration completed");
    }

    function verifyDeployment(
        DeployedContracts memory contracts,
        address deployer
    ) internal view {
        console.log("\n--- Verifying Deployment ---");
        
        // Verify BridgeVault
        BridgeVault vault = BridgeVault(contracts.bridgeVault);
        require(vault.asset() == USDC_POLYGON_AMOY, "Vault asset mismatch");
        require(vault.owner() == deployer, "Vault owner mismatch");
        
        // Verify CCTPBridge
        CCTPBridge bridge = CCTPBridge(contracts.cctpBridge);
        require(address(bridge.tokenMessenger()) == CCTP_TOKEN_MESSENGER, "Token messenger mismatch");
        require(address(bridge.usdc()) == USDC_POLYGON_AMOY, "USDC address mismatch");
        
        console.log("[SUCCESS] Deployment verification passed");
    }

    function saveDeploymentData(DeployedContracts memory contracts) internal {
        string memory deploymentData = string.concat(
            "# Polygon Amoy BridgeVault Deployment\n",
            "# Deployed at block: ", vm.toString(block.number), "\n",
            "# Timestamp: ", vm.toString(block.timestamp), "\n\n",
            "BRIDGE_VAULT=", vm.toString(contracts.bridgeVault), "\n",
            "CCTP_BRIDGE=", vm.toString(contracts.cctpBridge), "\n",
            "AGGLAYER_ADAPTER=", vm.toString(contracts.aggLayerAdapter), "\n\n",
            "# Infrastructure\n",
            "USDC_ADDRESS=", vm.toString(USDC_POLYGON_AMOY), "\n",
            "CCTP_TOKEN_MESSENGER=", vm.toString(CCTP_TOKEN_MESSENGER), "\n",
            "CCTP_MESSAGE_TRANSMITTER=", vm.toString(CCTP_MESSAGE_TRANSMITTER), "\n"
        );
        
        vm.writeFile("deployments/polygon_amoy.env", deploymentData);
        console.log("[SUCCESS] Deployment data saved to: deployments/polygon_amoy.env");
    }

    function logDeploymentSummary(DeployedContracts memory contracts) internal pure {
        console.log("\n=== POLYGON AMOY DEPLOYMENT SUMMARY ===");
        console.log("Network: Polygon Amoy (Chain ID: 80002)");
        console.log("\n--- Contract Addresses ---");
        console.log("BridgeVault:", contracts.bridgeVault);
        console.log("CCTPBridge:", contracts.cctpBridge);
        console.log("AggLayerAdapter:", contracts.aggLayerAdapter);
        console.log("\n--- Next Steps ---");
        console.log("1. Deploy KatanaChildVault on Tatara testnet");
        console.log("2. Configure AggLayer bridge connection");
        console.log("3. Set remote addresses in Mother Vault (Base)");
        console.log("4. Test CCTP Base -> Polygon flow");
        console.log("5. Test AggLayer Polygon -> Katana flow");
    }
}

/**
 * @title BridgeVault
 * @notice Intermediate vault on Polygon for two-hop bridging
 */
contract BridgeVault {
    IERC20 public immutable asset;
    address public owner;
    address public cctpBridge;
    address public aggLayerAdapter;
    address public motherVault;
    
    // Domain constants
    uint32 public constant BASE_DOMAIN = 6;
    uint32 public constant POLYGON_DOMAIN = 7;
    
    uint256 public minBridgeAmount;
    uint256 public bridgeCooldown;
    uint256 public lastBridgeTime;
    
    mapping(address => uint256) public pendingWithdrawals;
    
    event FundsReceived(uint256 amount, address from);
    event FundsBridgedToKatana(uint256 amount);
    event FundsReturnedToBase(uint256 amount, address recipient);
    
    constructor(address _asset, address _owner) {
        asset = IERC20(_asset);
        owner = _owner;
    }
    
    function setCCTPBridge(address _bridge) external {
        require(msg.sender == owner, "Only owner");
        cctpBridge = _bridge;
    }
    
    function setAggLayerAdapter(address _adapter) external {
        require(msg.sender == owner, "Only owner");
        aggLayerAdapter = _adapter;
    }
    
    function setMinBridgeAmount(uint256 _amount) external {
        require(msg.sender == owner, "Only owner");
        minBridgeAmount = _amount;
    }
    
    function setBridgeCooldown(uint256 _cooldown) external {
        require(msg.sender == owner, "Only owner");
        bridgeCooldown = _cooldown;
    }
    
    function receiveFromBase(uint256 amount) external {
        require(msg.sender == cctpBridge, "Only CCTP bridge");
        emit FundsReceived(amount, msg.sender);
        
        // Auto-bridge to Katana if threshold met
        if (asset.balanceOf(address(this)) >= minBridgeAmount) {
            _bridgeToKatana();
        }
    }
    
    function _bridgeToKatana() internal {
        require(block.timestamp >= lastBridgeTime + bridgeCooldown, "Cooldown active");
        
        uint256 balance = asset.balanceOf(address(this));
        require(balance >= minBridgeAmount, "Below minimum");
        
        // Transfer to AggLayer adapter
        asset.transfer(aggLayerAdapter, balance);
        
        // Trigger AggLayer bridge
        IAggLayerAdapter(aggLayerAdapter).bridgeToKatana(balance);
        
        lastBridgeTime = block.timestamp;
        emit FundsBridgedToKatana(balance);
    }
    
    function returnToBase(uint256 amount, address recipient) external {
        require(msg.sender == aggLayerAdapter, "Only AggLayer");
        
        // Burn and send back via CCTP
        // Note: This needs to be implemented in CCTPBridge contract
        ICCTPBridge(cctpBridge).burnAndBridgeToRecipient(amount, recipient, BASE_DOMAIN);
        
        emit FundsReturnedToBase(amount, recipient);
    }
}

/**
 * @title AggLayerAdapter
 * @notice Handles bridging to/from Katana Network via AggLayer
 */
contract AggLayerAdapter {
    address public immutable bridgeVault;
    address public immutable usdcToken;
    address public owner;
    address public katanaChildVault;
    
    // AggLayer VaultBridge address (to be configured)
    address public vaultBridge;
    
    constructor(address _bridgeVault, address _usdcToken, address _owner) {
        bridgeVault = _bridgeVault;
        usdcToken = _usdcToken;
        owner = _owner;
    }
    
    function setVaultBridge(address _vaultBridge) external {
        require(msg.sender == owner, "Only owner");
        vaultBridge = _vaultBridge;
    }
    
    function setKatanaChildVault(address _vault) external {
        require(msg.sender == owner, "Only owner");
        katanaChildVault = _vault;
    }
    
    function bridgeToKatana(uint256 amount) external {
        require(msg.sender == bridgeVault, "Only bridge vault");
        
        // TODO: Implement actual AggLayer bridge call
        // This will interact with VaultBridge to move funds to Katana
        // For now, this is a placeholder
        
        // IVaultBridge(vaultBridge).bridge(
        //     katanaChildVault,
        //     amount,
        //     KATANA_DOMAIN
        // );
    }
    
    function receiveFromKatana(uint256 amount) external {
        // TODO: Implement receipt from Katana
        // This will be called by AggLayer when funds return
        
        // Transfer back to BridgeVault for CCTP return
        IERC20(usdcToken).transfer(bridgeVault, amount);
    }
}

// Interfaces
interface ICCTPBridge {
    function burnAndBridgeToRecipient(uint256 amount, address recipient, uint32 destinationDomain) external returns (bytes32);
}

interface IAggLayerAdapter {
    function bridgeToKatana(uint256 amount) external;
}