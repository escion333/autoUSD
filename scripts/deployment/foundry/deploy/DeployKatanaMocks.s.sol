// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title Deploy Katana Mock Contracts
 * @notice Deploys mock contracts for testing on Katana Bokuto testnet
 * @dev Use this to deploy test infrastructure before mainnet addresses are available
 */
contract DeployKatanaMocks is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Deploying Mock Contracts to Katana Network...");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        
        // Deploy Mock USDC (VBUSDC - VaultBridge Bridged USDC)
        MockUSDC usdc = new MockUSDC();
        console.log("Mock VBUSDC deployed at:", address(usdc));
        
        // Deploy Mock SushiSwap V3 Router
        MockSushiV3Router router = new MockSushiV3Router(address(usdc));
        console.log("Mock SushiV3Router deployed at:", address(router));
        
        // Deploy Mock SushiSwap V3 Factory
        MockSushiV3Factory factory = new MockSushiV3Factory();
        console.log("Mock SushiV3Factory deployed at:", address(factory));
        
        // Deploy Mock Position Manager
        MockPositionManager positionManager = new MockPositionManager(
            address(factory),
            address(usdc)
        );
        console.log("Mock PositionManager deployed at:", address(positionManager));
        
        // Mint some test USDC to deployer
        usdc.mint(deployer, 10000 * 1e6); // 10,000 USDC
        console.log("Minted 10,000 USDC to deployer");
        
        // Save deployment data
        string memory deploymentData = string.concat(
            "# Katana Mock Contracts\n",
            "# Chain ID: ", vm.toString(block.chainid), "\n",
            "# Deployed at block: ", vm.toString(block.number), "\n\n",
            "MOCK_VBUSDC=", vm.toString(address(usdc)), "\n",
            "MOCK_SUSHI_V3_ROUTER=", vm.toString(address(router)), "\n",
            "MOCK_SUSHI_V3_FACTORY=", vm.toString(address(factory)), "\n",
            "MOCK_POSITION_MANAGER=", vm.toString(address(positionManager)), "\n"
        );
        
        vm.writeFile("deployments/katana_mocks.env", deploymentData);
        console.log("Deployment data saved to: deployments/katana_mocks.env");
        
        vm.stopBroadcast();
    }
}

/**
 * @title Mock VBUSDC (VaultBridge Bridged USDC)
 * @notice Mock USDC for testing on Katana
 */
contract MockUSDC is ERC20 {
    constructor() ERC20("VaultBridge Bridged USDC", "VBUSDC") {}
    
    function decimals() public pure override returns (uint8) {
        return 6; // USDC has 6 decimals
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title Mock SushiSwap V3 Router
 * @notice Simplified router for testing
 */
contract MockSushiV3Router {
    address public immutable VBUSDC;
    
    constructor(address _usdc) {
        VBUSDC = _usdc;
    }
    
    function exactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        address recipient,
        uint256 deadline,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint160 sqrtPriceLimitX96
    ) external returns (uint256 amountOut) {
        // Mock swap - just transfer tokens
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        
        // Mock 1:1 swap for simplicity
        amountOut = amountIn;
        if (tokenOut == VBUSDC) {
            MockUSDC(VBUSDC).mint(recipient, amountOut);
        }
        
        return amountOut;
    }
}

/**
 * @title Mock SushiSwap V3 Factory
 * @notice Simplified factory for testing
 */
contract MockSushiV3Factory {
    mapping(address => mapping(address => mapping(uint24 => address))) public pools;
    
    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external returns (address pool) {
        pool = address(new MockPool(tokenA, tokenB, fee));
        pools[tokenA][tokenB][fee] = pool;
        pools[tokenB][tokenA][fee] = pool;
        return pool;
    }
    
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address) {
        return pools[tokenA][tokenB][fee];
    }
}

/**
 * @title Mock Pool
 * @notice Simplified pool for testing
 */
contract MockPool {
    address public immutable token0;
    address public immutable token1;
    uint24 public immutable fee;
    
    constructor(address _token0, address _token1, uint24 _fee) {
        token0 = _token0;
        token1 = _token1;
        fee = _fee;
    }
}

/**
 * @title Mock Position Manager
 * @notice Simplified position manager for testing
 */
contract MockPositionManager {
    address public immutable factory;
    address public immutable VBUSDC;
    uint256 public nextTokenId = 1;
    
    struct Position {
        address owner;
        address token0;
        address token1;
        uint24 fee;
        uint128 liquidity;
    }
    
    mapping(uint256 => Position) public positions;
    
    constructor(address _factory, address _usdc) {
        factory = _factory;
        VBUSDC = _usdc;
    }
    
    function mint(
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Desired,
        uint128 amount1Desired,
        uint128 amount0Min,
        uint128 amount1Min,
        address recipient,
        uint256 deadline
    ) external returns (
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    ) {
        // Mock minting - just store position
        tokenId = nextTokenId++;
        liquidity = amount0Desired; // Simplified
        
        positions[tokenId] = Position({
            owner: recipient,
            token0: token0,
            token1: token1,
            fee: fee,
            liquidity: liquidity
        });
        
        // Transfer tokens (simplified)
        IERC20(token0).transferFrom(msg.sender, address(this), amount0Desired);
        IERC20(token1).transferFrom(msg.sender, address(this), amount1Desired);
        
        return (tokenId, liquidity, amount0Desired, amount1Desired);
    }
}

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}