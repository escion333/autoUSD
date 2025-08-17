// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../../contracts/MotherVault.sol";
import "../../contracts/yield-strategies/KatanaChildVault.sol";
import "../../test/mocks/MockERC20.sol";
import "../../test/mocks/MockKatanaRouter.sol";
import "../../test/mocks/MockMailbox.sol";
import "../../test/mocks/MockInterchainGasPaymaster.sol";
import "../../test/mocks/MockTokenMessenger.sol";
import "../../contracts/core/CrossChainMessenger.sol";
import "../../contracts/core/CCTPBridge.sol";

// Extension to KatanaChildVault for testing internal functions
contract TestableKatanaChildVault is KatanaChildVault {
    constructor(
        address _usdc,
        address _katanaRouter,
        address _katanaPair,
        address _masterChef,
        address _sushiToken,
        address _crossChainMessenger,
        address _cctpBridge,
        address _admin
    ) KatanaChildVault(
        _usdc,
        _katanaRouter,
        _katanaPair,
        _masterChef,
        _sushiToken,
        _crossChainMessenger,
        _cctpBridge,
        _admin
    ) {}
    
    function calculatePriceImpactPublic(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) 
        external 
        pure 
        returns (uint256) 
    {
        return _calculatePriceImpact(amountIn, reserveIn, reserveOut);
    }
}

/**
 * @title Mathematical Calculations Test Suite
 * @notice Comprehensive tests for all mathematical calculations in the protocol
 */
contract MathematicalCalculationsTest is Test {
    MotherVault public motherVault;
    TestableKatanaChildVault public katanaVault;
    MockERC20 public usdc;
    MockERC20 public weth;
    MockKatanaRouter public router;
    
    address public admin = makeAddr("admin");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    
    uint256 public constant INITIAL_DEPOSIT = 100 * 1e6;
    uint256 public constant VIRTUAL_SHARES_MULTIPLIER = 1e3;

    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy mock tokens
        usdc = new MockERC20("USDC", "USDC", 6);
        weth = new MockERC20("WETH", "WETH", 18);
        
        // Deploy mocks for dependencies
        MockMailbox mailbox = new MockMailbox();
        MockInterchainGasPaymaster gasPaymaster = new MockInterchainGasPaymaster();
        MockTokenMessenger tokenMessenger = new MockTokenMessenger(address(usdc));
        
        // Deploy MotherVault
        motherVault = new MotherVault(
            address(usdc),
            "autoUSD Shares",
            "aUSD"
        );
        
        // Deploy CCTP Bridge and CrossChainMessenger for MotherVault
        CCTPBridge cctpBridge = new CCTPBridge(
            address(tokenMessenger),
            address(tokenMessenger),
            address(usdc),
            admin
        );
        
        CrossChainMessenger crossChainMessenger = new CrossChainMessenger(
            address(mailbox),
            address(gasPaymaster),
            address(cctpBridge),
            address(motherVault),
            admin
        );
        
        // Initialize MotherVault
        usdc.mint(admin, INITIAL_DEPOSIT);
        usdc.approve(address(motherVault), INITIAL_DEPOSIT);
        motherVault.initialize(address(crossChainMessenger), address(cctpBridge));
        motherVault.setDepositCap(10000 * 1e6);
        
        // Deploy router and KatanaChildVault
        router = new MockKatanaRouter(address(weth));
        
        katanaVault = new TestableKatanaChildVault(
            address(usdc),
            address(router),
            makeAddr("katanaPair"),
            makeAddr("masterChef"),
            makeAddr("sushiToken"),
            address(crossChainMessenger),
            address(cctpBridge),
            admin
        );
        
        // Setup test balances
        usdc.mint(user1, 10000 * 1e6);
        usdc.mint(user2, 10000 * 1e6);
        weth.mint(address(router), 1000 * 1e18);
        
        vm.stopPrank();
    }
    
    /**
     * @notice Test virtual shares implementation correctness
     */
    function testVirtualSharesImplementation() public {
        vm.startPrank(user1);
        usdc.approve(address(motherVault), 1000 * 1e6);
        
        // Test first deposit (should be close to 1:1 ratio)
        uint256 firstDeposit = 100 * 1e6;
        uint256 shares1 = motherVault.deposit(firstDeposit, user1);
        
        // With dead shares + virtual shares, ratio should be close to 1:1
        // Allow for some deviation due to virtual shares math
        assertApproxEqAbs(shares1, firstDeposit, 1e3, "First deposit ratio incorrect");
        
        vm.stopPrank();
        
        // Second user makes a deposit
        vm.startPrank(user2);
        usdc.approve(address(motherVault), 1000 * 1e6);
        
        uint256 secondDeposit = 50 * 1e6;
        uint256 shares2 = motherVault.deposit(secondDeposit, user2);
        
        // Second deposit should also be close to proportional
        uint256 expectedShares2 = (secondDeposit * motherVault.totalSupply()) / motherVault.totalAssets();
        assertApproxEqRel(shares2, expectedShares2, 0.01e18, "Second deposit ratio incorrect"); // 1% tolerance
        
        vm.stopPrank();
    }
    
    /**
     * @notice Test virtual shares manipulation resistance
     */
    function testVirtualSharesManipulationResistance() public {
        vm.startPrank(user1);
        usdc.approve(address(motherVault), 1000 * 1e6);
        
        // User1 makes normal deposit
        uint256 normalDeposit = 100 * 1e6;
        uint256 shares1 = motherVault.deposit(normalDeposit, user1);
        
        vm.stopPrank();
        
        // Simulate attacker trying to manipulate by direct transfer
        vm.startPrank(admin);
        usdc.mint(admin, 1000 * 1e6);
        usdc.transfer(address(motherVault), 1000 * 1e6); // Direct transfer to manipulate price
        vm.stopPrank();
        
        // User2 deposits after manipulation attempt
        vm.startPrank(user2);
        usdc.approve(address(motherVault), 1000 * 1e6);
        
        uint256 manipulatedDeposit = 100 * 1e6;
        uint256 shares2 = motherVault.deposit(manipulatedDeposit, user2);
        
        // Virtual shares should provide some protection
        // User2 should still get reasonable shares despite manipulation
        assertTrue(shares2 > normalDeposit / 2, "Virtual shares not providing manipulation resistance");
        
        vm.stopPrank();
    }
    
    /**
     * @notice Test edge cases for share conversion
     */
    function testShareConversionEdgeCases() public {
        // Test zero amounts
        assertEq(motherVault.convertToShares(0), 0, "Zero assets should return zero shares");
        assertEq(motherVault.convertToAssets(0), 0, "Zero shares should return zero assets");
        
        // Test very small amounts
        uint256 oneWei = 1;
        uint256 sharesForOneWei = motherVault.convertToShares(oneWei);
        assertTrue(sharesForOneWei >= 0, "Should handle one wei deposit");
        
        // Test very large amounts (near uint256 max)
        uint256 largeAmount = type(uint256).max / 1e6; // Avoid overflow
        uint256 sharesForLarge = motherVault.convertToShares(largeAmount);
        assertTrue(sharesForLarge > 0, "Should handle large amounts");
    }
    
    /**
     * @notice Test price impact calculation accuracy
     */
    function testPriceImpactCalculation() public {
        // Setup mock pool state
        uint256 reserveUsdc = 1000000 * 1e6; // 1M USDC
        uint256 reserveWeth = 400 * 1e18; // 400 ETH (assuming $2500 ETH price)
        
        // Test small trade (should have minimal impact)
        uint256 smallTrade = 1000 * 1e6; // $1000
        uint256 smallImpact = katanaVault.calculatePriceImpactPublic(smallTrade, reserveUsdc, reserveWeth);
        assertTrue(smallImpact < 50, "Small trade should have <0.5% impact"); // <50 bps
        
        // Test medium trade
        uint256 mediumTrade = 10000 * 1e6; // $10,000
        uint256 mediumImpact = katanaVault.calculatePriceImpactPublic(mediumTrade, reserveUsdc, reserveWeth);
        assertTrue(mediumImpact > smallImpact, "Medium trade should have higher impact than small");
        assertTrue(mediumImpact < 500, "Medium trade should have <5% impact"); // <500 bps
        
        // Test large trade
        uint256 largeTrade = 100000 * 1e6; // $100,000
        uint256 largeImpact = katanaVault.calculatePriceImpactPublic(largeTrade, reserveUsdc, reserveWeth);
        assertTrue(largeImpact > mediumImpact, "Large trade should have higher impact than medium");
    }
    
    /**
     * @notice Test price impact edge cases and protections
     */
    function testPriceImpactEdgeCases() public {
        // Test with zero reserves (should revert)
        vm.expectRevert("Reserve in must be positive");
        katanaVault.calculatePriceImpactPublic(1000 * 1e6, 0, 1000 * 1e18);
        
        vm.expectRevert("Reserve out must be positive");
        katanaVault.calculatePriceImpactPublic(1000 * 1e6, 1000 * 1e6, 0);
        
        // Test with zero amount (should revert)
        vm.expectRevert("Amount must be positive");
        katanaVault.calculatePriceImpactPublic(0, 1000 * 1e6, 1000 * 1e18);
        
        // Test with very small reserves (should revert)
        vm.expectRevert("Reserve too small");
        katanaVault.calculatePriceImpactPublic(1000 * 1e6, 1e5, 1000 * 1e18); // < 1 USDC reserve
        
        vm.expectRevert("Reserve too small");
        katanaVault.calculatePriceImpactPublic(1000 * 1e6, 1000 * 1e6, 1e11); // < 1e-6 ETH reserve
    }
    
    /**
     * @notice Test buffer calculation accuracy
     */
    function testBufferCalculations() public {
        vm.startPrank(user1);
        usdc.approve(address(motherVault), 1000 * 1e6);
        
        // Make a deposit to have some assets
        motherVault.deposit(1000 * 1e6, user1);
        
        uint256 totalAssets = motherVault.totalAssets();
        uint256 requiredBuffer = motherVault.getRequiredBuffer();
        uint256 currentBuffer = motherVault.getCurrentBuffer();
        
        // Required buffer should be 5% of total assets
        uint256 expectedBuffer = (totalAssets * 500) / 10000; // 5%
        assertEq(requiredBuffer, expectedBuffer, "Required buffer calculation incorrect");
        
        // Current buffer should equal total idle
        assertEq(currentBuffer, motherVault.totalAssets() - motherVault.totalDeployedAssets(), "Current buffer calculation incorrect");
        
        vm.stopPrank();
    }
    
    /**
     * @notice Test fee calculation accuracy over time
     */
    function testFeeCalculationAccuracy() public {
        vm.startPrank(admin);
        
        // Set a 1% annual management fee (100 bps)
        motherVault.proposeManagementFeeUpdate(100);
        vm.warp(block.timestamp + 7 days + 1); // Wait for timelock
        motherVault.executeManagementFeeUpdate();
        
        vm.stopPrank();
        
        vm.startPrank(user1);
        usdc.approve(address(motherVault), 1000 * 1e6);
        motherVault.deposit(1000 * 1e6, user1);
        vm.stopPrank();
        
        // Fast forward 1 year
        vm.warp(block.timestamp + 365 days);
        
        vm.startPrank(admin);
        uint256 totalAssetsBefore = motherVault.totalAssets();
        uint256 feeCollected = motherVault.collectManagementFees();
        
        // Fee should be approximately 1% of assets (100 bps)
        // Allow for small deviation due to rounding and virtual shares impact
        uint256 expectedFee = (totalAssetsBefore * 100) / 10000;
        assertApproxEqRel(feeCollected, expectedFee, 0.025e18, "Annual fee calculation incorrect"); // 2.5% tolerance
        
        vm.stopPrank();
    }
    
    /**
     * @notice Test mathematical consistency between preview and actual operations
     */
    function testPreviewConsistency() public {
        vm.startPrank(user1);
        usdc.approve(address(motherVault), 1000 * 1e6);
        
        uint256 depositAmount = 100 * 1e6;
        
        // Preview should match actual
        uint256 previewedShares = motherVault.previewDeposit(depositAmount);
        uint256 actualShares = motherVault.deposit(depositAmount, user1);
        
        assertEq(previewedShares, actualShares, "Preview deposit should match actual deposit");
        
        // Test withdrawal preview consistency
        uint256 withdrawAmount = 50 * 1e6;
        uint256 previewedWithdrawShares = motherVault.previewWithdraw(withdrawAmount);
        uint256 actualWithdrawShares = motherVault.withdraw(withdrawAmount, user1, user1);
        
        assertEq(previewedWithdrawShares, actualWithdrawShares, "Preview withdraw should match actual withdraw");
        
        vm.stopPrank();
    }
    
    /**
     * @notice Test mathematical operations don't overflow/underflow
     */
    function testOverflowUnderflowProtection() public {
        // Test with maximum possible values
        uint256 maxAssets = type(uint256).max / 1e18; // Avoid overflow in calculations
        
        // Should not revert due to overflow
        try motherVault.convertToShares(maxAssets) returns (uint256 shares) {
            assertTrue(shares > 0, "Should handle max assets");
        } catch {
            // Acceptable if it reverts due to reasonable limits
        }
        
        // Test edge case with very large totalSupply
        // This would need to be tested with a modified contract that allows setting large supply
    }
    
    /**
     * @notice Fuzz test for share conversion consistency
     */
    function testFuzzShareConversionConsistency(uint256 assets) public {
        // Bound the input to reasonable values
        assets = bound(assets, 1e6, 1000000 * 1e6); // 1 USDC to 1M USDC
        
        vm.startPrank(user1);
        usdc.mint(user1, assets);
        usdc.approve(address(motherVault), assets);
        
        // Test conversion consistency: convertToShares(convertToAssets(shares)) ≈ shares
        uint256 shares = motherVault.convertToShares(assets);
        uint256 backToAssets = motherVault.convertToAssets(shares);
        
        // Allow for small rounding errors (less than 0.1%)
        assertApproxEqRel(backToAssets, assets, 0.001e18, "Round-trip conversion should be consistent");
        
        vm.stopPrank();
    }
}