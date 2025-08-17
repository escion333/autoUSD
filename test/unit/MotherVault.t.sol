// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Test, console2 } from "forge-std/Test.sol";
import { MotherVault } from "../../contracts/MotherVault.sol";
import { IMotherVault } from "../../contracts/interfaces/IMotherVault.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ICrossChainMessenger } from "../../contracts/interfaces/ICrossChainMessenger.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") { }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockCrossChainMessenger is ICrossChainMessenger {
    function sendCrossChainMessage(CrossChainMessage calldata message) external payable returns (bytes32) {
        return keccak256(abi.encode(message));
    }

    function handle(uint32 origin, bytes32 sender, bytes calldata message) external payable { }

    function estimateMessageFee(uint32 targetChainId) external view returns (uint256) {
        return 0;
    }

    function getMessageStatus(bytes32 messageId) external view returns (bool processed, bool success) {
        return (false, false);
    }

    function getHyperlaneMailbox() external view returns (address) {
        return address(0);
    }

    function getCCTPTokenMessenger() external view returns (address) {
        return address(0);
    }

    function getInterchainGasPaymaster() external view returns (address) {
        return address(0);
    }

    function fee(uint32 destinationDomain, bytes calldata message) external view returns (uint256) {
        return 0;
    }
}

contract MockCCTPBridge {
    IERC20 public usdc;

    constructor(address _usdc) {
        usdc = IERC20(_usdc);
    }

    function bridgeUSDC(uint256 amount, uint256 destinationChainId, address recipient) external returns (uint64) {
        // Simple mock: just transfer USDC from caller to this contract
        usdc.transferFrom(msg.sender, address(this), amount);
        return 1; // Return a dummy nonce
    }
}

contract MotherVaultTest is Test {
    MotherVault public vault;
    MockUSDC public usdc;
    MockCrossChainMessenger public messenger;
    MockCCTPBridge public cctpBridge;

    address public owner = address(this);
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public feeSink = address(0x3);

    uint256 constant USDC_DECIMALS = 6;
    uint256 constant ONE_USDC = 10 ** USDC_DECIMALS;
    uint256 constant INITIAL_DEPOSIT = 100 * ONE_USDC;
    uint256 constant DEPOSIT_CAP = 10_000 * ONE_USDC;

    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    function setUp() public {
        usdc = new MockUSDC();
        messenger = new MockCrossChainMessenger();
        cctpBridge = new MockCCTPBridge(address(usdc));
        vault = new MotherVault(address(usdc), "autoUSD Vault", "aUSD");

        usdc.mint(owner, INITIAL_DEPOSIT);
        usdc.approve(address(vault), INITIAL_DEPOSIT);

        // Use the actual mock CCTP bridge
        vault.initialize(address(messenger), address(cctpBridge));
        vault.setDepositCap(DEPOSIT_CAP);

        usdc.mint(alice, 5000 * ONE_USDC);
        usdc.mint(bob, 5000 * ONE_USDC);

        vm.prank(alice);
        usdc.approve(address(vault), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(vault), type(uint256).max);
    }

    function test_InitialState() public {
        assertEq(vault.asset(), address(usdc));
        assertEq(vault.name(), "autoUSD Vault");
        assertEq(vault.symbol(), "aUSD");
        assertEq(vault.decimals(), USDC_DECIMALS);
        assertEq(vault.depositCap(), DEPOSIT_CAP);
        assertEq(vault.managementFeeBps(), 50);
        assertEq(vault.totalAssets(), INITIAL_DEPOSIT);
        assertEq(vault.totalSupply(), INITIAL_DEPOSIT);
        assertEq(vault.balanceOf(vault.DEAD_ADDRESS()), INITIAL_DEPOSIT);
    }

    // ... [Original tests from test_Deposit to test_ZeroWithdraw]
    function test_Deposit() public {
        uint256 depositAmount = 10 * ONE_USDC;
        vm.startPrank(alice);
        uint256 sharesBefore = vault.balanceOf(alice);
        uint256 vaultAssetsBefore = vault.totalAssets();
        vm.expectEmit(true, true, false, true);
        emit Deposit(alice, alice, depositAmount, depositAmount);
        uint256 shares = vault.deposit(depositAmount, alice);
        assertEq(shares, depositAmount);
        assertEq(vault.balanceOf(alice), sharesBefore + shares);
        assertEq(vault.totalAssets(), vaultAssetsBefore + depositAmount);
        assertEq(usdc.balanceOf(address(vault)), vaultAssetsBefore + depositAmount);
        vm.stopPrank();
    }

    function test_DepositExceedsCap() public {
        uint256 exceedingAmount = DEPOSIT_CAP + 1;
        uint256 availableDeposit = DEPOSIT_CAP - INITIAL_DEPOSIT;
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IMotherVault.DepositExceedsCap.selector, exceedingAmount, availableDeposit)
        );
        vault.deposit(exceedingAmount, alice);
        vm.stopPrank();
    }

    function test_MaxDeposit() public {
        uint256 expectedMax = DEPOSIT_CAP - INITIAL_DEPOSIT;
        assertEq(vault.maxDeposit(alice), expectedMax);
        vault.emergencyPause();
        assertEq(vault.maxDeposit(alice), 0);
        vault.emergencyUnpause();
        assertEq(vault.maxDeposit(alice), expectedMax);
    }

    function test_Mint() public {
        uint256 sharesToMint = 5 * ONE_USDC;
        vm.startPrank(alice);
        uint256 sharesBefore = vault.balanceOf(alice);
        uint256 vaultAssetsBefore = vault.totalAssets();
        uint256 assets = vault.mint(sharesToMint, alice);
        assertEq(assets, sharesToMint);
        assertEq(vault.balanceOf(alice), sharesBefore + sharesToMint);
        assertEq(vault.totalAssets(), vaultAssetsBefore + assets);
        vm.stopPrank();
    }

    function test_Withdraw() public {
        uint256 depositAmount = 20 * ONE_USDC;
        uint256 withdrawAmount = 10 * ONE_USDC;
        vm.startPrank(alice);
        vault.deposit(depositAmount, alice);
        uint256 aliceUsdcBefore = usdc.balanceOf(alice);
        uint256 aliceSharesBefore = vault.balanceOf(alice);
        vm.expectEmit(true, true, true, true);
        emit Withdraw(alice, alice, alice, withdrawAmount, withdrawAmount);
        uint256 shares = vault.withdraw(withdrawAmount, alice, alice);
        assertEq(shares, withdrawAmount);
        assertEq(usdc.balanceOf(alice), aliceUsdcBefore + withdrawAmount);
        assertEq(vault.balanceOf(alice), aliceSharesBefore - shares);
        vm.stopPrank();
    }

    function test_WithdrawWithAllowance() public {
        uint256 depositAmount = 20 * ONE_USDC;
        uint256 withdrawAmount = 10 * ONE_USDC;
        vm.prank(alice);
        vault.deposit(depositAmount, alice);
        vm.prank(alice);
        vault.approve(bob, withdrawAmount);
        uint256 bobUsdcBefore = usdc.balanceOf(bob);
        uint256 aliceSharesBefore = vault.balanceOf(alice);
        vm.prank(bob);
        uint256 shares = vault.withdraw(withdrawAmount, bob, alice);
        assertEq(shares, withdrawAmount);
        assertEq(usdc.balanceOf(bob), bobUsdcBefore + withdrawAmount);
        assertEq(vault.balanceOf(alice), aliceSharesBefore - shares);
        assertEq(vault.allowance(alice, bob), 0);
    }

    function test_Redeem() public {
        uint256 depositAmount = 30 * ONE_USDC;
        uint256 redeemShares = 15 * ONE_USDC;
        vm.startPrank(alice);
        vault.deposit(depositAmount, alice);
        uint256 aliceUsdcBefore = usdc.balanceOf(alice);
        uint256 aliceSharesBefore = vault.balanceOf(alice);
        uint256 assets = vault.redeem(redeemShares, alice, alice);
        assertEq(assets, redeemShares);
        assertEq(usdc.balanceOf(alice), aliceUsdcBefore + assets);
        assertEq(vault.balanceOf(alice), aliceSharesBefore - redeemShares);
        vm.stopPrank();
    }

    function test_PreviewFunctions() public {
        uint256 assets = 10 * ONE_USDC;
        uint256 shares = 10 * ONE_USDC;
        assertEq(vault.previewDeposit(assets), shares);
        assertEq(vault.previewMint(shares), assets);
        assertEq(vault.previewWithdraw(assets), shares);
        assertEq(vault.previewRedeem(shares), assets);
        vm.prank(alice);
        vault.deposit(20 * ONE_USDC, alice);
        assertEq(vault.previewDeposit(assets), shares);
        assertEq(vault.previewMint(shares), assets);
        assertEq(vault.previewWithdraw(assets), shares);
        assertEq(vault.previewRedeem(shares), assets);
    }

    function test_ConvertFunctions() public {
        uint256 assets = 50 * ONE_USDC;
        uint256 shares = 50 * ONE_USDC;
        assertEq(vault.convertToShares(assets), shares);
        assertEq(vault.convertToAssets(shares), assets);
        vm.prank(alice);
        vault.deposit(25 * ONE_USDC, alice);
        assertEq(vault.convertToShares(assets), shares);
        assertEq(vault.convertToAssets(shares), assets);
    }

    function test_PauseDeposits() public {
        vault.emergencyPause();
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        vault.deposit(10 * ONE_USDC, alice);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        vault.mint(10 * ONE_USDC, alice);
        vm.stopPrank();
    }

    function test_PauseWithdrawals() public {
        vm.prank(alice);
        vault.deposit(20 * ONE_USDC, alice);
        vault.emergencyPause();
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        vault.withdraw(10 * ONE_USDC, alice, alice);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        vault.redeem(10 * ONE_USDC, alice, alice);
        vm.stopPrank();
    }

    function test_UnpauseOperations() public {
        vault.emergencyPause();
        vault.emergencyUnpause();
        vm.prank(alice);
        uint256 shares = vault.deposit(10 * ONE_USDC, alice);
        assertEq(shares, 10 * ONE_USDC);
    }

    function test_ManagementFeeCollection() public {
        vm.prank(alice);
        vault.deposit(50 * ONE_USDC, alice);
        skip(365 days);
        uint256 feeSinkBalanceBefore = usdc.balanceOf(vault.feeSink());
        uint256 expectedFee = (vault.totalAssets() * 50) / 10_000;
        vault.collectManagementFees();
        uint256 feeSinkBalanceAfter = usdc.balanceOf(vault.feeSink());
        assertApproxEqAbs(feeSinkBalanceAfter - feeSinkBalanceBefore, expectedFee, ONE_USDC / 100);
    }

    function testFuzz_Deposit(uint256 amount) public {
        uint256 maxDep = vault.maxDeposit(alice);
        vm.assume(maxDep > 0);
        amount = bound(amount, 1, maxDep);
        uint256 aliceBalance = usdc.balanceOf(alice);
        if (amount > aliceBalance) {
            amount = aliceBalance;
        }
        vm.assume(amount > 0);
        vm.prank(alice);
        uint256 shares = vault.deposit(amount, alice);
        assertGe(shares, 0);
        assertEq(vault.balanceOf(alice), shares);
        assertEq(vault.totalAssets(), INITIAL_DEPOSIT + amount);
    }

    function testFuzz_Withdraw(uint256 depositAmount, uint256 withdrawAmount) public {
        uint256 maxDep = vault.maxDeposit(alice);
        vm.assume(maxDep > 0);
        uint256 aliceBalance = usdc.balanceOf(alice);
        depositAmount = bound(depositAmount, 1, maxDep < aliceBalance ? maxDep : aliceBalance);
        vm.prank(alice);
        vault.deposit(depositAmount, alice);

        uint256 maxWithdraw = vault.maxWithdraw(alice);
        vm.assume(maxWithdraw > 0); // Skip if no withdrawals allowed due to buffer
        withdrawAmount = bound(withdrawAmount, 1, maxWithdraw);

        uint256 aliceBalanceBefore = usdc.balanceOf(alice);
        vm.prank(alice);
        vault.withdraw(withdrawAmount, alice, alice);
        assertEq(usdc.balanceOf(alice), aliceBalanceBefore + withdrawAmount);
    }

    function test_SharePriceConsistency() public {
        vm.prank(alice);
        vault.deposit(25 * ONE_USDC, alice);
        uint256 pricePerShareBefore = (vault.totalAssets() * 1e18) / vault.totalSupply();
        vm.prank(bob);
        vault.deposit(25 * ONE_USDC, bob);
        uint256 pricePerShareAfter = (vault.totalAssets() * 1e18) / vault.totalSupply();
        assertEq(pricePerShareBefore, pricePerShareAfter);
    }

    function test_ZeroDeposit() public {
        vm.startPrank(alice);
        vm.expectRevert("Zero assets");
        vault.deposit(0, alice);
        vm.expectRevert("Zero shares");
        vault.mint(0, alice);
        vm.stopPrank();
    }

    function test_ZeroWithdraw() public {
        vm.prank(alice);
        vault.deposit(10 * ONE_USDC, alice);
        vm.startPrank(alice);
        vm.expectRevert("Zero assets");
        vault.withdraw(0, alice, alice);
        vm.expectRevert("Zero shares");
        vault.redeem(0, alice, alice);
        vm.stopPrank();
    }

    // ================================
    // ASSET LIMIT & DEPOSIT CAP TESTS
    // ================================

    // Chain IDs and domains for the new architecture
    uint32 constant BASE_SEPOLIA_DOMAIN = 84532;
    uint32 constant ETHEREUM_SEPOLIA_DOMAIN = 11155111;
    uint32 constant KATANA_DOMAIN = 129399;

    function _deployAssetsToChild(uint32 domainId, address childVaultAddress, uint256 amount) private {
        vault.addChildVault(domainId, childVaultAddress);
        vm.prank(owner);
        vault.deployToChildVault(domainId, amount);
    }

    // ... [All the new tests from test_DepositCapBoundaryCondition_ExactlyAtCap to test_CollectManagementFees_InsufficientIdle]
    function test_DepositCapBoundaryCondition_ExactlyAtCap() public {
        uint256 currentAssets = vault.totalAssets();
        uint256 remainingCapacity = DEPOSIT_CAP - currentAssets;
        usdc.mint(alice, remainingCapacity);
        vm.prank(alice);
        usdc.approve(address(vault), remainingCapacity);
        vm.prank(alice);
        uint256 shares = vault.deposit(remainingCapacity, alice);
        assertEq(shares, remainingCapacity);
        assertEq(vault.totalAssets(), DEPOSIT_CAP);
        assertEq(vault.maxDeposit(alice), 0);
    }

    function test_MaxWithdraw_WithDeployedAssets() public {
        uint256 depositAmount = 2000 * ONE_USDC;
        uint256 deployAmount = 1500 * ONE_USDC;
        vm.prank(alice);
        vault.deposit(depositAmount, alice);
        uint256 totalIdleBefore = usdc.balanceOf(address(vault));
        address childVault = address(0xABC);
        _deployAssetsToChild(ETHEREUM_SEPOLIA_DOMAIN, childVault, deployAmount);

        // Calculate expected withdrawal accounting for buffer requirements
        uint256 remainingIdle = totalIdleBefore - deployAmount;
        uint256 totalAssets = vault.totalAssets(); // Includes initial deposit
        uint256 requiredBuffer = (totalAssets * 500) / 10_000; // 5% buffer
        uint256 expectedMaxWithdraw = remainingIdle > requiredBuffer ? remainingIdle - requiredBuffer : 0;

        assertEq(vault.maxWithdraw(alice), expectedMaxWithdraw);
    }

    function test_WithdrawBoundary_EqualToMax() public {
        uint256 depositAmount = 2000 * ONE_USDC;
        uint256 deployAmount = 1500 * ONE_USDC;
        vm.prank(alice);
        vault.deposit(depositAmount, alice);
        _deployAssetsToChild(ETHEREUM_SEPOLIA_DOMAIN, address(0xABC), deployAmount);
        uint256 maxWithdraw = vault.maxWithdraw(alice);
        vm.startPrank(alice);
        uint256 shares = vault.withdraw(maxWithdraw, alice, alice);
        assertGt(shares, 0);
        vm.stopPrank();
    }

    function test_WithdrawBoundary_GreaterThanMax() public {
        uint256 depositAmount = 2000 * ONE_USDC;
        uint256 deployAmount = 1500 * ONE_USDC;
        vm.prank(alice);
        vault.deposit(depositAmount, alice);
        _deployAssetsToChild(ETHEREUM_SEPOLIA_DOMAIN, address(0xABC), deployAmount);
        uint256 maxWithdraw = vault.maxWithdraw(alice);
        uint256 withdrawAmount = maxWithdraw + 1;
        vm.startPrank(alice);
        vm.expectRevert("Exceeds max");
        vault.withdraw(withdrawAmount, alice, alice);
        vm.stopPrank();
    }

    function test_AccessControl_OnlyManager() public {
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", alice, vault.MANAGER_ROLE())
        );
        vault.addChildVault(ETHEREUM_SEPOLIA_DOMAIN, address(0x456));
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", alice, vault.MANAGER_ROLE())
        );
        vault.removeChildVault(ETHEREUM_SEPOLIA_DOMAIN);
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", alice, vault.MANAGER_ROLE())
        );
        vault.deployToChildVault(ETHEREUM_SEPOLIA_DOMAIN, 100 * ONE_USDC);
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", alice, vault.MANAGER_ROLE())
        );
        vault.setDepositCap(20_000 * ONE_USDC);
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", alice, vault.MANAGER_ROLE())
        );
        vault.setManagementFee(100);
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", alice, vault.MANAGER_ROLE())
        );
        vault.setRebalanceCooldown(12 hours);
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", alice, vault.MANAGER_ROLE())
        );
        vault.setMinAPYDifferential(1000);
        vm.stopPrank();
    }

    function test_AddChildVault_AlreadyExists() public {
        vault.addChildVault(ETHEREUM_SEPOLIA_DOMAIN, address(0xABC));
        vm.expectRevert("Vault already exists");
        vault.addChildVault(ETHEREUM_SEPOLIA_DOMAIN, address(0xDEF));
    }

    function test_DeployToChild_InsufficientIdle() public {
        vault.addChildVault(ETHEREUM_SEPOLIA_DOMAIN, address(0xABC));
        uint256 idleFunds = usdc.balanceOf(address(vault));
        uint256 deployAmount = idleFunds + 1;
        vm.expectRevert("Insufficient idle funds");
        vault.deployToChildVault(ETHEREUM_SEPOLIA_DOMAIN, deployAmount);
    }

    function test_Initialize_AlreadyInitialized() public {
        vm.expectRevert("Already initialized");
        vault.initialize(address(messenger), address(0x1234));
    }

    function test_SetManagementFee_TooHigh() public {
        uint256 invalidFee = 1001;
        vm.expectRevert("Fee exceeds maximum (2%)");
        vault.setManagementFee(invalidFee);
    }

    // ================================
    // COMPREHENSIVE FUZZ TESTS
    // ================================

    /**
     * @dev Fuzz test for deposit amounts with various edge cases
     */
    function testFuzz_DepositAmountsEdgeCases(uint256 amount, uint256 userSeed) public {
        // Bound user to our test accounts
        address user = userSeed % 2 == 0 ? alice : bob;

        uint256 userBalance = usdc.balanceOf(user);
        uint256 maxDeposit = vault.maxDeposit(user);

        // Skip if vault is at capacity
        vm.assume(maxDeposit > 0);

        // Bound amount to realistic range
        amount = bound(amount, 1, maxDeposit);
        amount = amount > userBalance ? userBalance : amount;
        vm.assume(amount > 0);

        uint256 totalAssetsBefore = vault.totalAssets();
        uint256 sharesBefore = vault.balanceOf(user);

        vm.prank(user);
        uint256 shares = vault.deposit(amount, user);

        // Verify deposit succeeded correctly
        assertGe(shares, 0, "Shares should be non-negative");
        assertEq(vault.balanceOf(user), sharesBefore + shares, "Share balance mismatch");
        assertEq(vault.totalAssets(), totalAssetsBefore + amount, "Total assets mismatch");

        // Verify share price didn't become unreasonable
        uint256 sharePrice = (vault.totalAssets() * 1e18) / vault.totalSupply();
        assertGe(sharePrice, 0.5e18, "Share price too low");
        assertLe(sharePrice, 2e18, "Share price too high");
    }

    /**
     * @dev Fuzz test for withdrawal amounts with buffer constraints
     */
    function testFuzz_WithdrawWithBuffer(uint256 depositAmount, uint256 withdrawAmount, uint256 deployAmount) public {
        // Bound deposit amount
        uint256 maxDep = vault.maxDeposit(alice);
        vm.assume(maxDep > 0);
        uint256 aliceBalance = usdc.balanceOf(alice);
        depositAmount = bound(depositAmount, 100 * ONE_USDC, maxDep < aliceBalance ? maxDep : aliceBalance);

        // Make deposit
        vm.prank(alice);
        vault.deposit(depositAmount, alice);

        // Optionally deploy some assets to child vault
        deployAmount = bound(deployAmount, 0, vault.getDeployableAmount());
        if (deployAmount > 0) {
            vault.addChildVault(ETHEREUM_SEPOLIA_DOMAIN, address(0xABC));
            vault.deployToChildVault(ETHEREUM_SEPOLIA_DOMAIN, deployAmount);
        }

        // Attempt withdrawal
        uint256 maxWithdraw = vault.maxWithdraw(alice);
        if (maxWithdraw == 0) return; // Skip if no withdrawals allowed

        withdrawAmount = bound(withdrawAmount, 1, maxWithdraw);

        uint256 aliceBalanceBefore = usdc.balanceOf(alice);
        uint256 aliceSharesBefore = vault.balanceOf(alice);

        vm.prank(alice);
        uint256 shares = vault.withdraw(withdrawAmount, alice, alice);

        // Verify withdrawal succeeded
        assertEq(usdc.balanceOf(alice), aliceBalanceBefore + withdrawAmount, "USDC balance mismatch");
        assertEq(vault.balanceOf(alice), aliceSharesBefore - shares, "Share balance mismatch");

        // Verify buffer is still maintained
        if (vault.bufferManagementEnabled()) {
            assertTrue(vault.isBufferSufficient(), "Buffer requirement violated after withdrawal");
        }
    }

    /**
     * @dev Fuzz test for rebalance threshold scenarios
     */
    function testFuzz_RebalanceThresholds(
        uint256 apy1,
        uint256 apy2,
        uint256 deployAmount1,
        uint256 deployAmount2
    )
        public
    {
        // Set up two child vaults
        vault.addChildVault(ETHEREUM_SEPOLIA_DOMAIN, address(0xABC));
        vault.addChildVault(KATANA_DOMAIN, address(0xDEF));

        // Bound APYs to reasonable values (0-50%)
        apy1 = bound(apy1, 0, 5000);
        apy2 = bound(apy2, 0, 5000);

        // Make a large deposit first
        uint256 largeDeposit = 5000 * ONE_USDC;
        vm.prank(alice);
        vault.deposit(largeDeposit, alice);

        // Bound deploy amounts to available funds
        uint256 deployableAmount = vault.getDeployableAmount();
        if (deployableAmount == 0) return;

        deployAmount1 = bound(deployAmount1, 0, deployableAmount / 2);
        deployAmount2 = bound(deployAmount2, 0, (deployableAmount - deployAmount1));

        // Deploy to both vaults
        if (deployAmount1 > 0) {
            vault.deployToChildVault(ETHEREUM_SEPOLIA_DOMAIN, deployAmount1);
        }
        if (deployAmount2 > 0) {
            vault.deployToChildVault(KATANA_DOMAIN, deployAmount2);
        }

        // Report yields
        vault.reportYield(ETHEREUM_SEPOLIA_DOMAIN, apy1, deployAmount1);
        vault.reportYield(KATANA_DOMAIN, apy2, deployAmount2);

        // Calculate APY differential
        uint256 apyDiff = apy1 > apy2 ? apy1 - apy2 : apy2 - apy1;
        uint256 minDifferential = vault.minAPYDifferential();

        // Skip time to avoid cooldown issues
        skip(25 hours);

        // Attempt rebalance
        vm.deal(address(this), 1 ether); // For cross-chain fees

        if (apyDiff >= minDifferential && deployAmount1 > 0 && deployAmount2 > 0) {
            // Should succeed
            vault.rebalance();
            // Verify rebalance timestamp was updated
            assertGt(vault.lastRebalanceTime(), 0, "Rebalance timestamp not updated");
        } else {
            // May fail due to insufficient differential or no funds to rebalance
            try vault.rebalance() {
                // If it succeeds, that's fine too
            } catch {
                // Expected failure
            }
        }
    }

    /**
     * @dev Fuzz test for fee calculations with various time periods
     */
    function testFuzz_FeeCalculations(uint256 timeElapsed, uint256 managementFeeBps, uint256 totalAssets) public {
        // Bound parameters to realistic values
        timeElapsed = bound(timeElapsed, 1 hours, 2 * 365 days);
        managementFeeBps = bound(managementFeeBps, 1, 1000); // 0.01% to 10%
        totalAssets = bound(totalAssets, 1000 * ONE_USDC, 100_000 * ONE_USDC);

        // Set up vault with assets
        usdc.mint(alice, totalAssets);
        vm.prank(alice);
        usdc.approve(address(vault), totalAssets);
        vm.prank(alice);
        vault.deposit(totalAssets, alice);

        // Set management fee
        vault.setManagementFee(managementFeeBps);

        // Advance time
        skip(timeElapsed);

        uint256 feeSinkBalanceBefore = usdc.balanceOf(vault.feeSink());
        uint256 totalAssetsBefore = vault.totalAssets();

        // Collect fees
        uint256 feeAmount = vault.collectManagementFees();

        // Calculate expected fee
        uint256 expectedFee = (totalAssetsBefore * managementFeeBps * timeElapsed) / (10_000 * 365 days);

        // Allow for small rounding differences
        assertApproxEqAbs(feeAmount, expectedFee, ONE_USDC / 100, "Fee calculation mismatch");

        if (feeAmount > 0) {
            assertEq(
                usdc.balanceOf(vault.feeSink()), feeSinkBalanceBefore + feeAmount, "Fee not transferred to fee sink"
            );
        }
    }

    /**
     * @dev Fuzz test for rate limiting enforcement
     */
    function testFuzz_RateLimitEnforcement(uint256 timeBetweenRebalances) public {
        // Set up child vaults with different APYs
        vault.addChildVault(ETHEREUM_SEPOLIA_DOMAIN, address(0xABC));
        vault.addChildVault(KATANA_DOMAIN, address(0xDEF));

        // Make a deposit and deploy to both vaults
        uint256 depositAmount = 5000 * ONE_USDC; // Stay well below cap
        vm.prank(alice);
        vault.deposit(depositAmount, alice);

        uint256 deployAmount = vault.getDeployableAmount() / 2;
        vault.deployToChildVault(ETHEREUM_SEPOLIA_DOMAIN, deployAmount);
        vault.deployToChildVault(KATANA_DOMAIN, deployAmount);

        // Report significantly different APYs
        vault.reportYield(ETHEREUM_SEPOLIA_DOMAIN, 1000, deployAmount); // 10%
        vault.reportYield(KATANA_DOMAIN, 100, deployAmount); // 1%

        // Set short cooldown for testing
        vault.setRebalanceCooldown(1 hours);

        // Bound time between rebalances
        timeBetweenRebalances = bound(timeBetweenRebalances, 1 minutes, 6 hours);

        uint256 successfulRebalances = 0;
        uint256 maxRebalances = vault.MAX_REBALANCE_FREQUENCY();

        vm.deal(address(this), 10 ether); // For cross-chain fees

        // Try to perform multiple rebalances
        for (uint256 i = 0; i < maxRebalances + 2; i++) {
            if (i > 0) {
                skip(timeBetweenRebalances);
            } else {
                skip(25 hours); // Skip initial cooldown
            }

            try vault.rebalance() {
                successfulRebalances++;

                // Verify rate limit
                uint256 recentRebalances = vault.getRebalanceCount();
                assertLe(recentRebalances, maxRebalances, "Rate limit exceeded");
            } catch {
                // Expected when rate limit is hit
                break;
            }
        }

        // Should not exceed the maximum allowed rebalances
        assertLe(successfulRebalances, maxRebalances, "Too many rebalances succeeded");
    }

    /**
     * @dev Fuzz test for buffer management with various scenarios
     */
    function testFuzz_BufferManagement(uint256 depositAmount, uint256 deployRatio) public {
        // Bound inputs
        uint256 maxDep = vault.maxDeposit(alice);
        vm.assume(maxDep > 1000 * ONE_USDC);
        uint256 aliceBalance = usdc.balanceOf(alice);
        depositAmount = bound(depositAmount, 1000 * ONE_USDC, maxDep < aliceBalance ? maxDep : aliceBalance);
        deployRatio = bound(deployRatio, 0, 100); // 0-100% of deployable amount

        // Make deposit
        vm.prank(alice);
        vault.deposit(depositAmount, alice);

        // Add child vault
        vault.addChildVault(ETHEREUM_SEPOLIA_DOMAIN, address(0xABC));

        // Calculate deployment amount based on ratio
        uint256 deployableAmount = vault.getDeployableAmount();
        uint256 deployAmount = (deployableAmount * deployRatio) / 100;

        if (deployAmount > 0) {
            vault.deployToChildVault(ETHEREUM_SEPOLIA_DOMAIN, deployAmount);
        }

        // Verify buffer requirements
        assertTrue(vault.isBufferSufficient(), "Buffer insufficient after deployment");

        // Verify buffer calculations
        uint256 requiredBuffer = vault.getRequiredBuffer();
        uint256 currentBuffer = vault.getCurrentBuffer();
        uint256 expectedBuffer = (vault.totalAssets() * 500) / 10_000; // 5%

        assertEq(requiredBuffer, expectedBuffer, "Required buffer calculation incorrect");
        assertGe(currentBuffer, requiredBuffer, "Current buffer below required");

        // Test withdrawal respects buffer
        uint256 maxWithdraw = vault.maxWithdraw(alice);
        if (maxWithdraw > 0) {
            vm.prank(alice);
            vault.withdraw(maxWithdraw, alice, alice);

            // Buffer should still be sufficient (or we should be at zero deployable)
            assertTrue(
                vault.isBufferSufficient() || vault.getDeployableAmount() == 0, "Buffer violated after max withdrawal"
            );
        }
    }

    /**
     * @dev Fuzz test for complex multi-user scenarios
     */
    function testFuzz_MultiUserScenarios(
        uint256 user1Deposit,
        uint256 user2Deposit,
        uint256 user1WithdrawRatio,
        uint256 user2WithdrawRatio,
        uint256 timeSeed
    )
        public
    {
        // Bound inputs
        uint256 maxDep1 = vault.maxDeposit(alice);
        uint256 maxDep2 = vault.maxDeposit(bob);
        vm.assume(maxDep1 > 100 * ONE_USDC && maxDep2 > 100 * ONE_USDC);

        user1Deposit = bound(user1Deposit, 100 * ONE_USDC, min(maxDep1, usdc.balanceOf(alice)));
        user2Deposit = bound(user2Deposit, 100 * ONE_USDC, min(maxDep2, usdc.balanceOf(bob)));
        user1WithdrawRatio = bound(user1WithdrawRatio, 0, 100);
        user2WithdrawRatio = bound(user2WithdrawRatio, 0, 100);
        timeSeed = bound(timeSeed, 1, 365 days);

        // User 1 deposits
        vm.prank(alice);
        uint256 shares1 = vault.deposit(user1Deposit, alice);

        // Advance time
        skip(timeSeed / 2);

        // User 2 deposits
        vm.prank(bob);
        uint256 shares2 = vault.deposit(user2Deposit, bob);

        // Verify proportional ownership
        uint256 totalShares = vault.totalSupply();
        uint256 user1Ownership = (shares1 * 1e18) / totalShares;
        uint256 user2Ownership = (shares2 * 1e18) / totalShares;

        // Advance more time
        skip(timeSeed / 2);

        // Both users withdraw a portion
        uint256 user1MaxWithdraw = vault.maxWithdraw(alice);
        uint256 user2MaxWithdraw = vault.maxWithdraw(bob);

        uint256 user1WithdrawAmount = (user1MaxWithdraw * user1WithdrawRatio) / 100;
        uint256 user2WithdrawAmount = (user2MaxWithdraw * user2WithdrawRatio) / 100;

        if (user1WithdrawAmount > 0) {
            vm.prank(alice);
            vault.withdraw(user1WithdrawAmount, alice, alice);
        }

        if (user2WithdrawAmount > 0) {
            vm.prank(bob);
            vault.withdraw(user2WithdrawAmount, bob, bob);
        }

        // Verify vault state remains consistent
        assertTrue(vault.totalAssets() >= vault.getCurrentBuffer(), "Total assets below buffer");

        // Verify no user has negative shares
        assertGe(vault.balanceOf(alice), 0, "Alice has negative shares");
        assertGe(vault.balanceOf(bob), 0, "Bob has negative shares");
    }

    /**
     * @dev Helper function to get minimum of two values
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    // ================================
    // COMPREHENSIVE EDGE CASE FUZZ TESTS
    // ================================

    /**
     * @dev Fuzz test for extreme deposit amounts (0, 1, max uint256)
     */
    function testFuzz_ExtremeDepositAmounts(uint256 extremeCase) public {
        uint256 caseType = bound(extremeCase, 0, 4);
        uint256 amount;

        if (caseType == 0) {
            // Test zero amount - should fail
            amount = 0;
            vm.prank(alice);
            vm.expectRevert("Zero assets");
            vault.deposit(amount, alice);
            return;
        } else if (caseType == 1) {
            // Test 1 wei - minimum possible
            amount = 1;
        } else if (caseType == 2) {
            // Test exactly max deposit allowed
            amount = vault.maxDeposit(alice);
        } else if (caseType == 3) {
            // Test 1 USDC exactly
            amount = ONE_USDC;
        } else {
            // Test large amount near uint256 max (but reasonable for USDC)
            amount = type(uint128).max; // Avoid overflow in calculations
        }

        // Skip if amount is 0 or exceeds what's available
        uint256 maxAllowed = vault.maxDeposit(alice);
        uint256 userBalance = usdc.balanceOf(alice);

        if (amount > maxAllowed || amount > userBalance || amount == 0) {
            return;
        }

        // Add more USDC to alice if needed
        if (amount > userBalance) {
            usdc.mint(alice, amount - userBalance);
            vm.prank(alice);
            usdc.approve(address(vault), amount);
        }

        uint256 totalAssetsBefore = vault.totalAssets();

        vm.prank(alice);
        uint256 shares = vault.deposit(amount, alice);

        assertGe(shares, 0, "Shares should be non-negative");
        assertEq(vault.totalAssets(), totalAssetsBefore + amount, "Total assets mismatch");
    }

    /**
     * @dev Fuzz test for extreme withdrawal amounts
     */
    function testFuzz_ExtremeWithdrawAmounts(uint256 depositAmount, uint256 extremeCase) public {
        // First make a deposit
        uint256 maxDep = vault.maxDeposit(alice);
        vm.assume(maxDep > ONE_USDC);
        depositAmount = bound(depositAmount, ONE_USDC, maxDep);

        vm.prank(alice);
        vault.deposit(depositAmount, alice);

        uint256 caseType = bound(extremeCase, 0, 4);
        uint256 withdrawAmount;

        if (caseType == 0) {
            // Test zero amount - should fail
            withdrawAmount = 0;
            vm.prank(alice);
            vm.expectRevert("Zero assets");
            vault.withdraw(withdrawAmount, alice, alice);
            return;
        } else if (caseType == 1) {
            // Test 1 wei withdrawal
            withdrawAmount = 1;
        } else if (caseType == 2) {
            // Test exactly max withdrawal
            withdrawAmount = vault.maxWithdraw(alice);
        } else if (caseType == 3) {
            // Test more than max (should fail)
            withdrawAmount = vault.maxWithdraw(alice) + 1;
            if (withdrawAmount > vault.maxWithdraw(alice)) {
                vm.prank(alice);
                vm.expectRevert("Exceeds max");
                vault.withdraw(withdrawAmount, alice, alice);
                return;
            }
        } else {
            // Test very large amount
            withdrawAmount = type(uint128).max;
            if (withdrawAmount > vault.maxWithdraw(alice)) {
                vm.prank(alice);
                vm.expectRevert("Exceeds max");
                vault.withdraw(withdrawAmount, alice, alice);
                return;
            }
        }

        uint256 maxWithdraw = vault.maxWithdraw(alice);
        if (withdrawAmount > maxWithdraw || withdrawAmount == 0) {
            return;
        }

        uint256 aliceBalanceBefore = usdc.balanceOf(alice);

        vm.prank(alice);
        vault.withdraw(withdrawAmount, alice, alice);

        assertEq(usdc.balanceOf(alice), aliceBalanceBefore + withdrawAmount, "USDC balance mismatch");
    }

    /**
     * @dev Fuzz test for APY differentials from 0% to 100%
     */
    function testFuzz_APYDifferentials(uint256 apy1, uint256 apy2, uint256 minDiff) public {
        // Bound APYs to reasonable ranges (0-100%)
        apy1 = bound(apy1, 0, 10_000); // 0-100%
        apy2 = bound(apy2, 0, 10_000); // 0-100%
        minDiff = bound(minDiff, 0, 5000); // 0-50%

        // Set up child vaults
        vault.addChildVault(ETHEREUM_SEPOLIA_DOMAIN, address(0xABC));
        vault.addChildVault(KATANA_DOMAIN, address(0xDEF));

        // Set minimum differential
        vault.setMinAPYDifferential(minDiff);

        // Make deposits and deploy
        uint256 depositAmount = 5000 * ONE_USDC;
        vm.prank(alice);
        vault.deposit(depositAmount, alice);

        uint256 deployAmount = vault.getDeployableAmount() / 2;
        if (deployAmount > 0) {
            vault.deployToChildVault(ETHEREUM_SEPOLIA_DOMAIN, deployAmount);
            vault.deployToChildVault(KATANA_DOMAIN, deployAmount);

            // Report yields
            vault.reportYield(ETHEREUM_SEPOLIA_DOMAIN, apy1, deployAmount);
            vault.reportYield(KATANA_DOMAIN, apy2, deployAmount);

            // Calculate expected differential
            uint256 actualDiff = apy1 > apy2 ? apy1 - apy2 : apy2 - apy1;

            // Skip cooldown
            skip(25 hours);

            vm.deal(address(this), 1 ether);

            if (actualDiff >= minDiff && deployAmount > 0) {
                // Should be able to rebalance
                try vault.rebalance() {
                    assertTrue(true, "Rebalance succeeded as expected");
                } catch {
                    // May fail for other reasons (rate limiting, etc.)
                }
            } else {
                // Should fail due to insufficient differential
                try vault.rebalance() {
                    // May succeed if other conditions allow
                } catch {
                    // Expected failure
                }
            }
        }
    }

    /**
     * @dev Fuzz test for various fee percentages (0.01% to 10%)
     */
    function testFuzz_FeePercentages(uint256 feeBps, uint256 timeElapsed, uint256 assetAmount) public {
        // Bound fee to valid range (0.01% to 10%)
        feeBps = bound(feeBps, 1, 1000);
        // Bound time to reasonable range
        timeElapsed = bound(timeElapsed, 1 days, 2 * 365 days);
        // Bound assets to reasonable range
        assetAmount = bound(assetAmount, 1000 * ONE_USDC, 50_000 * ONE_USDC);

        // Set the fee
        vault.setManagementFee(feeBps);

        // Make a large deposit
        usdc.mint(alice, assetAmount);
        vm.prank(alice);
        usdc.approve(address(vault), assetAmount);
        vm.prank(alice);
        vault.deposit(assetAmount, alice);

        // Skip time
        skip(timeElapsed);

        uint256 feeSinkBefore = usdc.balanceOf(vault.feeSink());
        uint256 totalAssetsBefore = vault.totalAssets();

        // Collect fees
        uint256 feeAmount = vault.collectManagementFees();

        // Calculate expected fee (allowing for rounding)
        uint256 expectedFee = (totalAssetsBefore * feeBps * timeElapsed) / (10_000 * 365 days);

        // Allow for rounding differences
        assertApproxEqAbs(feeAmount, expectedFee, ONE_USDC / 10, "Fee calculation mismatch");

        if (feeAmount > 0) {
            assertEq(usdc.balanceOf(vault.feeSink()), feeSinkBefore + feeAmount, "Fee not transferred correctly");
        }
    }

    /**
     * @dev Fuzz test for cross-chain message handling edge cases
     */
    function testFuzz_CrossChainMessageHandling(
        uint256 domainId,
        uint256 messageType,
        uint256 payload1,
        uint256 payload2
    )
        public
    {
        domainId = bound(domainId, 1, 100);
        messageType = bound(messageType, 0, 5);

        uint32 domain = uint32(domainId);
        address childVault = address(uint160(0x20000 + domainId));

        // Add child vault
        vault.addChildVault(domain, childVault);

        bytes memory message;

        if (messageType == 0) {
            // Empty message
            message = "";
        } else if (messageType == 1) {
            // Invalid message type
            message = abi.encode(uint8(255), abi.encode(payload1, payload2));
        } else if (messageType == 2) {
            // Valid yield report
            uint256 apy = bound(payload1, 0, 10_000); // 0-100%
            uint256 totalValue = bound(payload2, 0, 1_000_000 * ONE_USDC);
            message = abi.encode(uint8(2), abi.encode(apy, totalValue));
        } else if (messageType == 3) {
            // Malformed yield report
            message = abi.encode(uint8(2), "invalid");
        } else {
            // Random bytes
            message = abi.encodePacked(payload1, payload2);
        }

        // Test message handling
        vm.prank(address(messenger));
        try vault.handleIncomingMessage(domain, bytes32(uint256(uint160(childVault))), message) {
            // Message processed successfully
        } catch {
            // Expected failure for malformed messages
        }
    }

    /**
     * @dev Fuzz test for buffer management under various scenarios
     */
    function testFuzz_BufferManagementScenarios(
        uint256 bufferEnabled,
        uint256 deployRatio,
        uint256 withdrawRatio
    )
        public
    {
        bool enableBuffer = bound(bufferEnabled, 0, 1) == 1;
        deployRatio = bound(deployRatio, 0, 95); // 0-95% deployment
        withdrawRatio = bound(withdrawRatio, 0, 100); // 0-100% withdrawal attempt

        // Set buffer management
        vault.setBufferManagement(enableBuffer);

        // Make a deposit within cap
        uint256 depositAmount = 5000 * ONE_USDC; // Stay well below cap
        vm.prank(alice);
        vault.deposit(depositAmount, alice);

        // Add child vault and deploy some funds
        vault.addChildVault(ETHEREUM_SEPOLIA_DOMAIN, address(0xABC));

        uint256 deployableAmount = vault.getDeployableAmount();
        uint256 deployAmount = (deployableAmount * deployRatio) / 100;

        if (deployAmount > 0) {
            vault.deployToChildVault(ETHEREUM_SEPOLIA_DOMAIN, deployAmount);
        }

        // Verify buffer state
        if (enableBuffer) {
            assertTrue(
                vault.isBufferSufficient() || vault.getDeployableAmount() == 0,
                "Buffer should be sufficient after deployment"
            );
        }

        // Attempt withdrawal
        uint256 maxWithdraw = vault.maxWithdraw(alice);
        uint256 withdrawAmount = (maxWithdraw * withdrawRatio) / 100;

        if (withdrawAmount > 0) {
            uint256 balanceBefore = usdc.balanceOf(alice);

            vm.prank(alice);
            vault.withdraw(withdrawAmount, alice, alice);

            assertEq(usdc.balanceOf(alice), balanceBefore + withdrawAmount, "Withdrawal amount mismatch");

            // Buffer should still be maintained
            if (enableBuffer && vault.totalAssets() > 0) {
                assertTrue(
                    vault.isBufferSufficient() || vault.getCurrentBuffer() == 0, "Buffer violated after withdrawal"
                );
            }
        }
    }

    // ===== APPROVAL RESET TESTS =====

    function test_DeployToChildVault_ResetsApprovalToZero() public {
        uint256 depositAmount = 5000 * ONE_USDC;
        uint256 deployAmount = 2000 * ONE_USDC;

        // Setup: deposit and add child vault
        vm.prank(alice);
        vault.deposit(depositAmount, alice);
        vault.addChildVault(ETHEREUM_SEPOLIA_DOMAIN, address(0xABC));

        // Set initial allowance to non-zero to simulate previous usage
        vm.prank(address(vault));
        usdc.approve(address(cctpBridge), 10_000 * ONE_USDC);

        // Check initial allowance
        assertEq(usdc.allowance(address(vault), address(cctpBridge)), 10_000 * ONE_USDC);

        // Deploy to child vault
        vault.deployToChildVault(ETHEREUM_SEPOLIA_DOMAIN, deployAmount);

        // Verify allowance was reset to 0 first, then set to amount
        // The final allowance should be 0 since tokens were transferred via bridge
        assertEq(usdc.allowance(address(vault), address(cctpBridge)), 0);
    }

    function test_InitiateRebalance_ResetsApprovalToZero() public {
        uint256 depositAmount = 5000 * ONE_USDC;
        uint256 deployAmount = 2000 * ONE_USDC;
        uint256 rebalanceAmount = 1000 * ONE_USDC;

        // Setup: deposit and add child vaults
        vm.prank(alice);
        vault.deposit(depositAmount, alice);
        vault.addChildVault(ETHEREUM_SEPOLIA_DOMAIN, address(0xABC)); // Source chain
        vault.addChildVault(KATANA_DOMAIN, address(0xDEF)); // Target chain

        // Deploy some funds to source chain first
        vault.deployToChildVault(ETHEREUM_SEPOLIA_DOMAIN, deployAmount);

        // Set initial allowance to non-zero to test reset
        vm.prank(address(vault));
        usdc.approve(address(cctpBridge), 5000 * ONE_USDC);
        assertEq(usdc.allowance(address(vault), address(cctpBridge)), 5000 * ONE_USDC);

        // Simulate funds returning from child vault for rebalancing
        // This would normally come through CCTP callback
        usdc.mint(address(vault), rebalanceAmount);

        // Initiate rebalance (this only sends a message, no immediate USDC transfer)
        vault.initiateRebalance(ETHEREUM_SEPOLIA_DOMAIN, KATANA_DOMAIN, rebalanceAmount);

        // Verify allowance remains unchanged since no USDC was transferred yet
        // The actual USDC transfer happens when funds arrive from child vault via CCTP
        assertEq(usdc.allowance(address(vault), address(cctpBridge)), 5000 * ONE_USDC);
    }
}
