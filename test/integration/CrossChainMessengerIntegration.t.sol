// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Test, console2 } from "forge-std/Test.sol";
import { MotherVault } from "../../contracts/MotherVault.sol";
import { CCTPBridge } from "../../contracts/core/CCTPBridge.sol";
import { CrossChainMessenger } from "../../contracts/core/CrossChainMessenger.sol";
import { IMotherVault } from "../../contracts/interfaces/IMotherVault.sol";
import { ICrossChainMessenger } from "../../contracts/interfaces/ICrossChainMessenger.sol";
import { MockERC20 } from "../mocks/MockERC20.sol";
import { MockTokenMessenger } from "../mocks/MockTokenMessenger.sol";
import { MockMessageTransmitter } from "../mocks/MockMessageTransmitter.sol";
import { MockMailbox } from "../mocks/MockMailbox.sol";
import { MockInterchainGasPaymaster } from "../mocks/MockInterchainGasPaymaster.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title CrossChainMessengerIntegration
 * @notice Integration tests for messenger-driven cross-domain operations
 * @dev Tests deposit/withdraw requests across domains via Hyperlane messaging
 */
contract CrossChainMessengerIntegrationTest is Test {
    MotherVault public motherVault;
    CCTPBridge public cctpBridge;
    CrossChainMessenger public messenger;
    MockERC20 public usdc;
    MockTokenMessenger public tokenMessenger;
    MockMessageTransmitter public messageTransmitter;
    MockMailbox public mailbox;

    address public admin = address(0x1);
    address public user = address(0x2);
    address public childVaultEthereumSepolia = address(0x3);
    address public childVaultKatana = address(0x4);
    address public rebalancer = address(0x5);

    uint32 public constant BASE_SEPOLIA_DOMAIN = 6;
    uint32 public constant ETHEREUM_SEPOLIA_DOMAIN = 0;
    uint32 public constant KATANA_DOMAIN = 129399;

    event MessageSent(uint32 indexed destinationDomain, bytes32 indexed messageId, bytes message);
    event MessageReceived(uint32 indexed sourceDomain, bytes32 indexed messageId, bytes message);
    event CrossChainDepositRequest(uint32 indexed destinationDomain, uint256 amount);
    event CrossChainWithdrawRequest(uint32 indexed sourceDomain, uint256 amount);
    event FundsDeployedToChild(uint32 indexed destinationDomain, uint256 amount);
    event FundsReceivedFromChild(uint32 indexed sourceDomain, uint256 amount);

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
        motherVault.addChildVault(ETHEREUM_SEPOLIA_DOMAIN, childVaultEthereumSepolia);
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
        messenger.configureDomain(ETHEREUM_SEPOLIA_DOMAIN, ETHEREUM_SEPOLIA_DOMAIN);
        messenger.configureDomain(KATANA_DOMAIN, KATANA_DOMAIN);
        // Set trusted senders
        messenger.setTrustedSender(ETHEREUM_SEPOLIA_DOMAIN, bytes32(uint256(uint160(childVaultEthereumSepolia))));
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
     * @notice Test messenger-driven deposit request from mother to child vault
     * @dev Simulates complete cross-domain deposit flow via Hyperlane
     */
    function test_Messenger_CrossDomainDeposit() public {
        uint256 depositAmount = 500e6;
        uint256 deployAmount = 400e6;

        // Step 1: User deposits to mother vault
        vm.startPrank(user);
        usdc.approve(address(motherVault), depositAmount);
        uint256 shares = motherVault.deposit(depositAmount, user);
        vm.stopPrank();

        assertEq(motherVault.getCurrentBuffer(), depositAmount, "Buffer should have deposit");
        assertEq(motherVault.balanceOf(user), shares, "User should have shares");

        // Step 2: Initiate cross-domain deployment via messenger
        vm.expectEmit(true, false, false, true);
        emit FundsDeployedToChild(ETHEREUM_SEPOLIA_DOMAIN, deployAmount);

        vm.prank(admin);
        motherVault.deployToChildVault(ETHEREUM_SEPOLIA_DOMAIN, deployAmount);

        // Step 3: Verify deployment state
        IMotherVault.ChildVault memory childVault = motherVault.getChildVault(ETHEREUM_SEPOLIA_DOMAIN);
        assertEq(childVault.deployedAmount, deployAmount, "Child vault should track deployment");
        assertEq(motherVault.totalDeployedAssets(), deployAmount, "Total deployed should match");
        assertEq(motherVault.getCurrentBuffer(), depositAmount - deployAmount, "Buffer should decrease");

        // Step 4: Verify deployment state remains consistent
        // Note: In production, child vault would send yield reports via messenger
        assertEq(
            motherVault.getChildVault(ETHEREUM_SEPOLIA_DOMAIN).deployedAmount, deployAmount, "Deployment should be tracked"
        );
    }

    /**
     * @notice Test messenger-driven withdraw request from child to mother vault
     * @dev Simulates complete cross-domain withdrawal flow
     */
    function test_Messenger_CrossDomainWithdraw() public {
        uint256 depositAmount = 800e6;
        uint256 deployAmount = 600e6;
        uint256 withdrawAmount = 300e6;

        // Setup: Deploy funds to child vault
        vm.startPrank(user);
        usdc.approve(address(motherVault), depositAmount);
        motherVault.deposit(depositAmount, user);
        vm.stopPrank();

        vm.prank(admin);
        motherVault.deployToChildVault(KATANA_DOMAIN, deployAmount);

        // Step 1: Simulate child vault requesting withdrawal via messenger
        bytes memory withdrawRequest =
            abi.encode(ICrossChainMessenger.MessageType.WITHDRAWAL_REQUEST, withdrawAmount, childVaultKatana);

        uint256 bufferBefore = motherVault.getCurrentBuffer();
        uint256 deployedBefore = motherVault.totalDeployedAssets();

        // Step 2: Messenger receives and processes withdrawal request
        vm.expectEmit(true, false, false, true);
        emit CrossChainWithdrawRequest(KATANA_DOMAIN, withdrawAmount);

        vm.prank(address(mailbox));
        messenger.handle(KATANA_DOMAIN, bytes32(uint256(uint160(childVaultKatana))), withdrawRequest);

        // Step 3: Simulate CCTP bridge completing the withdrawal
        vm.prank(address(cctpBridge));
        motherVault.handleCCTPReceive(withdrawAmount, KATANA_DOMAIN, bytes32(uint256(1)));

        // Step 4: Verify accounting after withdrawal
        assertEq(motherVault.getCurrentBuffer(), bufferBefore + withdrawAmount, "Buffer should increase by withdrawal");
        assertEq(
            motherVault.totalDeployedAssets(), deployedBefore - withdrawAmount, "Deployed should decrease by withdrawal"
        );

        IMotherVault.ChildVault memory childVault = motherVault.getChildVault(KATANA_DOMAIN);
        assertEq(childVault.deployedAmount, deployAmount - withdrawAmount, "Child vault deployed should decrease");
    }

    /**
     * @notice Test multiple concurrent cross-domain operations
     * @dev Ensures system handles overlapping deposit/withdraw requests
     */
    function test_Messenger_ConcurrentOperations() public {
        uint256 initialDeposit = 1000e6;
        uint256 deployEthereumSepolia = 400e6;
        uint256 deployKatana = 300e6;
        uint256 withdrawEthereumSepolia = 150e6;
        uint256 redeployKatana = 200e6;

        // Initial setup
        vm.startPrank(user);
        usdc.approve(address(motherVault), initialDeposit);
        motherVault.deposit(initialDeposit, user);
        vm.stopPrank();

        // Deploy to both child vaults
        vm.startPrank(admin);
        motherVault.deployToChildVault(ETHEREUM_SEPOLIA_DOMAIN, deployEthereumSepolia);
        motherVault.deployToChildVault(KATANA_DOMAIN, deployKatana);
        vm.stopPrank();

        uint256 totalAssetsBefore = motherVault.totalAssets();

        // Concurrent operations:
        // 1. Withdraw from Arbitrum
        vm.prank(address(cctpBridge));
        motherVault.handleCCTPReceive(withdrawEthereumSepolia, ETHEREUM_SEPOLIA_DOMAIN, bytes32(uint256(2)));

        // 2. Redeploy to Katana
        vm.prank(admin);
        motherVault.deployToChildVault(KATANA_DOMAIN, redeployKatana);

        // Verify final state
        IMotherVault.ChildVault memory ethereumSepoliaVault = motherVault.getChildVault(ETHEREUM_SEPOLIA_DOMAIN);
        IMotherVault.ChildVault memory katanaVault = motherVault.getChildVault(KATANA_DOMAIN);

        assertEq(ethereumSepoliaVault.deployedAmount, deployEthereumSepolia - withdrawEthereumSepolia, "Ethereum Sepolia should reflect withdrawal");
        assertEq(katanaVault.deployedAmount, deployKatana + redeployKatana, "Katana should reflect redeployment");
        assertEq(motherVault.totalAssets(), totalAssetsBefore, "Total assets should remain constant");
    }

    /**
     * @notice Test messenger error handling for unauthorized callers
     * @dev Ensures only authorized addresses can trigger cross-domain operations
     */
    function test_Messenger_UnauthorizedAccess() public {
        address attacker = address(0x666);
        uint256 amount = 100e6;

        // Attempt unauthorized withdrawal request
        bytes memory withdrawRequest = abi.encode(ICrossChainMessenger.MessageType.WITHDRAWAL_REQUEST, amount, attacker);

        // Should revert for unauthorized caller
        vm.expectRevert();
        vm.prank(address(mailbox));
        messenger.handle(ETHEREUM_SEPOLIA_DOMAIN, bytes32(uint256(uint160(attacker))), withdrawRequest);
    }

    /**
     * @notice Test messenger handling of yield reporting
     * @dev Verifies yield updates are properly processed via messenger
     */
    function test_Messenger_YieldReporting() public {
        uint256 deployAmount = 500e6;
        uint256 yieldAmount = 25e6; // 5% yield
        uint16 apyBps = 500; // 5% APY

        // Deploy funds to child vault
        vm.startPrank(user);
        usdc.approve(address(motherVault), deployAmount);
        motherVault.deposit(deployAmount, user);
        vm.stopPrank();

        vm.prank(admin);
        motherVault.deployToChildVault(ETHEREUM_SEPOLIA_DOMAIN, deployAmount);

        // Simulate yield report from child vault via messenger
        bytes memory yieldReport =
            abi.encode(ICrossChainMessenger.MessageType.YIELD_REPORT, apyBps, deployAmount + yieldAmount);

        uint256 totalAssetsBefore = motherVault.totalAssets();

        // Process yield report
        vm.prank(address(mailbox));
        messenger.handle(ETHEREUM_SEPOLIA_DOMAIN, bytes32(uint256(uint160(childVaultEthereumSepolia))), yieldReport);

        // Verify yield is recorded
        IMotherVault.ChildVault memory childVault = motherVault.getChildVault(ETHEREUM_SEPOLIA_DOMAIN);
        assertEq(childVault.reportedAPY, apyBps, "APY should be updated");
        assertTrue(childVault.lastReportTime > 0, "Update timestamp should be set");
    }

    /**
     * @notice Test messenger retry mechanism for failed messages
     * @dev Ensures failed messages can be retried
     */
    function test_Messenger_MessageRetry() public {
        uint256 deployAmount = 300e6;
        bytes32 messageId = bytes32(uint256(0x123));

        // Setup deployment
        vm.startPrank(user);
        usdc.approve(address(motherVault), deployAmount);
        motherVault.deposit(deployAmount, user);
        vm.stopPrank();

        // Store initial state
        uint256 bufferBefore = motherVault.getCurrentBuffer();

        // Attempt deployment (simulate initial message)
        vm.prank(admin);
        motherVault.deployToChildVault(ETHEREUM_SEPOLIA_DOMAIN, deployAmount);

        // Simulate retry of deployment message
        bytes memory retryMessage =
            abi.encode(ICrossChainMessenger.MessageType.DEPOSIT_REQUEST, deployAmount, address(motherVault));

        // Retry should be idempotent
        vm.prank(address(mailbox));
        messenger.handle(BASE_SEPOLIA_DOMAIN, bytes32(uint256(uint160(address(motherVault)))), retryMessage);

        // Verify no double accounting
        IMotherVault.ChildVault memory childVault = motherVault.getChildVault(ETHEREUM_SEPOLIA_DOMAIN);
        assertEq(childVault.deployedAmount, deployAmount, "Deployment should not be duplicated");
        assertEq(motherVault.getCurrentBuffer(), bufferBefore - deployAmount, "Buffer should only decrease once");
    }

    /**
     * @notice Fuzz test for cross-domain operation consistency
     * @dev Ensures messenger operations maintain invariants
     */
    function testFuzz_Messenger_OperationConsistency(
        uint256 depositAmount,
        uint256 deployAmount,
        uint256 withdrawAmount
    )
        public
    {
        depositAmount = bound(depositAmount, 100e6, 2000e6);
        deployAmount = bound(deployAmount, 50e6, depositAmount);
        withdrawAmount = bound(withdrawAmount, 10e6, deployAmount);

        // Setup
        vm.startPrank(user);
        usdc.approve(address(motherVault), depositAmount);
        motherVault.deposit(depositAmount, user);
        vm.stopPrank();

        // Deploy
        vm.prank(admin);
        motherVault.deployToChildVault(KATANA_DOMAIN, deployAmount);

        uint256 totalBefore = motherVault.totalAssets();

        // Withdraw via messenger flow
        vm.prank(address(cctpBridge));
        motherVault.handleCCTPReceive(withdrawAmount, KATANA_DOMAIN, bytes32(uint256(99)));

        // Verify invariants
        assertEq(motherVault.totalAssets(), totalBefore, "Total assets should remain constant");
        assertEq(
            motherVault.getCurrentBuffer() + motherVault.totalDeployedAssets(),
            totalBefore,
            "Accounting equation should hold"
        );
        assertEq(
            motherVault.getChildVault(KATANA_DOMAIN).deployedAmount,
            deployAmount - withdrawAmount,
            "Child vault tracking should be accurate"
        );
    }
}
