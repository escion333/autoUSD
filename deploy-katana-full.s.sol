// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "./contracts/yield-strategies/KatanaChildVault.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// SushiSwap V2 interfaces
interface ISushiV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface ISushiV2Router {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
}

// Mock ERC20 for testing
contract MockToken {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol, uint256 _totalSupply) {
        name = _name;
        symbol = _symbol;
        totalSupply = _totalSupply;
        balanceOf[msg.sender] = _totalSupply;
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

contract DeployKatanaFull is Script {
    // Katana SushiSwap infrastructure
    address constant SUSHI_FACTORY = 0x9B3336186a38E1b6c21955d112dbb0343Ee061eE;
    address constant SUSHI_ROUTER = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506; // Assuming standard router
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("SushiSwap Factory:", SUSHI_FACTORY);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy mock tokens for testing (in real deployment, use bridge USDC)
        MockToken usdc = new MockToken("Bridged USDC", "VBUSDC", 1000000 * 1e6); // 1M USDC with 6 decimals
        MockToken usdt = new MockToken("Bridged USDT", "VBUSDT", 1000000 * 1e6); // 1M USDT with 6 decimals
        
        console.log("Mock USDC deployed:", address(usdc));
        console.log("Mock USDT deployed:", address(usdt));
        
        // Create SushiSwap pair
        ISushiV2Factory factory = ISushiV2Factory(SUSHI_FACTORY);
        address pair = factory.createPair(address(usdc), address(usdt));
        
        console.log("SushiSwap USDC/USDT pair created:", pair);
        
        // Deploy KatanaChildVault with real addresses
        KatanaChildVault childVault = new KatanaChildVault(
            address(usdc),       // _usdc
            SUSHI_ROUTER,        // _katanaRouter  
            pair,                // _katanaPair
            address(0),          // _masterChef (mock for now)
            address(0),          // _sushiToken (mock for now)
            address(0),          // _crossChainMessenger (set later)
            address(0),          // _cctpBridge (set later)
            deployer             // _admin
        );
        
        console.log("KatanaChildVault deployed:", address(childVault));
        
        // Optional: Add initial liquidity to the pair (for testing)
        if (usdc.balanceOf(deployer) >= 1000 * 1e6 && usdt.balanceOf(deployer) >= 1000 * 1e6) {
            console.log("Adding initial liquidity...");
            
            usdc.approve(SUSHI_ROUTER, 1000 * 1e6);
            usdt.approve(SUSHI_ROUTER, 1000 * 1e6);
            
            ISushiV2Router router = ISushiV2Router(SUSHI_ROUTER);
            router.addLiquidity(
                address(usdc),
                address(usdt),
                1000 * 1e6,      // 1000 USDC
                1000 * 1e6,      // 1000 USDT
                950 * 1e6,       // min USDC (5% slippage)
                950 * 1e6,       // min USDT (5% slippage)
                deployer,        // LP tokens to deployer
                block.timestamp + 300 // 5 min deadline
            );
            
            console.log("Initial liquidity added");
        }
        
        vm.stopBroadcast();
        
        console.log("\n===== KATANA DEPLOYMENT COMPLETE =====");
        console.log("Mock USDC:", address(usdc));
        console.log("Mock USDT:", address(usdt));
        console.log("SushiSwap Pair:", pair);
        console.log("KatanaChildVault:", address(childVault));
        console.log("Factory:", SUSHI_FACTORY);
        console.log("Router:", SUSHI_ROUTER);
    }
}