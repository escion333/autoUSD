// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../../contracts/MotherVault.sol";
import "../../contracts/core/CrossChainMessenger.sol";
import "../../contracts/core/CCTPBridge.sol";
import "../../contracts/core/Rebalancer.sol";
import "../../test/mocks/MockERC20.sol";
import "../../test/mocks/MockMailbox.sol";
import "../../test/mocks/MockTokenMessenger.sol";
import "../../test/mocks/MockInterchainGasPaymaster.sol";

/**
 * @title SecurityFixes Test Suite
 * @notice Tests for critical security vulnerabilities that were fixed
 */
contract SecurityFixesTest is Test {
    MotherVault public motherVault;
    CrossChainMessenger public crossChainMessenger;
    CCTPBridge public cctpBridge;
    Rebalancer public rebalancer;
    
    MockERC20 public usdc;
    MockMailbox public mailbox;
    MockTokenMessenger public tokenMessenger;
    MockInterchainGasPaymaster public gasPaymaster;
    
    address public admin = makeAddr("admin");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public attacker = makeAddr("attacker");
    
    uint256 public constant INITIAL_DEPOSIT = 100 * 1e6; // 100 USDC
    uint256 public constant MIN_DEPOSIT = 10 * 1e6; // 10 USDC minimum
    
    event CrossChainTimeout(bytes32 indexed operationId, uint32 indexed domainId, uint256 amount, string reason);
    event RebalanceTriggered(uint32 indexed sourceChainId, uint32 indexed targetChainId, uint256 amount, uint256 expectedAPYImprovement);

    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy mock dependencies
        usdc = new MockERC20("USDC", "USDC", 6);
        mailbox = new MockMailbox();
        tokenMessenger = new MockTokenMessenger(address(usdc));
        gasPaymaster = new MockInterchainGasPaymaster();
        
        // Deploy MotherVault first
        motherVault = new MotherVault(
            address(usdc),
            "autoUSD Shares",
            "aUSD"
        );
        
        // Deploy CCTP Bridge
        cctpBridge = new CCTPBridge(
            address(tokenMessenger),
            address(tokenMessenger), // Using same for simplicity
            address(usdc),
            admin
        );
        
        // Deploy CrossChainMessenger with correct mother vault address
        crossChainMessenger = new CrossChainMessenger(
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
        
        // Set deposit cap to allow testing
        motherVault.setDepositCap(10000 * 1e6); // 10k USDC cap
        
        // Deploy Rebalancer
        rebalancer = new Rebalancer(address(motherVault));
        
        // Update rebalance config to allow immediate testing
        IRebalancer.RebalanceConfig memory config = IRebalancer.RebalanceConfig({
            minAPYDifferentialBps: 100,
            maxRebalanceAmount: 1_000_000 * 1e6,
            minRebalanceAmount: 1000 * 1e6,
            rebalanceCooldown: 0, // No cooldown for testing
            maxGasCostUSD: 50 * 1e6,
            targetAllocationRatio: 0
        });
        rebalancer.updateRebalanceConfig(config);
        
        // Setup test balances
        usdc.mint(user1, 1000 * 1e6);
        usdc.mint(user2, 1000 * 1e6);
        usdc.mint(attacker, 1000 * 1e6);
        
        // Fund contracts with ETH for cross-chain operations
        vm.deal(address(motherVault), 10 ether);
        vm.deal(address(crossChainMessenger), 10 ether);
        vm.deal(admin, 10 ether);
        
        vm.stopPrank();
    }
    
    /**
     * @notice Test C3: Share Price Manipulation Protection
     */
    function testSharePriceManipulationProtection() public {
        vm.startPrank(attacker);
        
        // Attacker tries to manipulate share price with large direct transfer
        usdc.transfer(address(motherVault), 100 * 1e6);
        
        // Next depositor should still get fair shares due to virtual shares protection
        vm.startPrank(user1);
        usdc.approve(address(motherVault), 50 * 1e6);
        
        // This should not fail due to manipulation protection
        uint256 sharesBefore = motherVault.balanceOf(user1);
        motherVault.deposit(50 * 1e6, user1);
        uint256 sharesAfter = motherVault.balanceOf(user1);
        
        // User should receive reasonable amount of shares
        assertTrue(sharesAfter > sharesBefore);
        assertTrue(sharesAfter >= 40 * 1e6); // Should get close to deposited amount
        
        vm.stopPrank();
    }
    
    /**
     * @notice Test minimum deposit enforcement
     */
    function testMinimumDepositEnforcement() public {
        vm.startPrank(user1);
        usdc.approve(address(motherVault), 5 * 1e6);
        
        // Should fail with amount below minimum
        vm.expectRevert("Below minimum deposit");
        motherVault.deposit(5 * 1e6, user1);
        
        vm.stopPrank();
    }
    
    /**
     * @notice Test H3: Buffer Management Bypass Protection
     */
    function testBufferManagementProtection() public {
        // Setup: Make a deposit first
        vm.startPrank(user1);
        usdc.approve(address(motherVault), 200 * 1e6);
        motherVault.deposit(200 * 1e6, user1);
        vm.stopPrank();
        
        // Admin deploys most funds to reduce buffer
        vm.startPrank(admin);
        address childVault1 = makeAddr("childVault1");
        motherVault.addChildVault(1, childVault1);
        crossChainMessenger.setTrustedSender(1, bytes32(uint256(uint160(childVault1))));
        
        // Deploy most funds, leaving only buffer
        uint256 deployableAmount = motherVault.getDeployableAmount();
        if (deployableAmount > 0) {
            motherVault.deployToChildVault(1, deployableAmount);
        }
        vm.stopPrank();
        
        // User should not be able to withdraw beyond buffer requirements
        vm.startPrank(user1);
        uint256 currentBuffer = motherVault.getCurrentBuffer();
        uint256 requiredBuffer = motherVault.getRequiredBuffer();
        
        // Test buffer protection - try to withdraw amount that would bring buffer below required
        uint256 excessWithdrawal = (currentBuffer > requiredBuffer) 
            ? (currentBuffer - requiredBuffer + 1e6) 
            : 1e6; // If at minimum, any withdrawal should be limited by maxWithdraw
        
        if (currentBuffer > requiredBuffer) {
            // Buffer is above minimum, test buffer violation specifically
            vm.expectRevert("Withdrawal would violate buffer requirements");
            motherVault.withdraw(excessWithdrawal, user1, user1);
        } else {
            // Buffer is at minimum, maxWithdraw should be protecting us
            uint256 maxWithdrawal = motherVault.maxWithdraw(user1);
            if (maxWithdrawal == 0) {
                // Cannot withdraw anything - expected behavior when buffer is at minimum
                vm.expectRevert("Exceeds max");
                motherVault.withdraw(1e6, user1, user1);
            } else {
                // Can withdraw up to max, but not more
                vm.expectRevert("Exceeds max");  
                motherVault.withdraw(maxWithdrawal + 1e6, user1, user1);
            }
        }
        
        vm.stopPrank();
    }
    
    /**
     * @notice Test C1: Cross-Chain Replay Attack Protection
     */
    function testCrossChainReplayProtection() public {
        vm.startPrank(admin);
        
        // Setup trusted sender for domain 1
        crossChainMessenger.setTrustedSender(1, bytes32(uint256(uint160(makeAddr("trustedSender")))));
        
        // Simulate a cross-chain message
        bytes memory messageData = abi.encode(
            uint8(2), // YIELD_REPORT
            address(motherVault),
            abi.encode(5000, 100 * 1e6), // 50% APY, 100 USDC total value
            uint256(1), // nonce
            block.timestamp
        );
        
        // First message should succeed (from mailbox)
        vm.startPrank(address(mailbox));
        crossChainMessenger.handle(
            1, // origin domain
            bytes32(uint256(uint160(makeAddr("trustedSender")))),
            messageData
        );
        vm.stopPrank();
        
        // Replay attempt with same message should fail with MessageAlreadyProcessed
        vm.startPrank(address(mailbox));
        vm.expectRevert();
        crossChainMessenger.handle(
            1, // origin domain  
            bytes32(uint256(uint160(makeAddr("trustedSender")))),
            messageData
        );
        vm.stopPrank();
        
        // Advance time to allow for timestamp ordering
        vm.warp(block.timestamp + 10);
        
        // Test with wrong nonce sequence (should fail with Invalid nonce sequence)
        bytes memory wrongNonceMessage = abi.encode(
            uint8(2), // YIELD_REPORT
            address(motherVault),
            abi.encode(5000, 100 * 1e6), // 50% APY, 100 USDC total value
            uint256(3), // wrong nonce - should be 2
            block.timestamp // now valid timestamp, but wrong nonce
        );
        
        vm.startPrank(address(mailbox));
        vm.expectRevert("Invalid nonce sequence");
        crossChainMessenger.handle(
            1, // origin domain  
            bytes32(uint256(uint160(makeAddr("trustedSender")))),
            wrongNonceMessage
        );
        vm.stopPrank();
    }
    
    /**
     * @notice Test H4: Race Condition Protection in Rebalancer
     */
    function testRebalancerRaceConditionProtection() public {
        vm.startPrank(admin);
        
        // Setup rebalancer with REBALANCER_ROLE and MANAGER_ROLE
        motherVault.grantRole(motherVault.REBALANCER_ROLE(), address(rebalancer));
        motherVault.grantRole(motherVault.MANAGER_ROLE(), address(rebalancer));
        
        // Add a child vault and configure domain for cross-chain messaging
        address childVault1 = makeAddr("childVault1");
        motherVault.addChildVault(1, childVault1);
        crossChainMessenger.setTrustedSender(1, bytes32(uint256(uint160(childVault1))));
        
        // Make a deposit first to have funds for rebalancing
        vm.startPrank(user1);
        usdc.approve(address(motherVault), 100 * 1e6);
        motherVault.deposit(100 * 1e6, user1);
        vm.stopPrank();
        
        vm.startPrank(admin);
        
        // Create a rebalance decision with smaller amount
        IRebalancer.RebalanceDecision memory decision = IRebalancer.RebalanceDecision({
            sourceChainId: 0, // Deploy idle funds
            targetChainId: 1,
            amountToMove: 5 * 1e6, // Smaller amount
            expectedAPYImprovement: 5000,
            estimatedGasCost: 1e6,
            shouldExecute: true,
            reason: "Test rebalance"
        });
        
        // Move forward in time to bypass chain cooldown (30 minutes)
        vm.warp(block.timestamp + 31 minutes);
        
        // First rebalance should succeed
        bool success = rebalancer.executeRebalance(decision);
        assertTrue(success);
        
        // Immediate second rebalance should fail due to lock
        vm.expectRevert("Rebalance already executed");
        rebalancer.executeRebalance(decision);
        
        vm.stopPrank();
    }
    
    /**
     * @notice Test H2: Cross-Chain State Synchronization Timeout
     */
    function testCrossChainTimeoutRecovery() public {
        vm.startPrank(admin);
        
        // Add child vault and configure domain
        address childVault1 = makeAddr("childVault1");
        motherVault.addChildVault(1, childVault1);
        crossChainMessenger.setTrustedSender(1, bytes32(uint256(uint160(childVault1))));
        
        // Make a deposit to have funds to deploy
        vm.startPrank(user1);
        usdc.approve(address(motherVault), 100 * 1e6);
        motherVault.deposit(100 * 1e6, user1);
        vm.stopPrank();
        
        vm.startPrank(admin);
        
        // Deploy funds to child vault (this creates a pending operation)
        uint256 deployAmount = 50 * 1e6;
        uint256 totalDeployedBefore = motherVault.totalDeployedAssets();
        
        motherVault.deployToChildVault(1, deployAmount);
        
        // Verify deployment was recorded
        uint256 totalDeployedAfter = motherVault.totalDeployedAssets();
        assertEq(totalDeployedAfter, totalDeployedBefore + deployAmount);
        
        // Fast forward past timeout period
        vm.warp(block.timestamp + 5 hours);
        
        // Check and recover timeouts - don't check operation ID since it's dynamic
        vm.expectEmit(false, true, false, true);
        emit CrossChainTimeout(bytes32(0), 1, deployAmount, "Deployment reverted");
        motherVault.checkAndRecoverTimeouts(1);
        
        // Verify accounting was reverted
        uint256 totalDeployedRecovered = motherVault.totalDeployedAssets();
        assertEq(totalDeployedRecovered, totalDeployedBefore);
        
        vm.stopPrank();
    }
    
    /**
     * @notice Test H1: CCTP Message Validation
     */
    function testCCTPMessageValidation() public {
        vm.startPrank(admin);
        
        // Configure supported domain  
        cctpBridge.configureDomain(1, 1);
        
        // Test with invalid message size
        bytes memory invalidMessage = new bytes(20000); // Exceeds MAX_MESSAGE_SIZE
        
        vm.startPrank(address(tokenMessenger));
        vm.expectRevert("Invalid message size");
        cctpBridge.handleReceiveMessage(1, bytes32(0), invalidMessage);
        
        // Test with empty message
        vm.expectRevert("Invalid message size");
        cctpBridge.handleReceiveMessage(1, bytes32(0), "");
        
        vm.stopPrank();
    }
    
    /**
     * @notice Helper function to test virtual shares calculation
     */
    function testVirtualSharesCalculation() public {
        vm.startPrank(user1);
        usdc.approve(address(motherVault), 100 * 1e6);
        
        uint256 previewShares = motherVault.previewDeposit(100 * 1e6);
        uint256 actualShares = motherVault.deposit(100 * 1e6, user1);
        
        // With virtual shares, the calculation should be more stable
        assertEq(previewShares, actualShares);
        
        vm.stopPrank();
    }
}