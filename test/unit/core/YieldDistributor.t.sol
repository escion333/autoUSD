// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {YieldDistributor} from "../contracts/core/YieldDistributor.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

contract YieldDistributorTest is Test {
    YieldDistributor public yieldDistributor;
    MockERC20 public usdc;

    address internal admin = makeAddr("admin");
    address internal motherVault = makeAddr("motherVault");
    address internal treasury = makeAddr("treasury");
    address internal randomAddress = makeAddr("randomAddress");

    uint256 internal constant INITIAL_MANAGEMENT_FEE_BPS = 50; // 0.5%

    function setUp() public {
        vm.startPrank(admin);
        usdc = new MockERC20("USD Coin", "USDC", 6);
        yieldDistributor = new YieldDistributor(
            address(usdc),
            motherVault,
            treasury,
            INITIAL_MANAGEMENT_FEE_BPS
        );
        vm.stopPrank();
    }

    // --- Constructor & Initialization Tests ---

    function test_Deployment_InitializesCorrectly() public {
        assertEq(address(yieldDistributor.USDC()), address(usdc));
        assertEq(yieldDistributor.motherVault(), motherVault);
        assertEq(yieldDistributor.treasury(), treasury);
        assertEq(yieldDistributor.managementFeeBps(), INITIAL_MANAGEMENT_FEE_BPS);
    }

    function test_Deployment_GrantsRolesCorrectly() public {
        assertTrue(yieldDistributor.hasRole(yieldDistributor.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(yieldDistributor.hasRole(yieldDistributor.MOTHER_VAULT_ROLE(), motherVault));
    }

    function test_Revert_WhenDeployWithZeroAddress() public {
        vm.expectRevert(
            abi.encodeWithSelector(YieldDistributor.InvalidAddress.selector, "Zero address provided")
        );
        new YieldDistributor(address(0), motherVault, treasury, INITIAL_MANAGEMENT_FEE_BPS);
    }

    function test_Revert_WhenDeployWithInvalidFee() public {
        vm.expectRevert(
            abi.encodeWithSelector(YieldDistributor.InvalidFee.selector, "Fee cannot exceed 100%")
        );
        new YieldDistributor(address(usdc), motherVault, treasury, 10001);
    }

    // --- Core Logic Tests ---

    function test_CalculateFees() public {
        uint256 grossYield = 1000e6; // 1000 USDC
        (uint256 managementFee, uint256 netYield) = yieldDistributor.calculateFees(grossYield);
        
        uint256 expectedFee = (grossYield * INITIAL_MANAGEMENT_FEE_BPS) / 10000;
        assertEq(managementFee, expectedFee, "Incorrect management fee");
        assertEq(netYield, grossYield - expectedFee, "Incorrect net yield");
    }

    function test_RecordHarvest_Permissions() public {
        vm.startPrank(randomAddress);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                randomAddress,
                yieldDistributor.MOTHER_VAULT_ROLE()
            )
        );
        yieldDistributor.recordHarvest(1000e6, 101000e6);
        vm.stopPrank();
    }

    function test_RecordHarvest_Logic() public {
        uint256 initialNav = 100_000e6;
        vm.prank(admin);
        yieldDistributor.setInitialNav(initialNav);
        
        uint256 grossYield = 1000e6;
        uint256 newTotalNav = initialNav + grossYield; 
        
        (uint256 expectedFee, uint256 expectedNetYield) = yieldDistributor.calculateFees(grossYield);

        vm.expectEmit(true, true, true, true);
        emit YieldDistributor.HarvestRecorded(block.timestamp, grossYield, expectedFee, expectedNetYield, newTotalNav);

        vm.prank(motherVault);
        yieldDistributor.recordHarvest(grossYield, newTotalNav);
        
        assertEq(yieldDistributor.lastTotalNav(), newTotalNav, "lastTotalNav not updated");
        assertEq(yieldDistributor.lastHarvestTime(), block.timestamp, "lastHarvestTime not updated");
        
        YieldDistributor.PerformanceSnapshot memory snapshot = yieldDistributor.getPerformanceSnapshot(0);
        assertEq(snapshot.timestamp, block.timestamp);
        assertEq(snapshot.grossYield, grossYield);
        assertEq(snapshot.managementFees, expectedFee);
        assertEq(snapshot.netYield, expectedNetYield);
        assertEq(snapshot.totalNav, newTotalNav);
    }

    // --- Admin Function Tests ---

    function test_SetTreasury_Permissions() public {
        vm.startPrank(randomAddress);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                randomAddress,
                yieldDistributor.DEFAULT_ADMIN_ROLE()
            )
        );
        yieldDistributor.setTreasury(makeAddr("newTreasury"));
        vm.stopPrank();
    }

    function test_SetTreasury_Logic() public {
        address newTreasury = makeAddr("newTreasury");
        vm.expectEmit(true, true, false, true);
        emit YieldDistributor.TreasuryUpdated(newTreasury);
        
        vm.prank(admin);
        yieldDistributor.setTreasury(newTreasury);
        
        assertEq(yieldDistributor.treasury(), newTreasury);
    }

    function test_SetTreasury_Revert_ZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(YieldDistributor.InvalidAddress.selector, "Cannot set treasury to zero address")
        );
        yieldDistributor.setTreasury(address(0));
    }

    function test_SetManagementFee_Permissions() public {
        vm.startPrank(randomAddress);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                randomAddress,
                yieldDistributor.DEFAULT_ADMIN_ROLE()
            )
        );
        yieldDistributor.setManagementFee(100);
        vm.stopPrank();
    }

    function test_SetManagementFee_Logic() public {
        uint256 newFeeBps = 100; // 1%
        vm.expectEmit(true, true, false, true);
        emit YieldDistributor.ManagementFeeUpdated(newFeeBps);
        
        vm.prank(admin);
        yieldDistributor.setManagementFee(newFeeBps);
        
        assertEq(yieldDistributor.managementFeeBps(), newFeeBps);
    }
    
    function test_SetManagementFee_Revert_TooHigh() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(YieldDistributor.InvalidFee.selector, "Fee cannot exceed 100%")
        );
        yieldDistributor.setManagementFee(10001);
    }

    function test_SetInitialNav() public {
        uint256 initialNav = 1_000_000e6;
        
        vm.prank(admin);
        yieldDistributor.setInitialNav(initialNav);
        
        assertEq(yieldDistributor.lastTotalNav(), initialNav);
    }
    
    function test_Revert_When_SetInitialNavTwice() public {
        vm.prank(admin);
        yieldDistributor.setInitialNav(1_000_000e6);
        
        vm.prank(admin);
        vm.expectRevert("Initial NAV already set");
        yieldDistributor.setInitialNav(2_000_000e6);
    }

    // --- Fuzz Tests ---

    function test_Fuzz_CalculateFees(uint96 _grossYield) public {
        uint256 grossYield = uint256(_grossYield);
        (uint256 managementFee, uint256 netYield) = yieldDistributor.calculateFees(grossYield);
        
        uint256 expectedFee = (grossYield * yieldDistributor.managementFeeBps()) / 10000;
        
        assertEq(managementFee, expectedFee, "Fuzz: Incorrect management fee");
        assertEq(netYield, grossYield - expectedFee, "Fuzz: Incorrect net yield");
        assertTrue(managementFee + netYield == grossYield, "Fuzz: Sum mismatch");
    }
}
