// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {MotherVault} from "../contracts/MotherVault.sol";
import {IMotherVault} from "../contracts/interfaces/IMotherVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ICrossChainMessenger} from "../contracts/interfaces/ICrossChainMessenger.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {}
    
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
    
    function handle(uint32 origin, bytes32 sender, bytes calldata message) external payable {}
    
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
    uint256 constant DEPOSIT_CAP = 10000 * ONE_USDC;

    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);
    
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
            abi.encodeWithSelector(
                IMotherVault.DepositExceedsCap.selector,
                exceedingAmount,
                availableDeposit
            )
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
        uint256 expectedFee = (vault.totalAssets() * 50) / 10000;
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
        withdrawAmount = bound(withdrawAmount, 1, depositAmount);
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
        _deployAssetsToChild(1, childVault, deployAmount);
        uint256 expectedMaxWithdraw = totalIdleBefore - deployAmount;
        assertEq(vault.maxWithdraw(alice), expectedMaxWithdraw);
    }
    
    function test_WithdrawBoundary_EqualToMax() public {
        uint256 depositAmount = 2000 * ONE_USDC;
        uint256 deployAmount = 1500 * ONE_USDC;
        vm.prank(alice);
        vault.deposit(depositAmount, alice);
        _deployAssetsToChild(1, address(0xABC), deployAmount);
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
        _deployAssetsToChild(1, address(0xABC), deployAmount);
        uint256 maxWithdraw = vault.maxWithdraw(alice);
        uint256 withdrawAmount = maxWithdraw + 1;
        vm.startPrank(alice);
        vm.expectRevert("Exceeds max");
        vault.withdraw(withdrawAmount, alice, alice);
        vm.stopPrank();
    }

    function test_AccessControl_OnlyManager() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", alice, vault.MANAGER_ROLE()));
        vault.addChildVault(1, address(0x456));
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", alice, vault.MANAGER_ROLE()));
        vault.removeChildVault(1);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", alice, vault.MANAGER_ROLE()));
        vault.deployToChildVault(1, 100 * ONE_USDC);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", alice, vault.MANAGER_ROLE()));
        vault.setDepositCap(20000 * ONE_USDC);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", alice, vault.MANAGER_ROLE()));
        vault.setManagementFee(100);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", alice, vault.MANAGER_ROLE()));
        vault.setRebalanceCooldown(12 hours);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", alice, vault.MANAGER_ROLE()));
        vault.setMinAPYDifferential(1000);
        vm.stopPrank();
    }
    
    function test_AddChildVault_AlreadyExists() public {
        vault.addChildVault(1, address(0xABC));
        vm.expectRevert("Vault already exists");
        vault.addChildVault(1, address(0xDEF));
    }

    function test_DeployToChild_InsufficientIdle() public {
        vault.addChildVault(1, address(0xABC));
        uint256 idleFunds = usdc.balanceOf(address(vault));
        uint256 deployAmount = idleFunds + 1;
        vm.expectRevert("Insufficient idle funds");
        vault.deployToChildVault(1, deployAmount);
    }
    
    function test_Initialize_AlreadyInitialized() public {
        vm.expectRevert("Already initialized");
        vault.initialize(address(messenger), address(0x1234));
    }

    function test_SetManagementFee_TooHigh() public {
        uint256 invalidFee = 1001;
        vm.expectRevert("Fee too high");
        vault.setManagementFee(invalidFee);
    }
}
