// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Test, console2 } from "forge-std/Test.sol";
import { MotherVault } from "../../contracts/MotherVault.sol";
import { IMotherVault } from "../../contracts/interfaces/IMotherVault.sol";
import { CCTPBridge } from "../../contracts/core/CCTPBridge.sol";
import { CrossChainMessenger } from "../../contracts/core/CrossChainMessenger.sol";
import { MockERC20 } from "../mocks/MockERC20.sol";
import { MockTokenMessenger } from "../mocks/MockTokenMessenger.sol";
import { MockMessageTransmitter } from "../mocks/MockMessageTransmitter.sol";
import { MockMailbox } from "../mocks/MockMailbox.sol";
import { MockInterchainGasPaymaster } from "../mocks/MockInterchainGasPaymaster.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MotherVaultCCTPCallbackTest is Test {
    MotherVault public motherVault;
    CCTPBridge public cctpBridge;
    CrossChainMessenger public messenger;
    MockERC20 public usdc;
    MockTokenMessenger public tokenMessenger;
    MockMessageTransmitter public messageTransmitter;
    MockMailbox public mailbox;
    MockInterchainGasPaymaster public gasPaymaster;

    address public admin = address(0x1);
    address public user = address(0x3);
    address public childVault = address(0x5);

    uint32 public constant BASE_DOMAIN = 6; // CCTP v2 domain for Base
    uint32 public constant ARBITRUM_DOMAIN = 3; // CCTP v2 domain for Arbitrum
    uint32 public constant KATANA_DOMAIN = 100; // Custom domain for Katana (not CCTP)

    event FundsReceivedFromChild(uint32 indexed sourceDomain, uint256 amount);
    event BridgeCompleted(bytes32 indexed messageHash, uint256 amount, uint32 sourceDomain, address indexed recipient);

    function setUp() public {
        // Setup tokens and mocks
        usdc = new MockERC20("USD Coin", "USDC", 6);
        tokenMessenger = new MockTokenMessenger(address(usdc));
        messageTransmitter = new MockMessageTransmitter();
        mailbox = new MockMailbox();
        gasPaymaster = new MockInterchainGasPaymaster();

        // Deploy core contracts
        motherVault = new MotherVault(address(usdc), "autoUSD", "aUSD");

        cctpBridge = new CCTPBridge(address(tokenMessenger), address(messageTransmitter), address(usdc), admin);

        messenger = new CrossChainMessenger(
            address(mailbox), address(gasPaymaster), address(cctpBridge), address(motherVault), admin
        );

        // Initialize mother vault with dependencies
        usdc.mint(admin, 1000e6); // For initial deposit
        vm.startPrank(admin);
        usdc.approve(address(motherVault), 1000e6);
        motherVault.initialize(address(messenger), address(cctpBridge));
        vm.stopPrank();

        // Setup child vaults
        vm.prank(admin);
        motherVault.addChildVault(ARBITRUM_DOMAIN, childVault);

        vm.prank(admin);
        motherVault.addChildVault(KATANA_DOMAIN, address(0x6));

        // Mint USDC for testing
        usdc.mint(address(cctpBridge), 1_000_000e6);
        usdc.mint(user, 1_000_000e6);
    }

    function test_HandleCCTPReceive_AccountingUpdates() public {
        uint256 deployAmount = 100e6;
        uint256 receiveAmount = 50e6;

        // First deploy some funds to create deployed balance
        vm.startPrank(user);
        usdc.approve(address(motherVault), deployAmount);
        motherVault.deposit(deployAmount, user);
        vm.stopPrank();

        vm.prank(admin);
        motherVault.deployToChildVault(ARBITRUM_DOMAIN, deployAmount);

        // Check initial state
        uint256 initialTotalIdle = motherVault.getCurrentBuffer();
        uint256 initialTotalDeployed = motherVault.totalDeployedAssets();
        uint256 initialTotalAssets = motherVault.totalAssets();
        IMotherVault.ChildVault memory childVault_before = motherVault.getChildVault(ARBITRUM_DOMAIN);

        // Simulate CCTP receive
        vm.prank(address(cctpBridge));
        motherVault.handleCCTPReceive(receiveAmount, ARBITRUM_DOMAIN, bytes32(uint256(0x123)));

        // Check accounting updates
        assertEq(
            motherVault.getCurrentBuffer(),
            initialTotalIdle + receiveAmount,
            "Total idle should increase by received amount"
        );

        assertEq(
            motherVault.totalDeployedAssets(),
            initialTotalDeployed - receiveAmount,
            "Total deployed should decrease by received amount"
        );

        assertEq(motherVault.totalAssets(), initialTotalAssets, "Total assets should remain the same");

        IMotherVault.ChildVault memory childVault_after = motherVault.getChildVault(ARBITRUM_DOMAIN);
        assertEq(
            childVault_after.deployedAmount,
            childVault_before.deployedAmount - receiveAmount,
            "Child vault deployed amount should decrease"
        );
    }

    function test_HandleCCTPReceive_BufferStatusUpdate() public {
        uint256 deployAmount = 200e6;
        uint256 receiveAmount = 75e6;

        // Deploy funds to make buffer insufficient
        vm.startPrank(user);
        usdc.approve(address(motherVault), deployAmount);
        motherVault.deposit(deployAmount, user);
        vm.stopPrank();

        vm.prank(admin);
        motherVault.deployToChildVault(ARBITRUM_DOMAIN, deployAmount);

        // Verify buffer is insufficient initially
        bool bufferSufficientBefore = motherVault.isBufferSufficient();
        uint256 bufferBefore = motherVault.getCurrentBuffer();
        uint256 requiredBuffer = motherVault.getRequiredBuffer();

        // Should be insufficient as we deployed all available funds
        assertFalse(bufferSufficientBefore, "Buffer should be insufficient after deployment");

        // Receive funds to improve buffer
        vm.prank(address(cctpBridge));
        motherVault.handleCCTPReceive(receiveAmount, ARBITRUM_DOMAIN, bytes32(uint256(0x124)));

        uint256 bufferAfter = motherVault.getCurrentBuffer();
        bool bufferSufficientAfter = motherVault.isBufferSufficient();

        assertEq(bufferAfter, bufferBefore + receiveAmount, "Buffer should increase by receive amount");
        assertTrue(bufferAfter > bufferBefore, "Buffer should be better after receive");
    }

    function test_HandleCCTPReceive_MultipleSequentialReceives() public {
        uint256[] memory receiveAmounts = new uint256[](4);
        receiveAmounts[0] = 25e6;
        receiveAmounts[1] = 40e6;
        receiveAmounts[2] = 15e6;
        receiveAmounts[3] = 60e6;

        uint256 totalReceived = 0;

        // Deploy initial funds
        vm.startPrank(user);
        usdc.approve(address(motherVault), 200e6);
        motherVault.deposit(200e6, user);
        vm.stopPrank();

        vm.prank(admin);
        motherVault.deployToChildVault(ARBITRUM_DOMAIN, 140e6);

        uint256 initialIdle = motherVault.getCurrentBuffer();
        uint256 initialDeployed = motherVault.totalDeployedAssets();
        uint256 initialChildDeployed = motherVault.getChildVault(ARBITRUM_DOMAIN).deployedAmount;

        // Execute multiple receives
        for (uint256 i = 0; i < receiveAmounts.length; i++) {
            vm.expectEmit(true, false, false, true);
            emit FundsReceivedFromChild(ARBITRUM_DOMAIN, receiveAmounts[i]);

            vm.prank(address(cctpBridge));
            motherVault.handleCCTPReceive(receiveAmounts[i], ARBITRUM_DOMAIN, bytes32(uint256(0x200 + i)));

            totalReceived += receiveAmounts[i];

            // Verify progressive accounting updates
            assertEq(
                motherVault.getCurrentBuffer(),
                initialIdle + totalReceived,
                string(abi.encodePacked("Idle should increase progressively at step ", i))
            );

            assertEq(
                motherVault.totalDeployedAssets(),
                initialDeployed - totalReceived,
                string(abi.encodePacked("Deployed should decrease progressively at step ", i))
            );

            assertEq(
                motherVault.getChildVault(ARBITRUM_DOMAIN).deployedAmount,
                initialChildDeployed - totalReceived,
                string(abi.encodePacked("Child deployed should decrease progressively at step ", i))
            );
        }
    }

    function test_HandleCCTPReceive_DuringRebalancing() public {
        uint256 deployAmount = 150e6;
        uint256 receiveAmount = 50e6;

        // Setup two child vaults with different APYs
        vm.startPrank(user);
        usdc.approve(address(motherVault), deployAmount * 2);
        motherVault.deposit(deployAmount * 2, user);
        vm.stopPrank();

        // Deploy to both child vaults
        vm.startPrank(admin);
        motherVault.deployToChildVault(ARBITRUM_DOMAIN, deployAmount);
        motherVault.deployToChildVault(KATANA_DOMAIN, deployAmount);
        vm.stopPrank();

        // Report different APYs to trigger rebalance conditions
        motherVault.reportYield(ARBITRUM_DOMAIN, 800, deployAmount); // 8% APY
        motherVault.reportYield(KATANA_DOMAIN, 1200, deployAmount); // 12% APY

        uint256 idleBefore = motherVault.getCurrentBuffer();
        uint256 deployedBefore = motherVault.totalDeployedAssets();
        uint256 arbitrumDeployedBefore = motherVault.getChildVault(ARBITRUM_DOMAIN).deployedAmount;

        // Receive funds from Arbitrum during potential rebalancing period
        vm.prank(address(cctpBridge));
        motherVault.handleCCTPReceive(receiveAmount, ARBITRUM_DOMAIN, bytes32(uint256(0x300)));

        // Verify accounting is still correct
        assertEq(
            motherVault.getCurrentBuffer(),
            idleBefore + receiveAmount,
            "Idle should update correctly during rebalancing period"
        );

        assertEq(
            motherVault.totalDeployedAssets(),
            deployedBefore - receiveAmount,
            "Total deployed should update correctly during rebalancing period"
        );

        assertEq(
            motherVault.getChildVault(ARBITRUM_DOMAIN).deployedAmount,
            arbitrumDeployedBefore - receiveAmount,
            "Arbitrum deployed amount should update correctly"
        );

        // Katana should be unaffected
        assertEq(
            motherVault.getChildVault(KATANA_DOMAIN).deployedAmount,
            deployAmount,
            "Katana deployed amount should be unchanged"
        );
    }

    function test_HandleCCTPReceive_WithPendingWithdrawals() public {
        uint256 depositAmount = 200e6;
        uint256 deployAmount = 150e6;
        uint256 withdrawAmount = 50e6;
        uint256 receiveAmount = 75e6;

        // User deposits
        vm.startPrank(user);
        usdc.approve(address(motherVault), depositAmount);
        uint256 shares = motherVault.deposit(depositAmount, user);
        vm.stopPrank();

        // Deploy funds
        vm.prank(admin);
        motherVault.deployToChildVault(ARBITRUM_DOMAIN, deployAmount);

        // User tries to withdraw (should be limited by available idle funds)
        uint256 maxWithdraw = motherVault.maxWithdraw(user);
        assertTrue(maxWithdraw < withdrawAmount, "Should be limited by buffer/idle availability");

        uint256 idleBefore = motherVault.getCurrentBuffer();
        uint256 deployedBefore = motherVault.totalDeployedAssets();

        // Receive funds from child vault
        vm.prank(address(cctpBridge));
        motherVault.handleCCTPReceive(receiveAmount, ARBITRUM_DOMAIN, bytes32(uint256(0x400)));

        // Check that accounting is updated
        assertEq(
            motherVault.getCurrentBuffer(),
            idleBefore + receiveAmount,
            "Idle should increase despite pending withdrawal pressure"
        );

        assertEq(
            motherVault.totalDeployedAssets(),
            deployedBefore - receiveAmount,
            "Deployed should decrease despite pending withdrawal pressure"
        );

        // Check that withdrawal availability has improved
        uint256 maxWithdrawAfter = motherVault.maxWithdraw(user);
        assertTrue(maxWithdrawAfter > maxWithdraw, "Withdrawal availability should improve after receive");

        // User should now be able to withdraw more
        vm.prank(user);
        motherVault.withdraw(withdrawAmount, user, user);
        assertEq(usdc.balanceOf(user), withdrawAmount, "User should receive withdrawn USDC");
    }

    function test_HandleCCTPReceive_EventEmission() public {
        uint256 receiveAmount = 80e6;
        bytes32 messageHash = bytes32(uint256(0x500));

        // Deploy some funds first
        vm.startPrank(user);
        usdc.approve(address(motherVault), 100e6);
        motherVault.deposit(100e6, user);
        vm.stopPrank();

        vm.prank(admin);
        motherVault.deployToChildVault(ARBITRUM_DOMAIN, 100e6);

        // Expect the correct event
        vm.expectEmit(true, false, false, true);
        emit FundsReceivedFromChild(ARBITRUM_DOMAIN, receiveAmount);

        vm.prank(address(cctpBridge));
        motherVault.handleCCTPReceive(receiveAmount, ARBITRUM_DOMAIN, messageHash);
    }

    function test_HandleCCTPReceive_OnlyAuthorizedCallers() public {
        uint256 receiveAmount = 30e6;

        // Should revert when called by unauthorized address
        vm.expectRevert("Only messenger/bridge");
        vm.prank(user);
        motherVault.handleCCTPReceive(receiveAmount, ARBITRUM_DOMAIN, bytes32(0));

        // Should succeed when called by CCTP bridge
        vm.prank(address(cctpBridge));
        motherVault.handleCCTPReceive(receiveAmount, ARBITRUM_DOMAIN, bytes32(0));

        // Should succeed when called by messenger
        vm.prank(address(messenger));
        motherVault.handleCCTPReceive(receiveAmount, ARBITRUM_DOMAIN, bytes32(0));
    }

    function test_HandleCCTPReceive_UnknownSourceDomain() public {
        uint32 unknownDomain = 99;
        uint256 receiveAmount = 30e6;

        vm.expectRevert("Unknown source");
        vm.prank(address(cctpBridge));
        motherVault.handleCCTPReceive(receiveAmount, unknownDomain, bytes32(0));
    }

    function test_HandleCCTPReceive_ZeroAmount() public {
        uint256 receiveAmount = 0;

        uint256 idleBefore = motherVault.getCurrentBuffer();
        uint256 deployedBefore = motherVault.totalDeployedAssets();

        // Should handle zero amount gracefully
        vm.prank(address(cctpBridge));
        motherVault.handleCCTPReceive(receiveAmount, ARBITRUM_DOMAIN, bytes32(0));

        // No accounting changes should occur
        assertEq(motherVault.getCurrentBuffer(), idleBefore);
        assertEq(motherVault.totalDeployedAssets(), deployedBefore);
    }

    function test_HandleCCTPReceive_AccountingInvariantCheck() public {
        uint256 deployAmount = 100e6;
        uint256 receiveAmount = 60e6;

        // Deploy funds
        vm.startPrank(user);
        usdc.approve(address(motherVault), deployAmount);
        motherVault.deposit(deployAmount, user);
        vm.stopPrank();

        vm.prank(admin);
        motherVault.deployToChildVault(ARBITRUM_DOMAIN, deployAmount);

        uint256 totalAssetsBefore = motherVault.totalAssets();

        // Receive funds
        vm.prank(address(cctpBridge));
        motherVault.handleCCTPReceive(receiveAmount, ARBITRUM_DOMAIN, bytes32(0));

        uint256 totalAssetsAfter = motherVault.totalAssets();

        // Total assets should remain constant (idle increases, deployed decreases by same amount)
        assertEq(totalAssetsAfter, totalAssetsBefore, "Total assets should remain constant");

        // Verify accounting equation: totalAssets = idle + deployed
        assertEq(
            motherVault.totalAssets(),
            motherVault.getCurrentBuffer() + motherVault.totalDeployedAssets(),
            "Accounting equation should hold"
        );
    }

    function testFuzz_HandleCCTPReceive_AccountingCorrectness(uint256 deployAmount, uint256 receiveAmount) public {
        deployAmount = bound(deployAmount, 1e6, 500e6);
        receiveAmount = bound(receiveAmount, 1e6, deployAmount);

        // Setup
        vm.startPrank(user);
        usdc.approve(address(motherVault), deployAmount);
        motherVault.deposit(deployAmount, user);
        vm.stopPrank();

        vm.prank(admin);
        motherVault.deployToChildVault(ARBITRUM_DOMAIN, deployAmount);

        uint256 idleBefore = motherVault.getCurrentBuffer();
        uint256 deployedBefore = motherVault.totalDeployedAssets();
        uint256 totalBefore = motherVault.totalAssets();
        uint256 childDeployedBefore = motherVault.getChildVault(ARBITRUM_DOMAIN).deployedAmount;

        // Receive
        vm.prank(address(cctpBridge));
        motherVault.handleCCTPReceive(receiveAmount, ARBITRUM_DOMAIN, bytes32(0));

        // Verify accounting
        assertEq(motherVault.getCurrentBuffer(), idleBefore + receiveAmount);
        assertEq(motherVault.totalDeployedAssets(), deployedBefore - receiveAmount);
        assertEq(motherVault.totalAssets(), totalBefore);
        assertEq(motherVault.getChildVault(ARBITRUM_DOMAIN).deployedAmount, childDeployedBefore - receiveAmount);
    }
}
