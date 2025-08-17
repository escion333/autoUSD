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
        usdc.transferFrom(msg.sender, address(this), amount);
        return 1;
    }
}

/**
 * @title MotherVaultExtendedTest
 * @notice Extended test suite for MotherVault covering edge cases and governance features
 */
contract MotherVaultExtendedTest is Test {
    MotherVault public vault;
    MockUSDC public usdc;
    MockCrossChainMessenger public messenger;
    MockCCTPBridge public cctpBridge;

    address public owner = address(this);
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public feeSink = address(0x3);
    address public pauser = address(0x4);
    address public manager = address(0x5);
    address public rebalancer = address(0x6);

    uint256 constant USDC_DECIMALS = 6;
    uint256 constant ONE_USDC = 10 ** USDC_DECIMALS;
    uint256 constant INITIAL_DEPOSIT = 100 * ONE_USDC;
    uint256 constant DEPOSIT_CAP = 10_000 * ONE_USDC;

    // Events
    event FeeSinkUpdated(address indexed oldSink, address indexed newSink);
    event ManagementFeeUpdated(uint256 indexed oldFee, uint256 indexed newFee);
    event FeeUpdateProposed(uint256 indexed oldFeeBps, uint256 indexed newFeeBps, uint256 indexed executeAfter);
    event FeeUpdateExecuted(uint256 indexed oldFeeBps, uint256 indexed newFeeBps, address indexed executor);
    event EmergencyPauseActivated(address indexed initiator);
    event EmergencyPauseDeactivated(address indexed initiator, uint256 indexed timestamp);
    event ChildVaultAdded(uint32 indexed domainId, address indexed vault);
    event ChildVaultRemoved(uint32 indexed domainId, address indexed vault);
    event BufferManagementToggled(bool indexed enabled);
    event HealthCheckFailed(string indexed reason, uint256 indexed timestamp, address indexed reporter);

    function setUp() public {
        usdc = new MockUSDC();
        messenger = new MockCrossChainMessenger();
        cctpBridge = new MockCCTPBridge(address(usdc));
        vault = new MotherVault(address(usdc), "autoUSD Vault", "aUSD");

        // Setup roles
        vault.grantRole(vault.PAUSER_ROLE(), pauser);
        vault.grantRole(vault.MANAGER_ROLE(), manager);
        vault.grantRole(vault.REBALANCER_ROLE(), rebalancer);

        usdc.mint(owner, INITIAL_DEPOSIT);
        usdc.approve(address(vault), INITIAL_DEPOSIT);

        vault.initialize(address(messenger), address(cctpBridge));
        vault.setDepositCap(DEPOSIT_CAP);

        // Mint tokens for other test accounts
        usdc.mint(alice, 1000 * ONE_USDC);
        usdc.mint(bob, 1000 * ONE_USDC);
    }

    // ===============================
    // Fee Governance Tests
    // ===============================

    function test_FeeGovernance_ProposeAndExecute() public {
        uint256 newFeeBps = 100; // 1%

        // Propose fee update
        vm.expectEmit(true, true, true, true);
        emit FeeUpdateProposed(vault.managementFeeBps(), newFeeBps, block.timestamp + vault.FEE_UPDATE_TIMELOCK());

        vm.prank(manager);
        vault.proposeManagementFeeUpdate(newFeeBps);

        IMotherVault.PendingFeeUpdate memory pending = vault.getPendingFeeUpdate();
        assertEq(pending.newFeeBps, newFeeBps);
        assertEq(pending.proposedAt, block.timestamp);
        assertFalse(pending.executed);

        // Try to execute before timelock
        vm.prank(manager);
        vm.expectRevert("Timelock not expired");
        vault.executeManagementFeeUpdate();

        // Wait for timelock and execute
        vm.warp(block.timestamp + vault.FEE_UPDATE_TIMELOCK());

        vm.expectEmit(true, true, true, true);
        emit FeeUpdateExecuted(vault.managementFeeBps(), newFeeBps, manager);

        vm.prank(manager);
        vault.executeManagementFeeUpdate();

        assertEq(vault.managementFeeBps(), newFeeBps);

        // Verify pending update is marked as executed
        pending = vault.getPendingFeeUpdate();
        assertTrue(pending.executed);
    }

    function test_FeeGovernance_CanExecuteCheck() public {
        uint256 newFeeBps = 100;

        vm.prank(manager);
        vault.proposeManagementFeeUpdate(newFeeBps);

        (bool canExecute, uint256 timeRemaining) = vault.canExecuteFeeUpdate();
        assertFalse(canExecute);
        assertEq(timeRemaining, vault.FEE_UPDATE_TIMELOCK());

        // Half way through timelock
        vm.warp(block.timestamp + vault.FEE_UPDATE_TIMELOCK() / 2);
        (canExecute, timeRemaining) = vault.canExecuteFeeUpdate();
        assertFalse(canExecute);
        assertEq(timeRemaining, vault.FEE_UPDATE_TIMELOCK() / 2);

        // After timelock
        vm.warp(block.timestamp + vault.FEE_UPDATE_TIMELOCK() / 2);
        (canExecute, timeRemaining) = vault.canExecuteFeeUpdate();
        assertTrue(canExecute);
        assertEq(timeRemaining, 0);
    }

    function test_FeeGovernance_NoUpdatePending() public {
        vm.prank(manager);
        vm.expectRevert("No pending update");
        vault.executeManagementFeeUpdate();
    }

    function test_FeeGovernance_UpdateAlreadyExecuted() public {
        uint256 newFeeBps = 100;

        vm.prank(manager);
        vault.proposeManagementFeeUpdate(newFeeBps);

        vm.warp(block.timestamp + vault.FEE_UPDATE_TIMELOCK());

        vm.prank(manager);
        vault.executeManagementFeeUpdate();

        // Try to execute again
        vm.prank(manager);
        vm.expectRevert("Update already executed");
        vault.executeManagementFeeUpdate();
    }

    function test_FeeGovernance_MaximumFeeExceeded() public {
        uint256 maxFee = vault.MAX_MANAGEMENT_FEE_BPS();

        vm.prank(manager);
        vm.expectRevert("Fee exceeds maximum (2%)");
        vault.proposeManagementFeeUpdate(maxFee + 1);
    }

    function test_FeeGovernance_FeeUnchanged() public {
        uint256 currentFee = vault.managementFeeBps();

        vm.prank(manager);
        vm.expectRevert("Fee unchanged");
        vault.proposeManagementFeeUpdate(currentFee);
    }

    function test_FeeGovernance_OverridePendingUpdate() public {
        uint256 firstFee = 100;
        uint256 secondFee = 150;

        // Propose first update
        vm.prank(manager);
        vault.proposeManagementFeeUpdate(firstFee);

        // Wait past timelock but don't execute
        vm.warp(block.timestamp + vault.FEE_UPDATE_TIMELOCK() + 1);

        // Propose second update (should override first)
        vm.prank(manager);
        vault.proposeManagementFeeUpdate(secondFee);

        IMotherVault.PendingFeeUpdate memory pending = vault.getPendingFeeUpdate();
        assertEq(pending.newFeeBps, secondFee);
        assertEq(pending.proposedAt, block.timestamp);
        assertFalse(pending.executed);
    }

    function test_EmergencyFeeUpdate() public {
        uint256 newFeeBps = 100;

        vm.expectEmit(true, true, false, true);
        emit ManagementFeeUpdated(vault.managementFeeBps(), newFeeBps);

        vault.setManagementFee(newFeeBps);

        assertEq(vault.managementFeeBps(), newFeeBps);
    }

    function test_EmergencyFeeUpdate_OnlyAdmin() public {
        vm.prank(alice);
        vm.expectRevert("Emergency fee update requires admin role");
        vault.setManagementFee(100);
    }

    function test_EmergencyFeeUpdate_ExceedsMax() public {
        vm.expectRevert("Fee exceeds maximum (2%)");
        vault.setManagementFee(vault.MAX_MANAGEMENT_FEE_BPS() + 1);
    }

    // ===============================
    // Emergency Functions Tests
    // ===============================

    function test_EmergencyPause() public {
        vm.expectEmit(true, false, false, true);
        emit EmergencyPauseActivated(pauser);

        vm.prank(pauser);
        vault.emergencyPause();

        assertTrue(vault.isPaused());
    }

    function test_EmergencyUnpause() public {
        vm.prank(pauser);
        vault.emergencyPause();

        vm.expectEmit(true, true, false, true);
        emit EmergencyPauseDeactivated(pauser, block.timestamp);

        vm.prank(pauser);
        vault.emergencyUnpause();

        assertFalse(vault.isPaused());
    }

    function test_EmergencyWithdrawAll_OnlyWhenPaused() public {
        vm.expectRevert("Pausable: not paused");
        vault.emergencyWithdrawAll();
    }

    function test_EmergencyWithdrawAll() public {
        uint256 depositAmount = 500 * ONE_USDC;

        // Make a deposit
        vm.startPrank(alice);
        usdc.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);
        vm.stopPrank();

        uint256 vaultBalanceBefore = usdc.balanceOf(address(vault));
        uint256 feeSinkBalanceBefore = usdc.balanceOf(feeSink);

        // Pause and emergency withdraw
        vm.prank(pauser);
        vault.emergencyPause();

        vault.emergencyWithdrawAll();

        assertEq(usdc.balanceOf(address(vault)), 0);
        assertEq(usdc.balanceOf(feeSink), feeSinkBalanceBefore + vaultBalanceBefore);
    }

    // ===============================
    // Buffer Management Tests
    // ===============================

    function test_BufferManagement_Toggle() public {
        assertTrue(vault.bufferManagementEnabled());

        vm.expectEmit(true, false, false, true);
        emit BufferManagementToggled(false);

        vm.prank(manager);
        vault.setBufferManagement(false);

        assertFalse(vault.bufferManagementEnabled());

        // When disabled, buffer functions should return appropriate values
        assertEq(vault.getRequiredBuffer(), 0);
        assertTrue(vault.isBufferSufficient());
    }

    function test_BufferManagement_RequestRefill_WhenDisabled() public {
        vm.prank(manager);
        vault.setBufferManagement(false);

        vm.prank(manager);
        vm.expectRevert("Buffer management disabled");
        vault.requestBufferRefill();
    }

    function test_BufferManagement_RequestRefill_WhenSufficient() public {
        // Buffer should be sufficient initially (no deployed assets)
        assertTrue(vault.isBufferSufficient());

        vm.prank(manager);
        vm.expectRevert("Buffer is sufficient");
        vault.requestBufferRefill();
    }

    function test_BufferManagement_RequestRefill_NoDeployedFunds() public {
        // Simulate insufficient buffer but no deployed funds
        vm.prank(manager);
        vault.setBufferManagement(false);
        vm.prank(manager);
        vault.setBufferManagement(true);

        // Deploy all funds to create buffer deficit
        uint32 domainId = 1;
        address childVault = address(0x100);
        vault.addChildVault(domainId, childVault);

        uint256 deployAmount = vault.getCurrentBuffer();
        vm.prank(manager);
        vault.deployToChildVault(domainId, deployAmount);

        // Remove deployed amount to simulate no deployed funds
        vm.store(address(vault), bytes32(uint256(49)), bytes32(uint256(0))); // _totalDeployed slot

        vm.prank(manager);
        vm.expectRevert("No deployed funds to recall");
        vault.requestBufferRefill();
    }

    // ===============================
    // Child Vault Management Tests
    // ===============================

    function test_AddChildVault_ZeroAddress() public {
        vm.expectRevert("Invalid vault address");
        vault.addChildVault(1, address(0));
    }

    function test_AddChildVault_AlreadyExists() public {
        uint32 domainId = 1;
        address childVault = address(0x100);

        vault.addChildVault(domainId, childVault);

        vm.expectRevert("Vault already exists");
        vault.addChildVault(domainId, childVault);
    }

    function test_RemoveChildVault_WithFunds() public {
        uint32 domainId = 1;
        address childVault = address(0x100);

        vault.addChildVault(domainId, childVault);

        // Deploy funds to child vault
        uint256 deployAmount = 100 * ONE_USDC;
        vm.prank(manager);
        vault.deployToChildVault(domainId, deployAmount);

        vm.expectRevert("Vault has funds");
        vault.removeChildVault(domainId);
    }

    function test_RemoveChildVault_Success() public {
        uint32 domainId = 1;
        address childVault = address(0x100);

        vault.addChildVault(domainId, childVault);

        vm.expectEmit(true, true, false, true);
        emit ChildVaultRemoved(domainId, childVault);

        vault.removeChildVault(domainId);

        IMotherVault.ChildVault memory removed = vault.getChildVault(domainId);
        assertFalse(removed.isActive);
    }

    // ===============================
    // Health Monitoring Tests
    // ===============================

    function test_HealthCheckFailure() public {
        string memory reason = "Network congestion detected";

        vm.expectEmit(true, true, true, true);
        emit HealthCheckFailed(reason, block.timestamp, manager);

        vm.prank(manager);
        vault.reportHealthCheckFailure(reason, manager);
    }

    function test_FeeGovernanceParams() public {
        (uint256 maxFeeBps, uint256 timelockPeriod) = vault.getFeeGovernanceParams();
        assertEq(maxFeeBps, vault.MAX_MANAGEMENT_FEE_BPS());
        assertEq(timelockPeriod, vault.FEE_UPDATE_TIMELOCK());
    }

    // ===============================
    // Edge Cases and Error Conditions
    // ===============================

    function test_SetFeeSink_ZeroAddress() public {
        vm.expectRevert("Invalid fee sink");
        vault.setFeeSink(address(0));
    }

    function test_SetFeeSink_Success() public {
        address newFeeSink = address(0x999);

        vm.expectEmit(true, true, false, true);
        emit FeeSinkUpdated(feeSink, newFeeSink);

        vault.setFeeSink(newFeeSink);

        assertEq(vault.feeSink(), newFeeSink);
    }

    function test_SetDepositCap() public {
        uint256 newCap = 50_000 * ONE_USDC;

        vm.prank(manager);
        vault.setDepositCap(newCap);

        assertEq(vault.depositCap(), newCap);
    }

    function test_SetRebalanceCooldown() public {
        uint256 newCooldown = 12 hours;

        vm.prank(manager);
        vault.setRebalanceCooldown(newCooldown);

        assertEq(vault.rebalanceCooldown(), newCooldown);
    }

    function test_SetMinAPYDifferential() public {
        uint256 newDifferential = 1000; // 10%

        vm.prank(manager);
        vault.setMinAPYDifferential(newDifferential);

        assertEq(vault.minAPYDifferential(), newDifferential);
    }

    function test_GetAllChildVaults() public {
        uint32 domain1 = 1;
        uint32 domain2 = 2;
        address vault1 = address(0x100);
        address vault2 = address(0x200);

        vault.addChildVault(domain1, vault1);
        vault.addChildVault(domain2, vault2);

        (uint32[] memory domainIds, IMotherVault.ChildVault[] memory vaults) = vault.getAllChildVaults();

        assertEq(domainIds.length, 2);
        assertEq(vaults.length, 2);

        // Order may vary, so check that both are present
        bool found1 = false;
        bool found2 = false;
        for (uint256 i = 0; i < domainIds.length; i++) {
            if (domainIds[i] == domain1 && vaults[i].vaultAddress == vault1) found1 = true;
            if (domainIds[i] == domain2 && vaults[i].vaultAddress == vault2) found2 = true;
        }
        assertTrue(found1 && found2);
    }

    // ===============================
    // Access Control Tests
    // ===============================

    function test_AccessControl_ManagerRole() public {
        vm.prank(alice);
        vm.expectRevert();
        vault.setDepositCap(1000 * ONE_USDC);

        vm.prank(alice);
        vm.expectRevert();
        vault.proposeManagementFeeUpdate(100);

        vm.prank(alice);
        vm.expectRevert();
        vault.setBufferManagement(false);
    }

    function test_AccessControl_PauserRole() public {
        vm.prank(alice);
        vm.expectRevert();
        vault.emergencyPause();

        vm.prank(alice);
        vm.expectRevert();
        vault.emergencyUnpause();
    }

    function test_AccessControl_AdminRole() public {
        vm.prank(alice);
        vm.expectRevert();
        vault.setFeeSink(address(0x999));

        vm.prank(alice);
        vm.expectRevert();
        vault.emergencyWithdrawAll();
    }

    // ===============================
    // Complex Scenarios
    // ===============================

    function test_ComplexScenario_FeeCollectionWithDeployments() public {
        uint256 depositAmount = 1000 * ONE_USDC;
        uint32 domainId = 1;
        address childVault = address(0x100);

        // Setup child vault and make deposit
        vault.addChildVault(domainId, childVault);

        vm.startPrank(alice);
        usdc.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);
        vm.stopPrank();

        // Deploy some funds
        uint256 deployAmount = 500 * ONE_USDC;
        vm.prank(manager);
        vault.deployToChildVault(domainId, deployAmount);

        // Fast forward time to accrue fees
        vm.warp(block.timestamp + 365 days);

        // Collect fees
        uint256 feeAmount = vault.collectManagementFees();
        assertTrue(feeAmount > 0);
    }

    function testFuzz_DepositCap_Boundary(uint256 cap) public {
        vm.assume(cap > 0 && cap <= type(uint128).max);

        vm.prank(manager);
        vault.setDepositCap(cap);

        assertEq(vault.depositCap(), cap);
        assertEq(vault.maxDeposit(alice), cap);
    }

    function testFuzz_ManagementFee_Boundary(uint256 feeBps) public {
        vm.assume(feeBps <= vault.MAX_MANAGEMENT_FEE_BPS());

        vm.prank(manager);
        vault.proposeManagementFeeUpdate(feeBps);

        vm.warp(block.timestamp + vault.FEE_UPDATE_TIMELOCK());

        vm.prank(manager);
        vault.executeManagementFeeUpdate();

        assertEq(vault.managementFeeBps(), feeBps);
    }

    function testFuzz_BufferCalculations(uint256 totalAssets) public {
        vm.assume(totalAssets > 0 && totalAssets <= type(uint128).max);

        // Mock total assets by setting idle balance
        vm.store(address(vault), bytes32(uint256(48)), bytes32(totalAssets)); // _totalIdle slot

        uint256 expectedBuffer = (totalAssets * vault.BUFFER_PERCENTAGE()) / vault.FEE_DIVISOR();
        assertEq(vault.getRequiredBuffer(), expectedBuffer);
    }
}
