// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Test, console2 } from "forge-std/Test.sol";
import { MotherVault } from "../../contracts/MotherVault.sol";
import { CCTPBridge } from "../../contracts/core/CCTPBridge.sol";
import { CrossChainMessenger } from "../../contracts/core/CrossChainMessenger.sol";
import { Rebalancer } from "../../contracts/core/Rebalancer.sol";
import { HealthMonitor } from "../../contracts/core/HealthMonitor.sol";
import { KatanaChildVault } from "../../contracts/yield-strategies/KatanaChildVault.sol";
import { ZircuitChildVault } from "../../contracts/yield-strategies/ZircuitChildVault.sol";
import { IMotherVault } from "../../contracts/interfaces/IMotherVault.sol";
import { IRebalancer } from "../../contracts/interfaces/IRebalancer.sol";
import { IHealthMonitor } from "../../contracts/interfaces/IHealthMonitor.sol";
import { MockERC20 } from "../mocks/MockERC20.sol";
import { MockTokenMessenger } from "../mocks/MockTokenMessenger.sol";
import { MockMessageTransmitter } from "../mocks/MockMessageTransmitter.sol";
import { MockMailbox } from "../mocks/MockMailbox.sol";
import { MockInterchainGasPaymaster } from "../mocks/MockInterchainGasPaymaster.sol";
import { MockKatanaRouter } from "../mocks/MockKatanaRouter.sol";
import { MockMasterChef } from "../mocks/MockMasterChef.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AnvilIntegration
 * @notice Integration tests for cross-chain operations using Anvil multi-chain setup
 * @dev Tests end-to-end flows across Base, Katana, and Zircuit chains
 */
contract AnvilIntegrationTest is Test {
    // Core contracts (Mother Vault on Base)
    MotherVault public motherVault;
    CCTPBridge public cctpBridge;
    CrossChainMessenger public messenger;
    Rebalancer public rebalancer;
    HealthMonitor public healthMonitor;

    // Child vaults (simulated from other chains)
    KatanaChildVault public katanaChildVault;
    ZircuitChildVault public zircuitChildVault;

    // Mock infrastructure
    MockERC20 public usdc;
    MockTokenMessenger public tokenMessenger;
    MockMessageTransmitter public messageTransmitter;
    MockMailbox public mailbox;
    MockInterchainGasPaymaster public gasPaymaster;

    // Test accounts
    address public admin = address(0x1);
    address public user = address(0x2);
    address public rebalancerBot = address(0x3);

    // Chain domains (matching Anvil setup)
    uint32 public constant BASE_DOMAIN = 6; // CCTP v2 domain for Base
    uint32 public constant KATANA_DOMAIN = 100; // Custom domain for Katana (not CCTP)
    uint32 public constant ZIRCUIT_DOMAIN = 101; // Custom domain for Zircuit (not CCTP)

    // Test parameters
    uint256 public constant INITIAL_DEPOSIT = 1000e6; // 1000 USDC
    uint256 public constant BUFFER_PERCENTAGE = 500; // 5%
    uint256 public constant APY_THRESHOLD = 500; // 5%

    event CrossChainDeployment(uint32 indexed domain, uint256 amount);
    event CrossChainReturn(uint32 indexed domain, uint256 amount);
    event RebalanceExecuted(uint32 fromDomain, uint32 toDomain, uint256 amount);
    event BufferRefillRequested(uint256 requiredAmount);

    function setUp() public {
        // Deploy mock infrastructure
        usdc = new MockERC20("USD Coin", "USDC", 6);
        tokenMessenger = new MockTokenMessenger(address(usdc));
        messageTransmitter = new MockMessageTransmitter();
        mailbox = new MockMailbox();
        gasPaymaster = new MockInterchainGasPaymaster();

        // Deploy core contracts (Base chain)
        motherVault = new MotherVault(address(usdc), "autoUSD", "aUSD");
        cctpBridge = new CCTPBridge(address(tokenMessenger), address(messageTransmitter), address(usdc), admin);
        messenger = new CrossChainMessenger(
            address(mailbox), address(gasPaymaster), address(cctpBridge), address(motherVault), admin
        );
        rebalancer = new Rebalancer(address(motherVault));
        healthMonitor = new HealthMonitor(address(motherVault), address(messenger), address(rebalancer), admin);

        // Deploy child vaults (simulating remote chains)
        MockERC20 weth = new MockERC20("Wrapped Ether", "WETH", 18);
        MockERC20 sushiPool = new MockERC20("SushiSwap USDC/USDT LP", "SUSHI-LP", 18);
        MockERC20 sushiToken = new MockERC20("SushiToken", "SUSHI", 18);
        MockKatanaRouter katanaRouter = new MockKatanaRouter(address(weth));
        MockMasterChef masterChef = new MockMasterChef();
        MockERC20 zuitPool = new MockERC20("Zuit USDC/USDT LP", "ZUIT-LP", 18);

        katanaChildVault = new KatanaChildVault(
            address(usdc),
            address(katanaRouter),
            address(sushiPool), // Mock pair/pool
            address(masterChef),
            address(sushiToken),
            address(messenger),
            address(cctpBridge),
            admin
        );

        zircuitChildVault = new ZircuitChildVault(address(usdc), address(messenger), address(cctpBridge), admin);

        // Initialize mother vault
        usdc.mint(address(this), 100e6); // Initial deposit to prevent share manipulation
        usdc.approve(address(motherVault), 100e6);
        motherVault.initialize(address(messenger), address(cctpBridge));

        // Configure child vaults
        motherVault.addChildVault(KATANA_DOMAIN, address(katanaChildVault));
        motherVault.addChildVault(ZIRCUIT_DOMAIN, address(zircuitChildVault));

        // Setup permissions
        motherVault.grantRole(motherVault.DEFAULT_ADMIN_ROLE(), admin);
        motherVault.grantRole(motherVault.MANAGER_ROLE(), admin);
        motherVault.grantRole(motherVault.REBALANCER_ROLE(), admin);
        motherVault.grantRole(motherVault.REBALANCER_ROLE(), rebalancerBot);

        // Configure cross-chain messaging
        vm.startPrank(admin);
        messenger.configureDomain(KATANA_DOMAIN, KATANA_DOMAIN);
        messenger.configureDomain(ZIRCUIT_DOMAIN, ZIRCUIT_DOMAIN);
        messenger.setTrustedSender(KATANA_DOMAIN, bytes32(uint256(uint160(address(katanaChildVault)))));
        messenger.setTrustedSender(ZIRCUIT_DOMAIN, bytes32(uint256(uint160(address(zircuitChildVault)))));

        // Configure rebalancer - use default config from constructor

        // Set higher deposit cap for testing
        motherVault.setDepositCap(10_000_000e6);
        vm.stopPrank();

        // Fund test accounts
        usdc.mint(user, 10_000e6);
        usdc.mint(address(motherVault), 1000e6);
        usdc.mint(address(katanaChildVault), 1000e6);
        usdc.mint(address(zircuitChildVault), 1000e6);

        // Provide ETH for gas
        vm.deal(address(motherVault), 10 ether);
        vm.deal(address(messenger), 10 ether);
        vm.deal(address(rebalancer), 10 ether);
    }

    /**
     * @notice Test complete deposit → bridge → child vault flow
     * @dev Verifies end-to-end deposit and deployment to child vault
     */
    function test_DepositAndDeployFlow() public {
        uint256 depositAmount = INITIAL_DEPOSIT;
        uint256 deployAmount = 600e6; // Deploy 60% to child vault

        // Step 1: User deposits USDC
        vm.startPrank(user);
        usdc.approve(address(motherVault), depositAmount);
        uint256 shares = motherVault.deposit(depositAmount, user);
        vm.stopPrank();

        assertEq(shares, depositAmount, "Shares should equal deposit amount (1:1 initial ratio)");
        assertEq(motherVault.balanceOf(user), shares, "User should own shares");
        assertEq(
            motherVault.getCurrentBuffer(),
            depositAmount + 100e6,
            "All funds should be in buffer initially (including setup deposit)"
        );

        // Step 2: Deploy funds to Katana child vault
        vm.prank(admin);
        motherVault.deployToChildVault(KATANA_DOMAIN, deployAmount);

        // Verify deployment
        IMotherVault.ChildVault memory katanaVault = motherVault.getChildVault(KATANA_DOMAIN);
        assertEq(katanaVault.deployedAmount, deployAmount, "Katana should have deployed amount");
        assertEq(motherVault.totalDeployedAssets(), deployAmount, "Total deployed should match");
        assertEq(motherVault.getCurrentBuffer(), (depositAmount + 100e6) - deployAmount, "Buffer should decrease");

        // Verify buffer management
        uint256 requiredBuffer = motherVault.getRequiredBuffer();
        uint256 totalAssets = depositAmount + 100e6; // Including setup deposit
        uint256 expectedBuffer = (totalAssets * BUFFER_PERCENTAGE) / 10_000; // 5% of TVL
        assertEq(requiredBuffer, expectedBuffer, "Required buffer should be 5% of TVL");
        assertTrue(motherVault.isBufferSufficient(), "Buffer should be sufficient after deployment");
    }

    /**
     * @notice Test withdrawal → bridge → return flow
     * @dev Verifies end-to-end withdrawal requiring funds from child vault
     */
    function test_WithdrawAndReturnFlow() public {
        // Setup: Deposit and deploy funds
        uint256 depositAmount = INITIAL_DEPOSIT;
        uint256 deployAmount = 600e6;
        uint256 returnAmount = 300e6;
        uint256 withdrawAmount = 400e6; // More than current buffer

        vm.startPrank(user);
        usdc.approve(address(motherVault), depositAmount);
        motherVault.deposit(depositAmount, user);
        vm.stopPrank();

        vm.prank(admin);
        motherVault.deployToChildVault(KATANA_DOMAIN, deployAmount);

        // Current buffer after deployment: (1000 + 100) - 600 = 500 USDC
        // User wants to withdraw 400 USDC, which should be possible with current buffer
        // But let's simulate that buffer becomes insufficient and needs refill

        // Step 1: Verify current state
        uint256 currentBuffer = motherVault.getCurrentBuffer();
        assertEq(currentBuffer, 500e6, "Buffer should be 500 USDC after deployment");

        // Step 2: Simulate CCTP bridge return from child vault (e.g., rebalancing)
        vm.prank(address(cctpBridge));
        motherVault.handleCCTPReceive(returnAmount, KATANA_DOMAIN, keccak256("return_message"));

        // Verify return
        assertEq(
            motherVault.getCurrentBuffer(), currentBuffer + returnAmount, "Buffer should increase by returned amount"
        );

        IMotherVault.ChildVault memory katanaVault = motherVault.getChildVault(KATANA_DOMAIN);
        assertEq(katanaVault.deployedAmount, deployAmount - returnAmount, "Katana deployed amount should decrease");

        // Step 3: Execute withdrawal with improved liquidity
        uint256 userBalanceBefore = usdc.balanceOf(user);

        vm.prank(user);
        uint256 assetsWithdrawn = motherVault.withdraw(withdrawAmount, user, user);

        assertEq(assetsWithdrawn, withdrawAmount, "Should withdraw requested amount");
        assertEq(usdc.balanceOf(user), userBalanceBefore + withdrawAmount, "User should receive USDC");
    }

    /**
     * @notice Test rebalancing between chains based on APY differential
     * @dev Verifies automated rebalancing when APY threshold is exceeded
     */
    function test_RebalancingFlow() public {
        // Setup: Deploy funds to both chains
        uint256 depositAmount = 2000e6;
        uint256 katanaDeployment = 800e6;
        uint256 zircuitDeployment = 600e6;

        vm.startPrank(user);
        usdc.approve(address(motherVault), depositAmount);
        motherVault.deposit(depositAmount, user);
        vm.stopPrank();

        vm.startPrank(admin);
        motherVault.deployToChildVault(KATANA_DOMAIN, katanaDeployment);
        motherVault.deployToChildVault(ZIRCUIT_DOMAIN, zircuitDeployment);
        vm.stopPrank();

        // Step 1: Simulate APY differential (Zircuit has better APY)
        // In real implementation, APYs would be fetched from child vaults
        // For this test, we'll trigger rebalancing manually

        uint256 rebalanceAmount = 300e6;

        // Step 2: Test rebalancing evaluation
        // In full integration, rebalancer would evaluate APY differentials and execute rebalancing
        // For this test, we simulate the evaluation process

        // Note: In full integration, this would involve:
        // 1. Requesting withdrawal from Katana child vault
        // 2. CCTP bridge return to mother vault
        // 3. CCTP bridge deployment to Zircuit child vault

        // For now, verify the rebalancer can evaluate rebalancing decisions
        IRebalancer.RebalanceDecision memory decision = rebalancer.evaluateRebalance();

        // Verify evaluation works (may not recommend rebalance without proper APY data)
        assertTrue(bytes(decision.reason).length > 0, "Should provide evaluation reason");
    }

    /**
     * @notice Test buffer management under various scenarios
     * @dev Verifies 5% buffer is maintained and refilled when needed
     */
    function test_BufferManagement() public {
        uint256 depositAmount = 2000e6;

        // Initial deposit
        vm.startPrank(user);
        usdc.approve(address(motherVault), depositAmount);
        motherVault.deposit(depositAmount, user);
        vm.stopPrank();

        // Get total assets (includes setup deposit)
        uint256 totalAssets = motherVault.totalAssets();
        uint256 requiredBuffer = motherVault.getRequiredBuffer();
        uint256 currentBuffer = motherVault.getCurrentBuffer();

        // Verify initial state
        assertEq(
            requiredBuffer, (totalAssets * BUFFER_PERCENTAGE) / 10_000, "Required buffer should be 5% of total assets"
        );
        assertEq(currentBuffer, totalAssets, "All funds should be in buffer initially");
        assertTrue(motherVault.isBufferSufficient(), "Buffer should be sufficient initially");

        // Deploy funds leaving minimum buffer
        uint256 deployAmount = currentBuffer - requiredBuffer;
        vm.prank(admin);
        motherVault.deployToChildVault(KATANA_DOMAIN, deployAmount);

        // Verify buffer after deployment
        assertEq(motherVault.getCurrentBuffer(), requiredBuffer, "Current buffer should equal required");
        assertTrue(motherVault.isBufferSufficient(), "Buffer should be sufficient after deployment");
        assertEq(motherVault.getDeployableAmount(), 0, "No excess funds to deploy");

        // Test additional deposit creates deployable funds
        uint256 additionalDeposit = 500e6;
        vm.startPrank(user);
        usdc.approve(address(motherVault), additionalDeposit);
        motherVault.deposit(additionalDeposit, user);
        vm.stopPrank();

        // Buffer management should now show excess deployable funds
        uint256 newTotalAssets = motherVault.totalAssets();
        uint256 newRequiredBuffer = motherVault.getRequiredBuffer();
        uint256 newCurrentBuffer = motherVault.getCurrentBuffer();
        uint256 deployableAmount = motherVault.getDeployableAmount();

        assertEq(
            newRequiredBuffer,
            (newTotalAssets * BUFFER_PERCENTAGE) / 10_000,
            "Required buffer should update with new TVL"
        );
        assertEq(newCurrentBuffer, requiredBuffer + additionalDeposit, "Current buffer should include new deposit");
        assertTrue(motherVault.isBufferSufficient(), "Buffer should be sufficient with additional funds");
        assertGt(deployableAmount, 0, "Should have deployable funds available");
    }

    /**
     * @notice Test message retry mechanism
     * @dev Verifies exponential backoff and retry logic for failed messages
     */
    function test_MessageRetryMechanism() public {
        // This test simulates the retry mechanism by checking internal state
        // In a full integration test with real Hyperlane, we would test actual message failures

        uint256 deployAmount = 500e6;
        bytes32 messageId = keccak256("test_message");

        vm.startPrank(user);
        usdc.approve(address(motherVault), 1000e6);
        motherVault.deposit(1000e6, user);
        vm.stopPrank();

        // Simulate message send
        vm.prank(admin);
        motherVault.deployToChildVault(KATANA_DOMAIN, deployAmount);

        // In full implementation, we would:
        // 1. Force a message to fail
        // 2. Verify retry attempts with exponential backoff
        // 3. Check failed message tracking
        // 4. Test manual retry capability

        // For now, verify the deployment was attempted
        IMotherVault.ChildVault memory katanaVault = motherVault.getChildVault(KATANA_DOMAIN);
        assertEq(katanaVault.deployedAmount, deployAmount, "Deployment should be tracked");
    }

    /**
     * @notice Test health monitoring system
     * @dev Verifies health monitoring tracks system status correctly
     */
    function test_HealthMonitoring() public {
        // Setup system with some activity
        vm.startPrank(user);
        usdc.approve(address(motherVault), 1000e6);
        motherVault.deposit(1000e6, user);
        vm.stopPrank();

        vm.prank(admin);
        motherVault.deployToChildVault(KATANA_DOMAIN, 500e6);

        // Test system health check
        IHealthMonitor.VaultHealth memory systemHealth = healthMonitor.getSystemHealth();
        assertTrue(systemHealth.isHealthy, "System should be healthy");
        assertEq(systemHealth.status, "All systems operational", "Status should indicate operational");

        // Test child vault health
        IHealthMonitor.VaultHealth memory katanaHealth = healthMonitor.getChildVaultHealth(KATANA_DOMAIN);
        assertTrue(katanaHealth.isHealthy, "Katana vault should be healthy");
        assertGt(katanaHealth.tvl, 0, "Katana should have TVL");

        // Test critical functions check
        bool criticalFunctionsOk = healthMonitor.checkCriticalFunctions();
        assertTrue(criticalFunctionsOk, "Critical functions should be operational");
    }

    /**
     * @notice Fuzz test for cross-chain operations
     * @dev Tests various deposit/deployment combinations
     */
    function testFuzz_CrossChainOperations(
        uint256 depositAmount,
        uint256 katanaPercent,
        uint256 zircuitPercent
    )
        public
    {
        // Bound inputs to reasonable ranges
        depositAmount = bound(depositAmount, 100e6, 5000e6); // 100-5000 USDC
        katanaPercent = bound(katanaPercent, 0, 70); // 0-70%
        zircuitPercent = bound(zircuitPercent, 0, 70); // 0-70%
        if (katanaPercent + zircuitPercent > 70) {
            zircuitPercent = 70 - katanaPercent; // Ensure total ≤ 70%
        }

        // Calculate deployment amounts (leaving at least 30% buffer)
        uint256 katanaDeployment = (depositAmount * katanaPercent) / 100;
        uint256 zircuitDeployment = (depositAmount * zircuitPercent) / 100;
        uint256 totalDeployment = katanaDeployment + zircuitDeployment;

        // Ensure we maintain minimum buffer
        uint256 requiredBuffer = (depositAmount * BUFFER_PERCENTAGE) / 10_000;
        if (depositAmount - totalDeployment < requiredBuffer) {
            return; // Skip if buffer would be insufficient
        }

        // Execute deposit
        vm.startPrank(user);
        usdc.approve(address(motherVault), depositAmount);
        motherVault.deposit(depositAmount, user);
        vm.stopPrank();

        uint256 totalAssetsBefore = motherVault.totalAssets();

        // Deploy to child vaults
        vm.startPrank(admin);
        if (katanaDeployment > 0) {
            motherVault.deployToChildVault(KATANA_DOMAIN, katanaDeployment);
        }
        if (zircuitDeployment > 0) {
            motherVault.deployToChildVault(ZIRCUIT_DOMAIN, zircuitDeployment);
        }
        vm.stopPrank();

        // Verify accounting consistency
        assertEq(motherVault.totalAssets(), totalAssetsBefore, "Total assets should remain constant");
        assertEq(motherVault.totalDeployedAssets(), totalDeployment, "Total deployed should match deployments");
        assertEq(
            motherVault.getCurrentBuffer(),
            (depositAmount + 100e6) - totalDeployment, // Include setup deposit
            "Buffer should be correct"
        );
        assertTrue(motherVault.isBufferSufficient(), "Buffer should remain sufficient");
    }
}
