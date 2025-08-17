// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "../../contracts/interfaces/IChildVault.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Katana Tatara Testnet Deployment
 * @notice Deploys KatanaChildVault on Tatara testnet (Katana Network)
 * @dev Final destination in Base → Polygon → Katana flow
 * @dev Uses real SushiSwap V3 addresses from contracts.katana.tools
 */
contract DeployKatanaTatara is Script {
    using SafeERC20 for IERC20;
    
    // Tatara Testnet Configuration - REAL ADDRESSES from contracts.katana.tools
    // Chain ID: 129399 (0x1f977)
    // RPC: https://rpc.tatara.katanarpc.com/
    // Explorer: https://explorer.tatara.katana.network/
    
    // VaultBridge USDC on origin chain (Sepolia for Tatara)
    address constant VBUSDC_ORIGIN = 0xAC8414eBFE5A55eA5859aF373371EE3233fFF7CD;
    
    // SushiSwap V3 Contracts on Tatara
    address constant SUSHI_V3_FACTORY = 0x9B3336186a38E1b6c21955d112dbb0343Ee061eE;
    address constant SUSHI_V3_POSITION_MANAGER = 0x1400feFD6F9b897970f00Df6237Ff2B8b27Dc82C;
    
    // We'll need to get the router address or deploy one
    address constant SUSHI_V3_ROUTER = address(0); // TODO: Get from Katana team
    
    // Network configuration
    uint256 constant TATARA_CHAIN_ID = 129399;
    uint32 constant POLYGON_DOMAIN = 7;
    
    // Protocol parameters
    uint256 constant MIN_LIQUIDITY = 100e6; // $100 minimum
    uint256 constant TARGET_APY = 1000; // 10% target APY

    struct DeployedContracts {
        address katanaChildVault;
        address yieldStrategy;
        address aggLayerReceiver;
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Starting Katana Tatara Deployment...");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        
        // Check for Tatara testnet
        if (block.chainid == TATARA_CHAIN_ID) {
            console.log("Deploying to Tatara Testnet");
        } else if (block.chainid == 747474) {
            console.log("Deploying to Katana Mainnet Fork (Local)");
        } else {
            console.log("WARNING: Unexpected chain ID, proceeding anyway");
        }
        
        DeployedContracts memory contracts = deployContracts(deployer);
        configureContracts(contracts, deployer);
        verifyDeployment(contracts, deployer);
        saveDeploymentData(contracts);
        
        vm.stopBroadcast();
        
        console.log("\n[SUCCESS] Katana Tatara deployment completed!");
        logDeploymentSummary(contracts);
    }

    function deployContracts(address deployer) 
        internal 
        returns (DeployedContracts memory contracts) 
    {
        console.log("\n--- Deploying Katana Infrastructure ---");
        
        // Note: VBUSDC on Tatara would be bridged from Sepolia origin
        // The actual VBUSDC on Tatara will have a different address after bridging
        
        // Deploy KatanaChildVault
        console.log("Deploying KatanaChildVault...");
        console.log("Using SushiSwap V3 Factory:", SUSHI_V3_FACTORY);
        console.log("Using Position Manager:", SUSHI_V3_POSITION_MANAGER);
        
        // For now, we'll use VBUSDC_ORIGIN as placeholder - actual bridged address needed
        KatanaChildVault childVault = new KatanaChildVault(
            VBUSDC_ORIGIN, // This will be the bridged VBUSDC on Tatara
            deployer
        );
        contracts.katanaChildVault = address(childVault);
        
        // Deploy YieldStrategy with SushiSwap V3
        console.log("Deploying KatanaYieldStrategy...");
        KatanaYieldStrategy yieldStrategy = new KatanaYieldStrategy(
            VBUSDC_ORIGIN, // Will be bridged VBUSDC on Tatara
            SUSHI_V3_POSITION_MANAGER, // Use Position Manager for V3 liquidity
            contracts.katanaChildVault
        );
        contracts.yieldStrategy = address(yieldStrategy);
        
        // Deploy AggLayerReceiver
        console.log("Deploying AggLayerReceiver...");
        AggLayerReceiver receiver = new AggLayerReceiver(
            contracts.katanaChildVault,
            VBUSDC_ORIGIN, // Will be bridged VBUSDC on Tatara
            deployer
        );
        contracts.aggLayerReceiver = address(receiver);
        
        console.log("[SUCCESS] Katana infrastructure deployed");
    }

    function configureContracts(
        DeployedContracts memory contracts,
        address deployer
    ) internal {
        console.log("\n--- Configuring Contracts ---");
        
        // Configure KatanaChildVault
        KatanaChildVault vault = KatanaChildVault(contracts.katanaChildVault);
        vault.setYieldStrategy(contracts.yieldStrategy);
        vault.setAggLayerReceiver(contracts.aggLayerReceiver);
        vault.setMinLiquidity(MIN_LIQUIDITY);
        vault.setTargetAPY(TARGET_APY);
        
        // Configure YieldStrategy
        KatanaYieldStrategy(contracts.yieldStrategy).setAuthorizedVault(contracts.katanaChildVault);
        
        // Configure AggLayerReceiver
        AggLayerReceiver(contracts.aggLayerReceiver).setPolygonBridge(address(0)); // TODO: Set actual Polygon bridge
        
        console.log("[SUCCESS] Contract configuration completed");
    }

    function verifyDeployment(
        DeployedContracts memory contracts,
        address deployer
    ) internal view {
        console.log("\n--- Verifying Deployment ---");
        
        // Verify KatanaChildVault
        KatanaChildVault vault = KatanaChildVault(contracts.katanaChildVault);
        require(vault.asset() == VBUSDC_ORIGIN, "Vault asset mismatch");
        require(vault.owner() == deployer, "Vault owner mismatch");
        
        console.log("[SUCCESS] Deployment verification passed");
    }

    function saveDeploymentData(DeployedContracts memory contracts) internal {
        string memory deploymentData = string.concat(
            "# Katana Tatara Deployment\n",
            "# Chain ID: ", vm.toString(block.chainid), "\n",
            "# Deployed at block: ", vm.toString(block.number), "\n",
            "# Timestamp: ", vm.toString(block.timestamp), "\n\n",
            "KATANA_CHILD_VAULT=", vm.toString(contracts.katanaChildVault), "\n",
            "YIELD_STRATEGY=", vm.toString(contracts.yieldStrategy), "\n",
            "AGGLAYER_RECEIVER=", vm.toString(contracts.aggLayerReceiver), "\n\n",
            "# Network Info\n",
            "CHAIN_ID=129399\n",
            "RPC_URL=https://rpc.tatara.katanarpc.com\n",
            "EXPLORER=https://explorer.tatara.katana.network/\n"
        );
        
        vm.writeFile("deployments/katana_tatara.env", deploymentData);
        console.log("[SUCCESS] Deployment data saved to: deployments/katana_tatara.env");
    }

    function logDeploymentSummary(DeployedContracts memory contracts) internal view {
        console.log("\n=== KATANA TATARA DEPLOYMENT SUMMARY ===");
        console.log("Network: Tatara Testnet (Chain ID: ", block.chainid, ")");
        console.log("\n--- Contract Addresses ---");
        console.log("KatanaChildVault:", contracts.katanaChildVault);
        console.log("YieldStrategy:", contracts.yieldStrategy);
        console.log("AggLayerReceiver:", contracts.aggLayerReceiver);
        console.log("\n--- Next Steps ---");
        console.log("1. Connect AggLayer bridge from Polygon");
        console.log("2. Configure yield strategies");
        console.log("3. Test fund reception from Polygon");
        console.log("4. Validate APY calculations");
        console.log("5. Test complete three-chain flow");
    }
}

/**
 * @title KatanaChildVault
 * @notice Child vault implementation for Katana Network
 */
contract KatanaChildVault is IChildVault {
    using SafeERC20 for IERC20;
    
    IERC20 public immutable asset;
    address public owner;
    address public motherVault;
    address public yieldStrategy;
    address public aggLayerReceiver;
    
    uint256 public totalDeposited;
    uint256 public totalYield;
    uint256 public minLiquidity;
    uint256 public targetAPY;
    
    event FundsReceived(uint256 amount);
    event FundsDeployed(uint256 amount);
    event YieldHarvested(uint256 amount);
    event FundsReturned(uint256 amount);
    
    constructor(address _asset, address _owner) {
        asset = IERC20(_asset);
        owner = _owner;
    }
    
    function setYieldStrategy(address _strategy) external {
        require(msg.sender == owner, "Only owner");
        yieldStrategy = _strategy;
    }
    
    function setAggLayerReceiver(address _receiver) external {
        require(msg.sender == owner, "Only owner");
        aggLayerReceiver = _receiver;
    }
    
    function setMinLiquidity(uint256 _min) external {
        require(msg.sender == owner, "Only owner");
        minLiquidity = _min;
    }
    
    function setTargetAPY(uint256 _apy) external {
        require(msg.sender == owner, "Only owner");
        targetAPY = _apy;
    }
    
    function setMotherVault(address _motherVault, uint32) external override {
        require(msg.sender == owner, "Only owner");
        motherVault = _motherVault;
    }
    
    function deployFunds(uint256 amount) external override {
        require(msg.sender == motherVault || msg.sender == aggLayerReceiver, "Unauthorized");
        
        totalDeposited += amount;
        
        // Deploy to yield strategy
        asset.safeTransfer(yieldStrategy, amount);
        IYieldStrategy(yieldStrategy).deposit(amount);
        
        emit FundsDeployed(amount);
    }
    
    function withdrawFunds(uint256 amount) external override {
        require(msg.sender == motherVault, "Only mother vault");
        
        // Withdraw from strategy
        IYieldStrategy(yieldStrategy).withdraw(amount);
        
        // Return via AggLayer
        asset.safeTransfer(aggLayerReceiver, amount);
        IAggLayerReceiver(aggLayerReceiver).bridgeToPolygon(amount);
        
        totalDeposited -= amount;
        emit FundsReturned(amount);
    }
    
    function getAPY() external view override returns (uint256) {
        // Get current APY from yield strategy
        return IYieldStrategy(yieldStrategy).currentAPY();
    }
    
    function getTotalValue() external view override returns (uint256) {
        // Get total value including yields
        return IYieldStrategy(yieldStrategy).totalValue();
    }
    
    function harvestYields() external override {
        uint256 harvested = IYieldStrategy(yieldStrategy).harvest();
        totalYield += harvested;
        emit YieldHarvested(harvested);
    }
}

/**
 * @title KatanaYieldStrategy
 * @notice Manages yield generation on Katana Network
 */
contract KatanaYieldStrategy {
    using SafeERC20 for IERC20;
    
    IERC20 public immutable asset;
    address public immutable dexRouter;
    address public authorizedVault;
    
    uint256 public totalDeposited;
    uint256 public totalEarned;
    
    constructor(address _asset, address _router, address _vault) {
        asset = IERC20(_asset);
        dexRouter = _router;
        authorizedVault = _vault;
    }
    
    function setAuthorizedVault(address _vault) external {
        require(authorizedVault == address(0), "Already set");
        authorizedVault = _vault;
    }
    
    function deposit(uint256 amount) external {
        require(msg.sender == authorizedVault, "Only vault");
        totalDeposited += amount;
        
        // TODO: Implement actual yield strategy
        // This would interact with Katana DEX/yield vaults
    }
    
    function withdraw(uint256 amount) external {
        require(msg.sender == authorizedVault, "Only vault");
        totalDeposited -= amount;
        
        // TODO: Implement withdrawal from yield positions
        asset.safeTransfer(authorizedVault, amount);
    }
    
    function harvest() external returns (uint256) {
        require(msg.sender == authorizedVault, "Only vault");
        
        // TODO: Implement yield harvesting
        uint256 yields = 0; // Calculate actual yields
        totalEarned += yields;
        
        return yields;
    }
    
    function currentAPY() external view returns (uint256) {
        // TODO: Calculate current APY based on strategy performance
        return 1000; // 10% placeholder
    }
    
    function totalValue() external view returns (uint256) {
        return totalDeposited + totalEarned;
    }
}

/**
 * @title AggLayerReceiver
 * @notice Handles fund reception from Polygon via AggLayer
 */
contract AggLayerReceiver {
    address public immutable usdcToken;
    address public katanaChildVault;
    address public owner;
    address public polygonBridge;
    
    constructor(address _vault, address _usdcToken, address _owner) {
        katanaChildVault = _vault;
        usdcToken = _usdcToken;
        owner = _owner;
    }
    
    function setPolygonBridge(address _bridge) external {
        require(msg.sender == owner, "Only owner");
        polygonBridge = _bridge;
    }
    
    function receiveFromPolygon(uint256 amount) external {
        require(msg.sender == polygonBridge, "Only bridge");
        
        // Forward to child vault
        IERC20(usdcToken).transfer(katanaChildVault, amount);
        KatanaChildVault(katanaChildVault).deployFunds(amount);
    }
    
    function bridgeToPolygon(uint256 amount) external {
        require(msg.sender == katanaChildVault, "Only vault");
        
        // TODO: Implement AggLayer bridge back to Polygon
        // This would interact with VaultBridge
    }
}

// Interfaces
interface IYieldStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function harvest() external returns (uint256);
    function currentAPY() external view returns (uint256);
    function totalValue() external view returns (uint256);
}

interface IAggLayerReceiver {
    function bridgeToPolygon(uint256 amount) external;
}