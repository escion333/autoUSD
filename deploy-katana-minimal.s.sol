// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";

// Simple mock router for testing
contract MockSushiRouter {
    address public WETH = 0x4200000000000000000000000000000000000006; // Standard WETH on L2s
    
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity) {
        // Mock implementation
        return (amountADesired, amountBDesired, amountADesired + amountBDesired);
    }
}

// Minimal vault for testing
contract MinimalKatanaVault {
    address public usdc;
    address public router;
    address public admin;
    bool public initialized;
    
    constructor(address _usdc, address _router, address _admin) {
        usdc = _usdc;
        router = _router;
        admin = _admin;
        initialized = true;
    }
    
    function deposit(uint256 amount) external returns (uint256 shares) {
        // Mock deposit
        return amount;
    }
    
    function withdraw(uint256 shares) external returns (uint256 amount) {
        // Mock withdraw
        return shares;
    }
}

// Mock USDC token
contract MockUSDC {
    string public name = "Mock USDC";
    string public symbol = "mUSDC";
    uint8 public decimals = 6;
    uint256 public totalSupply = 1000000 * 1e6;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor() {
        balanceOf[msg.sender] = totalSupply;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract DeployKatanaMinimal is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy mock USDC
        MockUSDC usdc = new MockUSDC();
        console.log("Mock USDC deployed:", address(usdc));
        
        // Deploy mock router
        MockSushiRouter router = new MockSushiRouter();
        console.log("Mock Router deployed:", address(router));
        
        // Deploy minimal vault
        MinimalKatanaVault vault = new MinimalKatanaVault(
            address(usdc),
            address(router),
            deployer
        );
        console.log("Minimal Katana Vault deployed:", address(vault));
        
        vm.stopBroadcast();
        
        console.log("\n===== KATANA MINIMAL DEPLOYMENT COMPLETE =====");
        console.log("Mock USDC:", address(usdc));
        console.log("Mock Router:", address(router));
        console.log("Minimal Vault:", address(vault));
        console.log("Ready for integration testing!");
    }
}