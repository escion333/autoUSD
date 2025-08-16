// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {ZircuitChildVault} from "../contracts/yield-strategies/ZircuitChildVault.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockCCTPBridge} from "./mocks/MockCCTPBridge.sol";
import {MockCrossChainMessenger} from "./mocks/MockCrossChainMessenger.sol";
import {MockTokenMessenger} from "./mocks/MockTokenMessenger.sol";
import {MockMessageTransmitter} from "./mocks/MockMessageTransmitter.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IZuitRouter} from "../contracts/interfaces/yield-strategies/IZuitRouter.sol";
import {ICrossChainMessenger} from "../contracts/interfaces/ICrossChainMessenger.sol";
import {IZuitPair} from "../contracts/interfaces/yield-strategies/IZuitPair.sol";

// Mock Zuit Router for testing purposes
contract MockZuitRouter is IZuitRouter {
    mapping(address => mapping(address => address)) public pairs;

    function addPair(address tokenA, address tokenB, address pair) public {
        pairs[tokenA][tokenB] = pair;
        pairs[tokenB][tokenA] = pair;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256, // amountOutMin
        address[] calldata path,
        address to,
        uint256 // deadline
    ) external returns (uint256[] memory amounts) {
        require(path.length == 2, "Invalid path");
        // This mock doesn't handle transfers, assumes tokens are available
        
        uint256 amountOut = amountIn; 
        MockERC20(path[1]).mint(to, amountOut);
        
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;
        return amounts;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256, // amountAMin
        uint256, // amountBMin
        address to,
        uint256 // deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        address pair = pairs[tokenA][tokenB];
        // Mock transfers
        liquidity = amountADesired + amountBDesired;
        MockERC20(pair).mint(to, liquidity);
        return (amountADesired, amountBDesired, liquidity);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256, // amountAMin
        uint256, // amountBMin
        address to,
        uint256 // deadline
    ) external returns (uint256 amountA, uint256 amountB) {
        // Mock transfers
        amountA = liquidity / 2;
        amountB = liquidity / 2;
        MockERC20(tokenA).mint(to, amountA);
        MockERC20(tokenB).mint(to, amountB);
        return (amountA, amountB);
    }

    function getAmountsOut(uint256 amountIn, address[] calldata /*path*/)
        external
        pure
        override
        returns (uint256[] memory amounts)
    {
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountIn; // 1:1 swap for stablecoins
        return amounts;
    }
}

// Mock Zuit Pair for testing purposes
contract MockZuitPair is MockERC20, IZuitPair {
    address public immutable token0;
    address public immutable token1;
    uint112 public reserve0;
    uint112 public reserve1;

    constructor(address _token0, address _token1) MockERC20("Zuit LP", "ZLP", 18) {
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
    
    function totalSupply() public view override(ERC20, IZuitPair) returns (uint256) {
        return super.totalSupply();
    }
}

contract ZircuitChildVaultTest is Test {
    ZircuitChildVault vault;
    MockERC20 usdc;
    MockERC20 usdt;
    MockZuitRouter router;
    MockZuitPair pairUsdcUsdt;
    MockCCTPBridge cctpBridge;
    MockCrossChainMessenger crossChainMessenger;
    MockTokenMessenger tokenMessenger;
    MockMessageTransmitter messageTransmitter;

    address admin = address(this);
    address motherVault = address(0x200);
    uint32 motherChainDomain = 1;
    bytes32 MOTHER_VAULT_SENDER;


    uint256 constant INITIAL_DEPOSIT = 10_000e6;

    event Deposited(uint256 amount, uint256 sharesMinted);
    event Withdrawn(uint256 amount, uint256 sharesBurned);
    event ProfitReported(uint256 profit);
    event PairAdded(uint256 indexed pairId, address indexed tokenB, address indexed pairAddress);
    event EmergencyWithdrawal(uint256 usdcAmount);


    function setUp() public {
        MOTHER_VAULT_SENDER = bytes32(uint256(uint160(motherVault)));
        usdc = new MockERC20("USD Coin", "USDC", 6);
        usdt = new MockERC20("Tether", "USDT", 6);
        router = new MockZuitRouter();
        pairUsdcUsdt = new MockZuitPair(address(usdc), address(usdt));
        tokenMessenger = new MockTokenMessenger(address(usdc));
        messageTransmitter = new MockMessageTransmitter();
        crossChainMessenger = new MockCrossChainMessenger();
        cctpBridge = new MockCCTPBridge(
            address(usdc),
            address(tokenMessenger),
            address(messageTransmitter),
            address(crossChainMessenger)
        );

        router.addPair(address(usdc), address(usdt), address(pairUsdcUsdt));
        pairUsdcUsdt.setReserves(1_000_000e6, 1_000_000e6);

        vault = new ZircuitChildVault(
            address(usdc),
            address(crossChainMessenger),
            address(cctpBridge),
            admin
        );

        vault.setMotherVault(motherVault, motherChainDomain);
        vault.addPair(address(usdt), address(pairUsdcUsdt), address(router));
    }

    function test_HandleDeposit() public {
        usdc.mint(address(vault), INITIAL_DEPOSIT);
        
        bytes memory data = abi.encode(INITIAL_DEPOSIT);
        bytes memory message = abi.encode(ICrossChainMessenger.MessageType.DEPOSIT_REQUEST, data);
        
        uint256 nav = vault._calculateNav();
        uint256 totalShares = vault.totalShares();
        uint256 expectedShares = (INITIAL_DEPOSIT * totalShares) / nav;
        
        vm.prank(crossChainMessenger.getHyperlaneMailbox());
        vm.expectEmit();
        emit Deposited(INITIAL_DEPOSIT, expectedShares);
        vault.handle(motherChainDomain, MOTHER_VAULT_SENDER, message);
        
        assertGt(vault.getPairInfo(0).lpTokenBalance, 0);
    }

    function test_Withdraw() public {
        // Deposit first
        usdc.mint(address(vault), INITIAL_DEPOSIT);
        bytes memory data = abi.encode(INITIAL_DEPOSIT);
        bytes memory message = abi.encode(ICrossChainMessenger.MessageType.DEPOSIT_REQUEST, data);
        vm.prank(crossChainMessenger.getHyperlaneMailbox());
        vault.handle(motherChainDomain, MOTHER_VAULT_SENDER, message);


        uint256 withdrawAmount = INITIAL_DEPOSIT / 2;
        uint256 nav = vault._calculateNav();
        uint256 totalShares = vault.totalShares();
        uint256 sharesToBurn = (withdrawAmount * totalShares) / nav;

        vm.prank(address(crossChainMessenger));
        vm.expectEmit();
        emit Withdrawn(withdrawAmount, sharesToBurn);
        vault.withdraw(withdrawAmount);
    }

    function test_Harvest_And_ReportProfit() public {
        // Deposit first
        usdc.mint(address(vault), INITIAL_DEPOSIT);
        bytes memory data = abi.encode(INITIAL_DEPOSIT);
        bytes memory message = abi.encode(ICrossChainMessenger.MessageType.DEPOSIT_REQUEST, data);
        vm.prank(crossChainMessenger.getHyperlaneMailbox());
        vault.handle(motherChainDomain, MOTHER_VAULT_SENDER, message);
        
        // Simulate profit by adjusting reserves
        pairUsdcUsdt.setReserves(1_100_000e6, 1_100_000e6);
        
        uint256 currentNav = vault._calculateNav();
        uint256 lastNav = vault.lastHarvestNav();
        uint256 expectedProfit = currentNav > lastNav ? currentNav - lastNav : 0;

        vm.prank(address(crossChainMessenger));
        vm.expectEmit();
        emit ProfitReported(expectedProfit);
        vault.harvest();
    }
    
    function test_EmergencyWithdraw() public {
        // Deposit first
        usdc.mint(address(vault), INITIAL_DEPOSIT);
        bytes memory data = abi.encode(INITIAL_DEPOSIT);
        bytes memory message = abi.encode(ICrossChainMessenger.MessageType.DEPOSIT_REQUEST, data);
        vm.prank(crossChainMessenger.getHyperlaneMailbox());
        vault.handle(motherChainDomain, MOTHER_VAULT_SENDER, message);

        assertGt(vault.getPairInfo(0).lpTokenBalance, 0);
        
        uint256 lpBalance = vault.getPairInfo(0).lpTokenBalance;
        // Based on mock logic: removeLiquidity returns lp/2 of each token. Swap is 1:1.
        // So total USDC recovered is (lpBalance / 2) + (lpBalance / 2) = lpBalance.
        uint256 expectedUsdcAmount = lpBalance;

        vm.expectEmit();
        emit EmergencyWithdrawal(expectedUsdcAmount);
        vault.emergencyWithdraw();
        
        assertEq(vault.getPairInfo(0).lpTokenBalance, 0);
        assertGt(usdc.balanceOf(address(vault)), 0);
    }
}
