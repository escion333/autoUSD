// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "../../contracts/yield-strategies/KatanaChildVault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Mock contracts for Katana chain testing
contract MockUSDC is ERC20 {
    address public owner;
    
    constructor() ERC20("Mock USDC", "USDC") {
        owner = msg.sender;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "MockUSDC: Only owner can mint");
        _;
    }
    
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract MockStablecoin is ERC20 {
    address public owner;
    
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        owner = msg.sender;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "MockStablecoin: Only owner can mint");
        _;
    }
    
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract MockSushiPool is ERC20 {
    address public token0;
    address public token1;
    uint256 public constant fee = 3000; // 0.3%
    
    constructor(address _token0, address _token1) ERC20("SushiLP", "SLP") {
        token0 = _token0;
        token1 = _token1;
        // Mint initial LP supply to simulate existing liquidity
        _mint(address(this), 1000000 * 1e18);
    }
    
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) {
        return (1000000 * 1e6, 1000000 * 1e6, uint32(block.timestamp)); // Mock 1M:1M reserves
    }
    
    function mint(address to) external returns (uint256 liquidity) {
        // Mock: transfer tokens from user to pool, mint LP tokens
        IERC20(token0).transferFrom(msg.sender, address(this), 500 * 1e6);
        IERC20(token1).transferFrom(msg.sender, address(this), 500 * 1e6);
        
        liquidity = 1000 * 1e18; // Mock LP tokens
        _mint(to, liquidity);
        return liquidity;
    }
    
    function burn(address to) external returns (uint256 amount0, uint256 amount1) {
        uint256 lpBalance = balanceOf(msg.sender);
        require(lpBalance > 0, "No LP tokens to burn");
        
        amount0 = 500 * 1e6; // Mock withdrawal amounts
        amount1 = 500 * 1e6;
        
        // Burn LP tokens and transfer underlying assets
        _burn(msg.sender, lpBalance);
        IERC20(token0).transfer(to, amount0);
        IERC20(token1).transfer(to, amount1);
        
        return (amount0, amount1);
    }
}

contract MockSushiRouter {
    address public constant WETH = 0x0000000000000000000000000000000000000001; // Mock WETH address
    
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256,
        uint256,
        address to,
        uint256
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        // Mock successful liquidity addition
        return (amountADesired, amountBDesired, 1000 * 1e18);
    }
    
    function removeLiquidity(
        address,
        address,
        uint256 liquidity,
        uint256,
        uint256,
        address to,
        uint256
    ) external returns (uint256 amountA, uint256 amountB) {
        // Mock successful liquidity removal
        return (liquidity / 2, liquidity / 2);
    }
    
    function getAmountsOut(uint256 amountIn, address[] memory)
        external
        pure
        returns (uint256[] memory amounts)
    {
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountIn; // 1:1 mock exchange rate
        return amounts;
    }
    
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256,
        address[] memory,
        address,
        uint256
    ) external pure returns (uint256[] memory amounts) {
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountIn; // 1:1 mock swap
        return amounts;
    }
}

contract MockMailbox {
    event MessageDispatched(uint32 domain, bytes32 recipient, bytes message);
    
    function dispatch(uint32 domain, bytes32 recipient, bytes memory message) 
        external 
        payable 
        returns (bytes32) 
    {
        emit MessageDispatched(domain, recipient, message);
        return keccak256(abi.encode(block.timestamp, domain, recipient));
    }
    
    function quoteDispatch(uint32, bytes32, bytes memory) 
        external 
        pure 
        returns (uint256) 
    {
        return 0.001 ether;
    }
}

contract MockGasPaymaster {
    function payGas(bytes32, uint256, uint256, address) external payable {}
}

contract DeployKatana is Script {
    // Domain IDs
    uint32 constant BASE_DOMAIN = 6; // CCTP v2 domain for Base
    uint32 constant KATANA_DOMAIN = 100; // Custom domain for Katana (not CCTP)
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy mock tokens
        MockUSDC usdc = new MockUSDC();
        MockStablecoin usdt = new MockStablecoin("Mock USDT", "USDT");
        
        // Deploy mock SushiSwap infrastructure
        MockSushiPool sushiPool = new MockSushiPool(address(usdc), address(usdt));
        MockSushiRouter sushiRouter = new MockSushiRouter();
        
        // Deploy mock Hyperlane
        MockMailbox mailbox = new MockMailbox();
        MockGasPaymaster gasPaymaster = new MockGasPaymaster();
        
        // Deploy KatanaChildVault
        KatanaChildVault katanaVault = new KatanaChildVault(
            address(usdc),              // _usdc
            address(sushiRouter),       // _katanaRouter  
            address(sushiPool),         // _katanaPair (this is correct - pool acts as pair)
            address(0),                 // _masterChef (not used in POC)
            address(0),                 // _sushiToken (not used in POC)
            address(mailbox),           // _crossChainMessenger
            address(0),                 // _cctpBridge (placeholder)
            deployer                    // _admin
        );
        
        // Configure vault settings
        try katanaVault.setSlippage(50) { // 0.5% slippage
            console.log("Katana: Slippage set to 0.5%");
        } catch Error(string memory reason) {
            console.log("Failed to set slippage:", reason);
        }
        
        try katanaVault.setSecurityLimits(1000 * 1e6, 50000 * 1e6) { // 1k min, 50k max
            console.log("Katana: Security limits set (1k-50k USDC)");
        } catch Error(string memory reason) {
            console.log("Failed to set security limits:", reason);
        }
        
        // Configure mother vault connection
        try katanaVault.setMotherVault(deployer, BASE_DOMAIN) { // Use deployer as placeholder mother vault
            console.log("Katana: Mother vault set to Base domain");
        } catch Error(string memory reason) {
            console.log("Failed to set mother vault:", reason);
        }
        
        // Mint test tokens
        usdc.mint(deployer, 5000 * 1e6); // 5k USDC
        usdt.mint(deployer, 5000 * 1e6); // 5k USDT
        console.log("Minted 5,000 USDC and 5,000 USDT to deployer");
        
        // Approve tokens for testing - pools need approvals for liquidity operations
        usdc.approve(address(katanaVault), 1000 * 1e6);  // Vault needs USDC approval
        usdt.approve(address(sushiPool), 1000 * 1e6);    // Pool needs USDT approval for LP
        usdc.approve(address(sushiPool), 1000 * 1e6);    // Pool needs USDC approval for LP
        console.log("Approved tokens for vault and liquidity operations");
        
        vm.stopBroadcast();
        
        // Log deployment info
        console.log("\n===== KATANA CHAIN DEPLOYMENT =====");
        console.log("Chain ID:", block.chainid);
        console.log("Deployer:", deployer);
        console.log("\n--- Core Contracts ---");
        console.log("KatanaChildVault:", address(katanaVault));
        console.log("\n--- Mock Infrastructure ---");
        console.log("USDC:", address(usdc));
        console.log("USDT:", address(usdt));
        console.log("SushiSwap Pool:", address(sushiPool));
        console.log("SushiSwap Router:", address(sushiRouter));
        console.log("Hyperlane Mailbox:", address(mailbox));
        console.log("\n--- Configuration ---");
        console.log("Slippage Tolerance: 0.5%");
        console.log("Security Limits: 1k-50k USDC");
        console.log("Test USDC Balance:", usdc.balanceOf(deployer) / 1e6, "USDC");
        console.log("Test USDT Balance:", usdt.balanceOf(deployer) / 1e6, "USDT");
        
        // Log key addresses for manual saving
        console.log("\n===== SAVE THESE ADDRESSES =====");
        console.log("export KATANA_VAULT=", address(katanaVault));
        console.log("export KATANA_USDC=", address(usdc));
        console.log("export KATANA_USDT=", address(usdt));
        console.log("export KATANA_POOL=", address(sushiPool));
        console.log("export KATANA_ROUTER=", address(sushiRouter));
        console.log("export KATANA_MAILBOX=", address(mailbox));
    }
}