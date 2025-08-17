// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Test, console2 } from "forge-std/Test.sol";
import { MotherVault } from "../../contracts/MotherVault.sol";
import { CCTPBridge } from "../../contracts/core/CCTPBridge.sol";
import { CrossChainMessenger } from "../../contracts/core/CrossChainMessenger.sol";
import { IMotherVault } from "../../contracts/interfaces/IMotherVault.sol";
import { MockERC20 } from "../mocks/MockERC20.sol";
import { MockTokenMessenger } from "../mocks/MockTokenMessenger.sol";
import { MockMessageTransmitter } from "../mocks/MockMessageTransmitter.sol";
import { MockMailbox } from "../mocks/MockMailbox.sol";
import { MockInterchainGasPaymaster } from "../mocks/MockInterchainGasPaymaster.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title CCTPBridgeIntegration
 * @notice Integration tests for CCTP bridge message handling
 * @dev Tests end-to-end CCTP message flow and handleCCTPReceive functionality
 */
contract CCTPBridgeIntegrationTest is Test {
    MotherVault public motherVault;
    CCTPBridge public cctpBridge;
    CrossChainMessenger public messenger;
    MockERC20 public usdc;
    MockTokenMessenger public tokenMessenger;
    MockMessageTransmitter public messageTransmitter;
    MockMailbox public mailbox;

    address public admin = address(0x1);
    address public user = address(0x2);
    address public childVaultArbitrum = address(0x3);
    address public childVaultKatana = address(0x4);

    uint32 public constant BASE_DOMAIN = 6; // CCTP v2 domain for Base
    uint32 public constant ARBITRUM_DOMAIN = 3; // CCTP v2 domain for Arbitrum
    uint32 public constant KATANA_DOMAIN = 100; // Custom domain for Katana (not CCTP)

    event BridgeCompleted(bytes32 indexed messageHash, uint256 amount, uint32 sourceDomain, address indexed recipient);
    event FundsReceivedFromChild(uint32 indexed sourceDomain, uint256 amount);
    event FundsDeployedToChild(uint32 indexed destinationDomain, uint256 amount);

    function setUp() public {
        // Deploy mock tokens and infrastructure
        usdc = new MockERC20("USD Coin", "USDC", 6);
        tokenMessenger = new MockTokenMessenger(address(usdc));
        messageTransmitter = new MockMessageTransmitter();
        mailbox = new MockMailbox();

        // Deploy core contracts
        motherVault = new MotherVault(address(usdc), "autoUSD", "aUSD");
        cctpBridge = new CCTPBridge(address(tokenMessenger), address(messageTransmitter), address(usdc), admin);
        MockInterchainGasPaymaster gasPaymaster = new MockInterchainGasPaymaster();
        messenger = new CrossChainMessenger(
            address(mailbox), address(gasPaymaster), address(cctpBridge), address(motherVault), admin
        );

        // Initialize contracts - test contract is the deployer and has admin role
        // MotherVault requires initial deposit to prevent share manipulation
        usdc.mint(address(this), 100e6);
        usdc.approve(address(motherVault), 100e6);
        motherVault.initialize(address(messenger), address(cctpBridge));
        motherVault.addChildVault(ARBITRUM_DOMAIN, childVaultArbitrum);
        motherVault.addChildVault(KATANA_DOMAIN, childVaultKatana);

        // Grant admin role to our admin address for later operations
        motherVault.grantRole(motherVault.DEFAULT_ADMIN_ROLE(), admin);
        motherVault.grantRole(motherVault.MANAGER_ROLE(), admin);
        motherVault.grantRole(motherVault.REBALANCER_ROLE(), admin);

        // Set deposit cap for testing (default is only 100 USDC)
        motherVault.setDepositCap(10_000_000e6); // 10M USDC cap for tests

        // Setup trusted domains in messenger (required for cross-chain messages)
        vm.startPrank(admin);
        // Configure domain mappings (CCTP domain -> Hyperlane domain)
        // We use the CCTP domain as both chain ID and Hyperlane domain for simplicity in tests
        messenger.configureDomain(ARBITRUM_DOMAIN, ARBITRUM_DOMAIN);
        messenger.configureDomain(KATANA_DOMAIN, KATANA_DOMAIN);
        // Set trusted senders
        messenger.setTrustedSender(ARBITRUM_DOMAIN, bytes32(uint256(uint160(childVaultArbitrum))));
        messenger.setTrustedSender(KATANA_DOMAIN, bytes32(uint256(uint160(childVaultKatana))));
        vm.stopPrank();

        // Fund test accounts
        usdc.mint(user, 10_000e6);
        usdc.mint(address(cctpBridge), 10_000e6);
        usdc.mint(address(motherVault), 1000e6);

        // Fund MotherVault with ETH for gas fees
        vm.deal(address(motherVault), 10 ether);
    }

    /**
     * @notice Test CCTP message completion calling handleCCTPReceive directly (bridge path)
     * @dev Simulates a complete CCTP bridge flow from child vault back to mother vault
     */
    function test_CCTPBridge_DirectHandleReceive() public {
        uint256 deployAmount = 500e6;
        uint256 returnAmount = 200e6;
        bytes32 messageHash = keccak256("test_message");

        // Step 1: User deposits and funds are deployed to child vault
        vm.startPrank(user);
        usdc.approve(address(motherVault), deployAmount);
        motherVault.deposit(deployAmount, user);
        vm.stopPrank();

        vm.prank(admin);
        motherVault.deployToChildVault(ARBITRUM_DOMAIN, deployAmount);

        // Verify deployment state
        IMotherVault.ChildVault memory childVault = motherVault.getChildVault(ARBITRUM_DOMAIN);
        assertEq(childVault.deployedAmount, deployAmount, "Child vault should have deployed amount");
        assertEq(motherVault.totalDeployedAssets(), deployAmount, "Total deployed should match");

        // Step 2: Simulate CCTP bridge receiving funds from child vault
        uint256 idleBefore = motherVault.getCurrentBuffer();
        uint256 deployedBefore = motherVault.totalDeployedAssets();

        // Bridge calls handleCCTPReceive directly
        vm.prank(address(cctpBridge));
        motherVault.handleCCTPReceive(returnAmount, ARBITRUM_DOMAIN, messageHash);

        // Step 3: Verify accounting after bridge completion
        assertEq(motherVault.getCurrentBuffer(), idleBefore + returnAmount, "Buffer should increase by return amount");
        assertEq(
            motherVault.totalDeployedAssets(),
            deployedBefore - returnAmount,
            "Total deployed should decrease by return amount"
        );

        childVault = motherVault.getChildVault(ARBITRUM_DOMAIN);
        assertEq(childVault.deployedAmount, deployAmount - returnAmount, "Child vault deployed should decrease");

        // Step 4: Verify total assets remain constant (no loss)
        assertEq(
            motherVault.totalAssets(),
            motherVault.getCurrentBuffer() + motherVault.totalDeployedAssets(),
            "Total assets should equal buffer + deployed"
        );
    }

    /**
     * @notice Test multiple sequential CCTP receives from different child vaults
     * @dev Verifies correct accounting when receiving from multiple sources
     */
    function test_CCTPBridge_MultipleSourceReceives() public {
        uint256 deployArbitrum = 300e6;
        uint256 deployKatana = 400e6;
        uint256 returnArbitrum = 100e6;
        uint256 returnKatana = 150e6;

        // Deploy to both child vaults
        vm.startPrank(user);
        usdc.approve(address(motherVault), deployArbitrum + deployKatana);
        motherVault.deposit(deployArbitrum + deployKatana, user);
        vm.stopPrank();

        vm.startPrank(admin);
        motherVault.deployToChildVault(ARBITRUM_DOMAIN, deployArbitrum);
        motherVault.deployToChildVault(KATANA_DOMAIN, deployKatana);
        vm.stopPrank();

        uint256 totalAssetsBefore = motherVault.totalAssets();

        // Receive from Arbitrum
        vm.prank(address(cctpBridge));
        motherVault.handleCCTPReceive(returnArbitrum, ARBITRUM_DOMAIN, bytes32(uint256(1)));

        IMotherVault.ChildVault memory arbitrumVault = motherVault.getChildVault(ARBITRUM_DOMAIN);
        assertEq(arbitrumVault.deployedAmount, deployArbitrum - returnArbitrum, "Arbitrum deployed should decrease");

        // Receive from Katana
        vm.prank(address(cctpBridge));
        motherVault.handleCCTPReceive(returnKatana, KATANA_DOMAIN, bytes32(uint256(2)));

        IMotherVault.ChildVault memory katanaVault = motherVault.getChildVault(KATANA_DOMAIN);
        assertEq(katanaVault.deployedAmount, deployKatana - returnKatana, "Katana deployed should decrease");

        // Verify total accounting
        assertEq(motherVault.getCurrentBuffer(), returnArbitrum + returnKatana, "Buffer should have both returns");
        assertEq(
            motherVault.totalDeployedAssets(),
            (deployArbitrum - returnArbitrum) + (deployKatana - returnKatana),
            "Total deployed should be accurate"
        );
        assertEq(motherVault.totalAssets(), totalAssetsBefore, "Total assets should remain constant");
    }

    /**
     * @notice Test CCTP bridge handling during active withdrawals
     * @dev Ensures bridge receives improve withdrawal liquidity
     */
    function test_CCTPBridge_ImproveWithdrawalLiquidity() public {
        uint256 depositAmount = 600e6;
        uint256 deployAmount = 550e6;
        uint256 returnAmount = 300e6;

        // User deposits and funds are deployed
        vm.startPrank(user);
        usdc.approve(address(motherVault), depositAmount);
        uint256 shares = motherVault.deposit(depositAmount, user);
        vm.stopPrank();

        vm.prank(admin);
        motherVault.deployToChildVault(ARBITRUM_DOMAIN, deployAmount);

        // Check withdrawal is limited by buffer
        uint256 maxWithdrawBefore = motherVault.maxWithdraw(user);
        assertEq(maxWithdrawBefore, depositAmount - deployAmount, "Max withdraw should be limited to buffer");

        // Receive funds via CCTP to improve liquidity
        vm.prank(address(cctpBridge));
        motherVault.handleCCTPReceive(returnAmount, ARBITRUM_DOMAIN, bytes32(uint256(3)));

        // Verify improved withdrawal capacity
        uint256 maxWithdrawAfter = motherVault.maxWithdraw(user);
        assertEq(maxWithdrawAfter, maxWithdrawBefore + returnAmount, "Max withdraw should increase by returned amount");

        // Execute withdrawal
        uint256 withdrawAmount = 250e6;
        vm.prank(user);
        uint256 assetsWithdrawn = motherVault.withdraw(withdrawAmount, user, user);

        assertEq(assetsWithdrawn, withdrawAmount, "Should withdraw requested amount");
        assertEq(usdc.balanceOf(user), withdrawAmount, "User should receive USDC");
    }

    /**
     * @notice Test CCTP bridge error handling for invalid domains
     * @dev Ensures proper validation of source domains
     */
    function test_CCTPBridge_RevertInvalidDomain() public {
        uint32 invalidDomain = 999;
        uint256 amount = 100e6;

        vm.expectRevert("Unknown source");
        vm.prank(address(cctpBridge));
        motherVault.handleCCTPReceive(amount, invalidDomain, bytes32(0));
    }

    /**
     * @notice Test CCTP bridge authorization
     * @dev Only bridge and messenger should be able to call handleCCTPReceive
     */
    function test_CCTPBridge_Authorization() public {
        uint256 amount = 100e6;

        // Unauthorized caller should fail
        vm.expectRevert("Only messenger/bridge");
        vm.prank(user);
        motherVault.handleCCTPReceive(amount, ARBITRUM_DOMAIN, bytes32(0));

        // Bridge should succeed
        vm.prank(address(cctpBridge));
        motherVault.handleCCTPReceive(amount, ARBITRUM_DOMAIN, bytes32(0));

        // Messenger should succeed
        vm.prank(address(messenger));
        motherVault.handleCCTPReceive(amount, KATANA_DOMAIN, bytes32(0));
    }

    /**
     * @notice Fuzz test for CCTP bridge accounting consistency
     * @dev Ensures accounting remains consistent across various amounts
     */
    function testFuzz_CCTPBridge_AccountingConsistency(
        uint256 deployAmount,
        uint256 returnAmount,
        uint8 numReturns
    )
        public
    {
        deployAmount = bound(deployAmount, 10e6, 1000e6);
        numReturns = uint8(bound(numReturns, 1, 10));

        // Setup and deploy
        vm.startPrank(user);
        usdc.approve(address(motherVault), deployAmount);
        motherVault.deposit(deployAmount, user);
        vm.stopPrank();

        vm.prank(admin);
        motherVault.deployToChildVault(ARBITRUM_DOMAIN, deployAmount);

        uint256 totalReturned = 0;
        uint256 remainingDeployed = deployAmount;

        // Multiple partial returns
        for (uint8 i = 0; i < numReturns; i++) {
            uint256 thisReturn = bound(returnAmount, 1e6, remainingDeployed / 2);
            if (thisReturn > remainingDeployed) break;

            uint256 bufferBefore = motherVault.getCurrentBuffer();
            uint256 deployedBefore = motherVault.totalDeployedAssets();
            uint256 totalBefore = motherVault.totalAssets();

            vm.prank(address(cctpBridge));
            motherVault.handleCCTPReceive(thisReturn, ARBITRUM_DOMAIN, bytes32(uint256(i)));

            totalReturned += thisReturn;
            remainingDeployed -= thisReturn;

            // Verify accounting
            assertEq(motherVault.getCurrentBuffer(), bufferBefore + thisReturn, "Buffer should increase correctly");
            assertEq(
                motherVault.totalDeployedAssets(), deployedBefore - thisReturn, "Deployed should decrease correctly"
            );
            assertEq(motherVault.totalAssets(), totalBefore, "Total assets should remain constant");
            assertEq(
                motherVault.getChildVault(ARBITRUM_DOMAIN).deployedAmount,
                remainingDeployed,
                "Child vault tracking should be accurate"
            );
        }
    }
}
