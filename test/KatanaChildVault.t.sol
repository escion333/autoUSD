// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {KatanaChildVault} from "../contracts/yield-strategies/KatanaChildVault.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IKatanaRouter} from "../contracts/interfaces/yield-strategies/IKatanaRouter.sol";
import {IKatanaPair} from "../contracts/interfaces/yield-strategies/IKatanaPair.sol";

// Mock Katana Router for testing purposes
contract MockKatanaRouter is IKatanaRouter {
    address private immutable _weth;
    mapping(address => mapping(address => address)) public pairs;
    mapping(address => uint256) public reservesA;
    mapping(address => uint256) public reservesB;

    constructor(address wethAddress) {
        _weth = wethAddress;
    }

    function addPair(address tokenA, address tokenB, address pair) public {
        pairs[tokenA][tokenB] = pair;
        pairs[tokenB][tokenA] = pair;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        // Simple mock: transfer 'to' some amount of the output token
        require(path.length == 2, "Invalid path");
        MockERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        
        // For USDC -> WETH swap, mint WETH
        // For WETH -> USDC swap, transfer USDC from router's balance
        uint256 amountOut = (amountIn * 99) / 100; // Simulate some slippage
        
        if (path[1] == _weth) {
            // USDC -> WETH: Mint WETH to recipient
            MockERC20(path[1]).mint(to, amountOut);
        } else {
            // WETH -> USDC: Transfer USDC from router balance
            MockERC20(path[1]).transfer(to, amountOut);
        }
        
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        address pair = pairs[tokenA][tokenB];
        MockERC20(tokenA).transferFrom(msg.sender, pair, amountADesired);
        MockERC20(tokenB).transferFrom(msg.sender, pair, amountBDesired);
        liquidity = (amountADesired + amountBDesired) / 2;
        MockERC20(pair).mint(to, liquidity);
        return (amountADesired, amountBDesired, liquidity);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB) {
        address pair = pairs[tokenA][tokenB];
        MockERC20(pair).transferFrom(msg.sender, address(this), liquidity);
        amountA = liquidity / 2;
        amountB = liquidity / 2;
        MockERC20(tokenA).mint(to, amountA);
        MockERC20(tokenB).mint(to, amountB);
        return (amountA, amountB);
    }

    function WETH() external view override returns (address) {
        return _weth; // Mainnet WETH
    }
}

// Mock Katana Pair for testing purposes
contract MockKatanaPair is MockERC20, IKatanaPair {
    address public token0;
    address public token1;
    uint112 public reserve0;
    uint112 public reserve1;

    constructor(address _token0, address _token1) MockERC20("Katana LP", "KLP", 18) {
        token0 = _token0;
        token1 = _token1;
    }

    function getReserves()
        external
        view
        returns (
            uint112 _reserve0,
            uint112 _reserve1,
            uint32 blockTimestampLast
        )
    {
        return (reserve0, reserve1, uint32(block.timestamp));
    }

    function setReserves(uint112 _reserve0, uint112 _reserve1) public {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
    }
    
    function totalSupply() public view override(ERC20, IKatanaPair) returns (uint256) {
        return super.totalSupply();
    }
}

contract KatanaChildVaultTest is Test {
    KatanaChildVault vault;
    MockERC20 usdc;
    MockERC20 weth;
    MockKatanaRouter router;
    MockKatanaPair pair;
    address admin = address(0x1);
    address messenger = address(this);
    uint256 constant INITIAL_LIQUIDITY = 10_000e6; // 10,000 USDC

    function setUp() public {
        usdc = new MockERC20("USD Coin", "USDC", 6);
        weth = new MockERC20("Wrapped Ether", "WETH", 18);
        router = new MockKatanaRouter(address(weth));
        pair = new MockKatanaPair(address(usdc), address(weth));

        router.addPair(address(usdc), address(weth), address(pair));

        vault = new KatanaChildVault(
            address(usdc),
            address(router),
            address(pair),
            address(0), // No cross-chain messenger in unit tests
            admin
        );

        // Grant roles
        vm.startPrank(admin);
        vault.grantRole(vault.MESSENGER_ROLE(), messenger);
        vm.stopPrank();

        // Mint initial USDC to this test contract
        usdc.mint(messenger, INITIAL_LIQUIDITY);
        
        // Give router some USDC for swaps (WETH -> USDC)
        usdc.mint(address(router), INITIAL_LIQUIDITY * 10);
    }

    function test_Deposit() public {
        // Transfer USDC to vault first (simulating cross-chain transfer)
        usdc.transfer(address(vault), INITIAL_LIQUIDITY);
        vault.deposit(INITIAL_LIQUIDITY);

        assertEq(vault.totalValue(), INITIAL_LIQUIDITY);
        assertTrue(MockERC20(address(pair)).balanceOf(address(vault)) > 0);
    }

    function test_Withdraw() public {
        // First, deposit
        usdc.transfer(address(vault), INITIAL_LIQUIDITY);
        vault.deposit(INITIAL_LIQUIDITY);
        
        uint256 initialVaultLpBalance = MockERC20(address(pair)).balanceOf(address(vault));
        uint256 withdrawAmount = INITIAL_LIQUIDITY / 2;

        // Now, withdraw half
        vault.withdraw(withdrawAmount);

        assertEq(vault.totalValue(), INITIAL_LIQUIDITY - withdrawAmount);
        // Check that the test contract (which is the messenger) received USDC
        // Due to slippage in swaps, we should receive slightly less than withdrawAmount
        assertTrue(usdc.balanceOf(address(this)) > 0);
        assertTrue(usdc.balanceOf(address(this)) < withdrawAmount); // Due to slippage 
    }

    function test_Harvest() public {
        usdc.transfer(address(vault), INITIAL_LIQUIDITY);
        vault.deposit(INITIAL_LIQUIDITY);

        // Simulate profit by increasing reserves significantly
        // Need reserves that make LP value > initial deposit
        // LP owns 100% of pool, so value = reserve0 * 2
        pair.setReserves(6_000e6, 6_000e18); // Increase reserves to show profit

        vm.expectEmit(true, true, true, true);
        emit KatanaChildVault.Harvested(2_000_000_000); // Profit of 2000 USDC (12B - 10B)
        vault.harvest();
        
        assertTrue(vault.totalValue() > INITIAL_LIQUIDITY);
    }

    function test_Pause() public {
        vm.prank(admin);
        vault.pause();
        
        usdc.transfer(address(vault), INITIAL_LIQUIDITY);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        vault.deposit(INITIAL_LIQUIDITY);

        vm.prank(admin);
        vault.unpause();
        vault.deposit(INITIAL_LIQUIDITY);
        assertEq(vault.totalValue(), INITIAL_LIQUIDITY);
    }

    function test_RevertWhen_UnauthorizedDeposit() public {
        usdc.transfer(address(vault), INITIAL_LIQUIDITY);
        vm.prank(address(0x2)); // Some random address
        vm.expectRevert("Caller is not the messenger");
        vault.deposit(INITIAL_LIQUIDITY);
    }
}
