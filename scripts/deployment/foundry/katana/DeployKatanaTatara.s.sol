// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "../../contracts/yield-strategies/KatanaChildVault.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Interface for SushiSwap V3 Factory
interface ISushiSwapV3Factory {
    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external returns (address pool);
    
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address pool);
}

// Interface for SushiSwap V3 Pool
interface ISushiSwapV3Pool {
    function initialize(uint160 sqrtPriceX96) external;
    function token0() external view returns (address);
    function token1() external view returns (address);
    function fee() external view returns (uint24);
}

contract DeployKatanaTatara is Script {
    // Katana Tatara testnet addresses (from contracts.katana.tools)
    address constant SUSHISWAP_V3_FACTORY = 0x9B3336186a38E1b6c21955d112dbb0343Ee061eE;
    address constant SUSHISWAP_V3_POSITION_MANAGER = 0x1400feFD6F9b897970f00Df6237Ff2B8b27Dc82C;
    address constant SUSHISWAP_V3_SWAP_ROUTER = 0x0e4e59f8492cb88033bA5083199eDB37d5039305;
    
    // VBUSDC (Virtual Bridged USDC) on Tatara
    address constant VBUSDC = 0xAC8414eBFE5A55eA5859aF373371EE3233fFF7CD;
    
    // USDT on Tatara (for USDC/USDT pool)
    address constant USDT = 0xA617Ec5cBC004A6a8b8ECd965B1ef848350e7e73;
    
    // Domain configuration
    uint32 constant MOTHER_DOMAIN = 1; // Base (mother vault domain)
    uint32 constant KATANA_DOMAIN = 2; // Katana domain ID in AggLayer (to be confirmed)
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("\n===== KATANA TATARA DEPLOYMENT =====");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("Expected Chain ID: 129399"); // Correct Tatara chain ID
        console.log("Deployer balance:", deployer.balance / 1e18, "ETH");
        
        // Get Mother Vault address from env (deployed on Base Sepolia)
        address motherVault;
        try vm.envAddress("MOTHER_VAULT_BASE") returns (address addr) {
            motherVault = addr;
            require(motherVault != address(0), "Invalid MOTHER_VAULT_BASE address");
        } catch {
            revert("MOTHER_VAULT_BASE environment variable not set. Deploy Base Sepolia first.");
        }
        console.log("Mother Vault (Base):", motherVault);
        
        // Get Bridge Vault for reference
        address bridgeVault;
        try vm.envAddress("BRIDGE_VAULT_POLYGON") returns (address addr) {
            bridgeVault = addr;
            require(bridgeVault != address(0), "Invalid BRIDGE_VAULT_POLYGON address");
        } catch {
            revert("BRIDGE_VAULT_POLYGON environment variable not set. Deploy Polygon Amoy first.");
        }
        console.log("Bridge Vault (Polygon):", bridgeVault);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy KatanaChildVault
        KatanaChildVault childVault = new KatanaChildVault(
            VBUSDC,                          // asset (VBUSDC)
            "Katana autoUSD Child",          // name
            "kaUSD",                         // symbol
            SUSHISWAP_V3_POSITION_MANAGER,  // position manager
            SUSHISWAP_V3_FACTORY,           // factory
            motherVault                     // mother vault (actual mother on Base)
        );
        console.log("KatanaChildVault deployed:", address(childVault));
        
        // Configure child vault
        childVault.setMotherDomain(MOTHER_DOMAIN);
        console.log("Mother domain set to:", MOTHER_DOMAIN);
        
        // Mother vault is already set in constructor
        console.log("Mother vault configured:", motherVault);
        
        // Create or verify VBUSDC/USDT pool
        uint24 poolFee = 3000; // 0.3% fee tier
        
        ISushiSwapV3Factory factory = ISushiSwapV3Factory(SUSHISWAP_V3_FACTORY);
        address existingPool = factory.getPool(VBUSDC, USDT, poolFee);
        
        if (existingPool == address(0)) {
            console.log("VBUSDC/USDT pool doesn't exist. Creating new pool...");
            
            // Create the pool
            address newPool = factory.createPool(VBUSDC, USDT, poolFee);
            console.log("Pool created at:", newPool);
            
            // Initialize the pool with 1:1 price ratio (assuming both are stablecoins)
            // sqrtPriceX96 = sqrt(1) * 2^96 = 2^96
            uint160 sqrtPriceX96 = 79228162514264337593543950336; // 2^96
            
            ISushiSwapV3Pool pool = ISushiSwapV3Pool(newPool);
            pool.initialize(sqrtPriceX96);
            console.log("Pool initialized with 1:1 price ratio");
            
            // Configure child vault with the new pool
            childVault.addPair(USDT, poolFee);
            console.log("Added VBUSDC/USDT pair to child vault");
        } else {
            console.log("VBUSDC/USDT pool already exists at:", existingPool);
            
            // Configure child vault with existing pool
            childVault.addPair(USDT, poolFee);
            console.log("Added existing VBUSDC/USDT pair to child vault");
        }
        
        console.log("Pool configuration:");
        console.log("- VBUSDC:", VBUSDC);
        console.log("- USDT:", USDT);
        console.log("- Fee tier: 0.3%");
        
        vm.stopBroadcast();
        
        console.log("\n===== DEPLOYMENT COMPLETE =====");
        console.log("\n--- Deployed Contracts ---");
        console.log("KatanaChildVault:", address(childVault));
        
        console.log("\n--- SushiSwap V3 Configuration ---");
        console.log("Factory:", SUSHISWAP_V3_FACTORY);
        console.log("Position Manager:", SUSHISWAP_V3_POSITION_MANAGER);
        console.log("Swap Router:", SUSHISWAP_V3_SWAP_ROUTER);
        
        console.log("\n--- Token Addresses ---");
        console.log("VBUSDC:", VBUSDC);
        console.log("USDT:", USDT);
        
        console.log("\n===== NEXT STEPS =====");
        console.log("1. Update BridgeVault on Polygon with KatanaChildVault address");
        console.log("2. Configure AggLayer bridge between Polygon and Katana");
        console.log("3. Update KatanaChildVault with actual MotherVault address");
        console.log("4. Test cross-chain flow from Base -> Polygon -> Katana");
        
        // Export for use in other scripts
        console.log("\n===== EXPORT COMMANDS =====");
        console.log("export KATANA_CHILD_VAULT=", address(childVault));
        console.log("export VBUSDC_KATANA=", VBUSDC);
        console.log("export USDT_KATANA=", USDT);
    }
}