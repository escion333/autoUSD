// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "../../contracts/yield-strategies/ZircuitChildVault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Mock contracts for Zircuit chain testing
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

contract MockZuitPool is ERC20 {
    address public token0;
    address public token1;
    uint256 public constant fee = 3000; // 0.3%
    
    constructor(address _token0, address _token1) ERC20("ZuitLP", "ZLP") {
        token0 = _token0;
        token1 = _token1;
        // Mint initial LP supply to simulate existing liquidity (higher than Katana for better APY)
        _mint(address(this), 2000000 * 1e18);
    }
    
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) {
        return (2000000 * 1e6, 2000000 * 1e6, uint32(block.timestamp)); // Mock 2M:2M reserves (higher than Katana)
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

contract MockZuitRouter {
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
        amounts[1] = (amountIn * 1005) / 1000; // Slightly better rate than Katana (0.5% better)
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
        amounts[1] = (amountIn * 1005) / 1000; // Slightly better rate
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

contract DeployZircuit is Script {
    // Domain IDs
    uint32 constant BASE_DOMAIN = 6; // CCTP v2 domain for Base
    uint32 constant ZIRCUIT_DOMAIN = 101; // Custom domain for Zircuit (not CCTP)
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy mock tokens
        MockUSDC usdc = new MockUSDC();
        MockStablecoin usdt = new MockStablecoin("Mock USDT", "USDT");
        
        // Deploy mock Zuit AMM infrastructure
        MockZuitPool zuitPool = new MockZuitPool(address(usdc), address(usdt));
        MockZuitRouter zuitRouter = new MockZuitRouter();
        
        // Deploy mock Hyperlane
        MockMailbox mailbox = new MockMailbox();
        MockGasPaymaster gasPaymaster = new MockGasPaymaster();
        
        // Deploy ZircuitChildVault
        ZircuitChildVault zircuitVault = new ZircuitChildVault(
            address(usdc),
            address(mailbox), // crossChainMessenger placeholder
            address(0), // cctpBridge placeholder
            deployer // admin
        );
        
        // Configure vault settings
        try zircuitVault.setSlippage(50) { // 0.5% slippage
            console.log("Zircuit: Slippage set to 0.5%");
        } catch Error(string memory reason) {
            console.log("Failed to set slippage:", reason);
        }
        
        try zircuitVault.setSecurityLimits(1000 * 1e6, 50000 * 1e6) { // 1k min, 50k max
            console.log("Zircuit: Security limits set (1k-50k USDC)");
        } catch Error(string memory reason) {
            console.log("Failed to set security limits:", reason);
        }
        
        // Configure mother vault connection
        try zircuitVault.setMotherVault(deployer, BASE_DOMAIN) { // Use deployer as placeholder mother vault
            console.log("Zircuit: Mother vault set to Base domain");
        } catch Error(string memory reason) {
            console.log("Failed to set mother vault:", reason);
        }
        
        // Add USDC/USDT pair to vault
        try zircuitVault.addPair(address(usdt), address(zuitPool), address(zuitRouter)) {
            console.log("Zircuit: USDC/USDT pair added successfully");
        } catch Error(string memory reason) {
            console.log("Failed to add USDC/USDT pair:", reason);
        }
        
        // Mint test tokens
        usdc.mint(deployer, 5000 * 1e6); // 5k USDC
        usdt.mint(deployer, 5000 * 1e6); // 5k USDT
        console.log("Minted 5,000 USDC and 5,000 USDT to deployer");
        
        // Approve tokens for testing - pools need approvals for liquidity operations
        usdc.approve(address(zircuitVault), 1000 * 1e6);  // Vault needs USDC approval
        usdt.approve(address(zuitPool), 1000 * 1e6);      // Pool needs USDT approval for LP
        usdc.approve(address(zuitPool), 1000 * 1e6);      // Pool needs USDC approval for LP
        console.log("Approved tokens for vault and liquidity operations");
        
        vm.stopBroadcast();
        
        // Log deployment info
        console.log("\n===== ZIRCUIT CHAIN DEPLOYMENT =====");
        console.log("Chain ID:", block.chainid);
        console.log("Deployer:", deployer);
        console.log("\n--- Core Contracts ---");
        console.log("ZircuitChildVault:", address(zircuitVault));
        console.log("\n--- Mock Infrastructure ---");
        console.log("USDC:", address(usdc));
        console.log("USDT:", address(usdt));
        console.log("Zuit AMM Pool:", address(zuitPool));
        console.log("Zuit AMM Router:", address(zuitRouter));
        console.log("Hyperlane Mailbox:", address(mailbox));
        console.log("\n--- Configuration ---");
        console.log("Slippage Tolerance: 0.5%");
        console.log("Security Limits: 1k-50k USDC");
        console.log("Test USDC Balance:", usdc.balanceOf(deployer) / 1e6, "USDC");
        console.log("Test USDT Balance:", usdt.balanceOf(deployer) / 1e6, "USDT");
        
        // Log key addresses for manual saving
        console.log("\n===== SAVE THESE ADDRESSES =====");
        console.log("export ZIRCUIT_VAULT=", address(zircuitVault));
        console.log("export ZIRCUIT_USDC=", address(usdc));
        console.log("export ZIRCUIT_USDT=", address(usdt));
        console.log("export ZIRCUIT_POOL=", address(zuitPool));
        console.log("export ZIRCUIT_ROUTER=", address(zuitRouter));
        console.log("export ZIRCUIT_MAILBOX=", address(mailbox));
    }
}