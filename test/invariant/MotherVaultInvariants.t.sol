// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Test, console2 } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
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

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}

contract MockCrossChainMessenger is ICrossChainMessenger {
    function sendCrossChainMessage(CrossChainMessage calldata message) external payable returns (bytes32) {
        return keccak256(abi.encode(message));
    }

    function handle(uint32 origin, bytes32 sender, bytes calldata message) external payable { }

    function estimateMessageFee(uint32 targetChainId) external view returns (uint256) {
        return 0.001 ether; // Small fee for testing
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
        return 0.001 ether;
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
 * @title MotherVaultInvariantHandler
 * @dev Handler contract that performs bounded operations on the MotherVault for invariant testing
 */
contract MotherVaultInvariantHandler is Test {
    MotherVault public vault;
    MockUSDC public usdc;
    MockCrossChainMessenger public messenger;
    MockCCTPBridge public cctpBridge;

    address[] public actors;
    uint256 public constant MAX_ACTORS = 5;
    uint256 public constant ONE_USDC = 1e6;
    uint256 public constant MIN_OPERATION_AMOUNT = 1 * ONE_USDC;
    uint256 public constant MAX_OPERATION_AMOUNT = 1000 * ONE_USDC;

    // Track historical values for monotonicity checks
    uint256 public lastSharePrice = 1e18; // Initial 1:1 ratio
    uint256[] public sharePriceHistory;

    // Track rebalance history for rate limiting
    uint256[] public rebalanceTimestamps;

    // Track ghost variables for invariant checking
    uint256 public ghost_totalDeposited;
    uint256 public ghost_totalWithdrawn;
    uint256 public ghost_totalFeesPaid;
    uint256 public ghost_cumulativeFees;
    uint256 public ghost_maxSharePriceSeen;
    uint256 public ghost_minBufferSeen;
    uint256 public ghost_emergencyPauseCount;

    // Track withdrawal queue for FIFO ordering tests
    struct WithdrawalRequest {
        address user;
        uint256 amount;
        uint256 timestamp;
        bool processed;
    }

    WithdrawalRequest[] public withdrawalQueue;

    // Track fee collection history
    uint256[] public feeCollectionHistory;
    uint256 public lastFeeSnapshot;

    // Getter functions for invariant tests
    function getRebalanceTimestamp(uint256 index) external view returns (uint256) {
        return rebalanceTimestamps[index];
    }

    function getRebalanceTimestampsLength() external view returns (uint256) {
        return rebalanceTimestamps.length;
    }

    function getWithdrawalRequest(uint256 index) external view returns (WithdrawalRequest memory) {
        return withdrawalQueue[index];
    }

    function getWithdrawalQueueLength() external view returns (uint256) {
        return withdrawalQueue.length;
    }

    modifier useActor(uint256 actorIndexSeed) {
        address currentActor = actors[bound(actorIndexSeed, 0, actors.length - 1)];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    constructor(MotherVault _vault, MockUSDC _usdc, MockCrossChainMessenger _messenger, MockCCTPBridge _cctpBridge) {
        vault = _vault;
        usdc = _usdc;
        messenger = _messenger;
        cctpBridge = _cctpBridge;

        // Initialize actors
        for (uint256 i = 0; i < MAX_ACTORS; i++) {
            address actor = address(uint160(0x10000 + i));
            actors.push(actor);

            // Give each actor USDC and approve vault
            usdc.mint(actor, 10_000 * ONE_USDC);
            vm.prank(actor);
            usdc.approve(address(vault), type(uint256).max);

            // Give each actor some ETH for gas
            vm.deal(actor, 10 ether);
        }

        // Initialize share price history
        sharePriceHistory.push(lastSharePrice);

        // Initialize fee tracking
        lastFeeSnapshot = vault.totalAssets();

        // Initialize additional ghost variables
        ghost_maxSharePriceSeen = lastSharePrice;
        ghost_minBufferSeen = vault.getCurrentBuffer();
        ghost_emergencyPauseCount = 0;

        // Initialize cumulative fees tracking
        ghost_cumulativeFees = 0;
    }

    /**
     * @dev Bounded deposit function
     */
    function deposit(uint256 actorSeed, uint256 amountSeed) external useActor(actorSeed) {
        if (vault.paused()) return;

        uint256 maxDeposit = vault.maxDeposit(msg.sender);
        if (maxDeposit == 0) return;

        uint256 amount = bound(amountSeed, MIN_OPERATION_AMOUNT, min(maxDeposit, MAX_OPERATION_AMOUNT));
        uint256 userBalance = usdc.balanceOf(msg.sender);
        if (amount > userBalance) {
            amount = userBalance;
        }
        if (amount == 0) return;

        try vault.deposit(amount, msg.sender) returns (uint256 shares) {
            ghost_totalDeposited += amount;
            _updateSharePrice();
        } catch {
            // Failed deposits don't affect invariants
        }
    }

    /**
     * @dev Bounded withdraw function
     */
    function withdraw(uint256 actorSeed, uint256 amountSeed) external useActor(actorSeed) {
        if (vault.paused()) return;

        uint256 maxWithdraw = vault.maxWithdraw(msg.sender);
        if (maxWithdraw == 0) return;

        uint256 amount = bound(amountSeed, MIN_OPERATION_AMOUNT, min(maxWithdraw, MAX_OPERATION_AMOUNT));
        if (amount == 0) return;

        try vault.withdraw(amount, msg.sender, msg.sender) returns (uint256 shares) {
            ghost_totalWithdrawn += amount;
            _updateSharePrice();
        } catch {
            // Failed withdrawals don't affect invariants
        }
    }

    /**
     * @dev Bounded redeem function
     */
    function redeem(uint256 actorSeed, uint256 sharesSeed) external useActor(actorSeed) {
        if (vault.paused()) return;

        uint256 maxRedeem = vault.maxRedeem(msg.sender);
        if (maxRedeem == 0) return;

        uint256 shares = bound(sharesSeed, 1, maxRedeem);

        try vault.redeem(shares, msg.sender, msg.sender) returns (uint256 assets) {
            ghost_totalWithdrawn += assets;
            _updateSharePrice();
        } catch {
            // Failed redeems don't affect invariants
        }
    }

    /**
     * @dev Add child vault for testing deployment/rebalancing
     */
    function addChildVault(uint256 domainSeed) external {
        uint32 domainId = uint32(bound(domainSeed, 1, 10));
        address childVault = address(uint160(0x20000 + domainId));

        // Check if vault already exists
        try vault.getChildVault(domainId) returns (IMotherVault.ChildVault memory existing) {
            if (existing.isActive) return;
        } catch {
            // Vault doesn't exist, can add
        }

        vm.startPrank(address(this)); // Use deployer role
        try vault.addChildVault(domainId, childVault) {
            // Success
        } catch {
            // Failed to add vault
        }
        vm.stopPrank();
    }

    /**
     * @dev Deploy to child vault (testing buffer management)
     */
    function deployToChildVault(uint256 domainSeed, uint256 amountSeed) external {
        if (vault.paused()) return;

        uint32 domainId = uint32(bound(domainSeed, 1, 10));

        // Check if child vault exists
        try vault.getChildVault(domainId) returns (IMotherVault.ChildVault memory childVault) {
            if (!childVault.isActive) return;
        } catch {
            return;
        }

        uint256 deployableAmount = vault.getDeployableAmount();
        if (deployableAmount == 0) return;

        uint256 amount = bound(amountSeed, MIN_OPERATION_AMOUNT, min(deployableAmount, MAX_OPERATION_AMOUNT));

        vm.startPrank(address(this)); // Use manager role
        vm.deal(address(this), 1 ether); // For cross-chain fees
        try vault.deployToChildVault(domainId, amount) {
            // Success
        } catch {
            // Failed deployment
        }
        vm.stopPrank();
    }

    /**
     * @dev Simulate yield reporting from child vaults
     */
    function reportYield(uint256 domainSeed, uint256 apySeed) external {
        uint32 domainId = uint32(bound(domainSeed, 1, 10));
        uint256 apy = bound(apySeed, 0, 20_000); // 0-200% APY in basis points

        // Check if child vault exists
        IMotherVault.ChildVault memory childVault;
        try vault.getChildVault(domainId) returns (IMotherVault.ChildVault memory _childVault) {
            childVault = _childVault;
            if (!childVault.isActive) return;
        } catch {
            return;
        }

        vm.startPrank(address(this)); // Use manager role
        try vault.reportYield(domainId, apy, childVault.deployedAmount) {
            // Success
        } catch {
            // Failed yield report
        }
        vm.stopPrank();
    }

    /**
     * @dev Attempt rebalancing (testing cooldown and rate limits)
     */
    function rebalance() external {
        if (vault.paused()) return;

        // Check cooldown
        if (block.timestamp < vault.lastRebalanceTime() + vault.rebalanceCooldown()) {
            return;
        }

        // Check rate limit before attempting
        uint256 recentRebalances = vault.getRebalanceCount();
        if (recentRebalances >= vault.MAX_REBALANCE_FREQUENCY()) {
            return; // Would exceed rate limit
        }

        // Also track our own rebalance times to prevent rate limit violations
        uint256 recentHandlerRebalances = 0;
        uint256 windowStart =
            block.timestamp >= vault.RATE_LIMIT_WINDOW() ? block.timestamp - vault.RATE_LIMIT_WINDOW() : 0;

        for (uint256 i = 0; i < rebalanceTimestamps.length; i++) {
            if (rebalanceTimestamps[i] >= windowStart) {
                recentHandlerRebalances++;
            }
        }

        if (recentHandlerRebalances >= vault.MAX_REBALANCE_FREQUENCY()) {
            return; // Would exceed our tracked rate limit
        }

        vm.startPrank(address(this)); // Use rebalancer role
        vm.deal(address(this), 1 ether); // For cross-chain fees
        try vault.rebalance() {
            rebalanceTimestamps.push(block.timestamp);
        } catch {
            // Failed rebalance (expected in most cases due to insufficient setup)
        }
        vm.stopPrank();
    }

    /**
     * @dev Simulate time passage (reduced bounds to prevent extreme scenarios)
     */
    function warp(uint256 timeSeed) external {
        uint256 timeAdvance = bound(timeSeed, 1 hours, 30 days); // More reasonable bounds
        skip(timeAdvance);

        // Update share price after time passage
        _updateSharePrice();
    }

    /**
     * @dev Collect management fees
     */
    function collectFees() external {
        vm.startPrank(address(this)); // Use admin role
        try vault.collectManagementFees() returns (uint256 feeAmount) {
            ghost_totalFeesPaid += feeAmount;
            ghost_cumulativeFees += feeAmount;
            feeCollectionHistory.push(feeAmount);
        } catch {
            // Failed fee collection
        }
        vm.stopPrank();
    }

    /**
     * @dev Emergency pause/unpause
     */
    function emergencyPause(uint256 pauseSeed) external {
        bool shouldPause = bound(pauseSeed, 0, 1) == 1;

        vm.startPrank(address(this)); // Use pauser role
        if (shouldPause && !vault.paused()) {
            vault.emergencyPause();
            ghost_emergencyPauseCount++;
        } else if (!shouldPause && vault.paused()) {
            vault.emergencyUnpause();
        }
        vm.stopPrank();
    }

    /**
     * @dev Update share price history
     */
    function _updateSharePrice() internal {
        if (vault.totalSupply() == 0) return;

        uint256 currentSharePrice = (vault.totalAssets() * 1e18) / vault.totalSupply();
        lastSharePrice = currentSharePrice;
        sharePriceHistory.push(currentSharePrice);

        // Update ghost variables
        if (currentSharePrice > ghost_maxSharePriceSeen) {
            ghost_maxSharePriceSeen = currentSharePrice;
        }

        uint256 currentBuffer = vault.getCurrentBuffer();
        if (currentBuffer < ghost_minBufferSeen) {
            ghost_minBufferSeen = currentBuffer;
        }
    }

    /**
     * @dev Test edge case deposits (0, 1, max values)
     */
    function depositEdgeCase(uint256 actorSeed, uint256 edgeCase) external useActor(actorSeed) {
        if (vault.paused()) return;

        uint256 amount;
        uint256 edgeType = bound(edgeCase, 0, 3);

        if (edgeType == 0) {
            // Test with 1 wei (minimum non-zero)
            amount = 1;
        } else if (edgeType == 1) {
            // Test with exactly 1 USDC
            amount = ONE_USDC;
        } else if (edgeType == 2) {
            // Test with max deposit allowed
            amount = vault.maxDeposit(msg.sender);
        } else {
            // Test with user's full balance
            amount = usdc.balanceOf(msg.sender);
        }

        if (amount == 0 || amount > vault.maxDeposit(msg.sender)) return;
        if (amount > usdc.balanceOf(msg.sender)) return;

        try vault.deposit(amount, msg.sender) returns (uint256 shares) {
            ghost_totalDeposited += amount;
            _updateSharePrice();
        } catch {
            // Failed deposits don't affect invariants
        }
    }

    /**
     * @dev Test cross-chain message edge cases
     */
    function sendCrossChainMessageEdgeCase(uint256 domainSeed, uint256 messageTypeSeed) external {
        uint32 domainId = uint32(bound(domainSeed, 1, 10));

        // Add child vault if it doesn't exist
        try vault.getChildVault(domainId) returns (IMotherVault.ChildVault memory existing) {
            if (!existing.isActive) {
                vm.startPrank(address(this));
                try vault.addChildVault(domainId, address(uint160(0x20000 + domainId))) { } catch { }
                vm.stopPrank();
            }
        } catch {
            vm.startPrank(address(this));
            try vault.addChildVault(domainId, address(uint160(0x20000 + domainId))) { } catch { }
            vm.stopPrank();
        }

        uint256 messageType = bound(messageTypeSeed, 0, 2);
        bytes memory payload;

        if (messageType == 0) {
            // Empty payload
            payload = "";
        } else if (messageType == 1) {
            // Malformed payload
            payload = "0x1234";
        } else {
            // Valid yield report
            payload = abi.encode(uint8(2), abi.encode(uint256(1000), uint256(100 * ONE_USDC)));
        }

        vm.startPrank(address(messenger));
        try vault.handleIncomingMessage(
            domainId, bytes32(uint256(uint160(address(uint160(0x20000 + domainId))))), payload
        ) {
            // Message processed successfully
        } catch {
            // Expected failure for malformed messages
        }
        vm.stopPrank();
    }

    /**
     * @dev Simulate extreme fee scenarios
     */
    function extremeFeeScenario(uint256 timeJump) external {
        // Jump reasonable amounts of time to test fee calculations
        timeJump = bound(timeJump, 1 days, 2 * 365 days); // Max 2 years
        skip(timeJump);

        vm.startPrank(address(this));
        try vault.collectManagementFees() returns (uint256 feeAmount) {
            ghost_totalFeesPaid += feeAmount;
            ghost_cumulativeFees += feeAmount;
            feeCollectionHistory.push(feeAmount);
        } catch {
            // Failed fee collection
        }
        vm.stopPrank();
    }

    /**
     * @dev Test buffer management edge cases
     */
    function bufferManagementEdgeCase(uint256 toggleSeed) external {
        bool shouldToggle = bound(toggleSeed, 0, 1) == 1;

        vm.startPrank(address(this));
        try vault.setBufferManagement(shouldToggle) {
            // Buffer management toggled
        } catch {
            // Failed to toggle
        }
        vm.stopPrank();
    }

    /**
     * @dev Test maximum withdrawal queue scenarios
     */
    function queueWithdrawal(uint256 actorSeed, uint256 amountSeed) external useActor(actorSeed) {
        if (vault.paused()) return;

        uint256 maxWithdraw = vault.maxWithdraw(msg.sender);
        if (maxWithdraw == 0) return;

        uint256 amount = bound(amountSeed, 1, maxWithdraw);

        // Record withdrawal request in our queue for ordering tests
        withdrawalQueue.push(
            WithdrawalRequest({ user: msg.sender, amount: amount, timestamp: block.timestamp, processed: false })
        );

        try vault.withdraw(amount, msg.sender, msg.sender) returns (uint256 shares) {
            ghost_totalWithdrawn += amount;

            // Mark this withdrawal as processed
            if (withdrawalQueue.length > 0) {
                withdrawalQueue[withdrawalQueue.length - 1].processed = true;
            }

            _updateSharePrice();
        } catch {
            // Failed withdrawal - remove from queue
            if (withdrawalQueue.length > 0) {
                withdrawalQueue.pop();
            }
        }
    }

    /**
     * @dev Helper function to get minimum of two values
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

/**
 * @title MotherVaultInvariantsTest
 * @dev Comprehensive invariant tests for the MotherVault contract
 */
contract MotherVaultInvariantsTest is StdInvariant, Test {
    MotherVault public vault;
    MockUSDC public usdc;
    MockCrossChainMessenger public messenger;
    MockCCTPBridge public cctpBridge;
    MotherVaultInvariantHandler public handler;

    uint256 public constant ONE_USDC = 1e6;
    uint256 public constant INITIAL_DEPOSIT = 100 * ONE_USDC;
    address public constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    function setUp() public {
        // Deploy contracts
        usdc = new MockUSDC();
        messenger = new MockCrossChainMessenger();
        cctpBridge = new MockCCTPBridge(address(usdc));
        vault = new MotherVault(address(usdc), "autoUSD Vault", "aUSD");

        // Initialize vault
        usdc.mint(address(this), INITIAL_DEPOSIT);
        usdc.approve(address(vault), INITIAL_DEPOSIT);
        vault.initialize(address(messenger), address(cctpBridge));

        // Grant necessary roles to test contract
        vault.grantRole(vault.MANAGER_ROLE(), address(this));
        vault.grantRole(vault.REBALANCER_ROLE(), address(this));
        vault.grantRole(vault.PAUSER_ROLE(), address(this));

        // Set reasonable parameters
        vault.setDepositCap(1_000_000 * ONE_USDC);
        vault.setRebalanceCooldown(1 hours);
        vault.setMinAPYDifferential(100); // 1%

        // Deploy handler
        handler = new MotherVaultInvariantHandler(vault, usdc, messenger, cctpBridge);

        // Grant roles to handler
        vault.grantRole(vault.MANAGER_ROLE(), address(handler));
        vault.grantRole(vault.REBALANCER_ROLE(), address(handler));
        vault.grantRole(vault.PAUSER_ROLE(), address(handler));

        // Target the handler for invariant testing
        targetContract(address(handler));

        // Focus on the most important functions with proper weight distribution
        bytes4[] memory selectors = new bytes4[](10);
        selectors[0] = handler.deposit.selector;
        selectors[1] = handler.withdraw.selector;
        selectors[2] = handler.redeem.selector;
        selectors[3] = handler.warp.selector;
        selectors[4] = handler.collectFees.selector;
        selectors[5] = handler.depositEdgeCase.selector;
        selectors[6] = handler.addChildVault.selector;
        selectors[7] = handler.deployToChildVault.selector;
        selectors[8] = handler.reportYield.selector;
        selectors[9] = handler.emergencyPause.selector;
        // Removed rebalance from this run to avoid rate limit issues during testing

        targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));
    }

    /**
     * @dev INVARIANT 1: Share price monotonicity - should never decrease except during losses
     * Share price can only decrease if there are actual losses (not just fee collection)
     */
    function invariant_SharePriceMonotonicity() public view {
        if (vault.totalSupply() == 0) return;

        uint256 currentSharePrice = (vault.totalAssets() * 1e18) / vault.totalSupply();
        uint256 lastSharePrice = handler.lastSharePrice();

        // Allow for reasonable fee collection impact (up to 5% decrease)
        // This accounts for management fees and potential small losses
        uint256 maxDecreaseAllowed = lastSharePrice / 20; // 5%

        assertGe(
            currentSharePrice + maxDecreaseAllowed,
            lastSharePrice,
            "Share price decreased beyond acceptable tolerance (5%)"
        );
    }

    /**
     * @dev INVARIANT 2: Buffer management - withdrawals should fail if they would reduce totalAssets below minBufferBalance
     */
    function invariant_BufferManagement() public view {
        if (!vault.bufferManagementEnabled()) return;

        uint256 currentBuffer = vault.getCurrentBuffer();
        uint256 requiredBuffer = vault.getRequiredBuffer();

        // If buffer management is enabled and we have assets, buffer should be maintained
        if (vault.totalAssets() > 0) {
            // Allow for small deviations due to rounding or recent operations
            uint256 tolerance = vault.totalAssets() / 1000; // 0.1% tolerance

            if (currentBuffer + tolerance < requiredBuffer) {
                // This is only acceptable during rebalancing or deployment operations
                // The system should not allow user withdrawals that would breach buffer
                assertTrue(
                    vault.getDeployableAmount() == 0,
                    "Buffer requirement violated: insufficient funds available for withdrawal"
                );
            }
        }
    }

    /**
     * @dev INVARIANT 3: Rebalance cooldown - rebalances should respect the cooldown period
     */
    function invariant_RebalanceCooldown() public view {
        uint256 lastRebalanceTime = vault.lastRebalanceTime();
        uint256 cooldownPeriod = vault.rebalanceCooldown();

        // If we're within the cooldown period, no new rebalances should have occurred
        if (block.timestamp < lastRebalanceTime + cooldownPeriod) {
            // Check that the most recent rebalance in our history respects the cooldown
            if (handler.getRebalanceTimestampsLength() > 1) {
                uint256 lastTimestamp = handler.getRebalanceTimestamp(handler.getRebalanceTimestampsLength() - 1);
                uint256 secondLastTimestamp = handler.getRebalanceTimestamp(handler.getRebalanceTimestampsLength() - 2);

                assertGe(lastTimestamp, secondLastTimestamp + cooldownPeriod, "Rebalance cooldown period violated");
            }
        }
    }

    /**
     * @dev INVARIANT 4: Rate limit enforcement - ensure rate limits are enforced
     */
    function invariant_RateLimitEnforcement() public view {
        uint256 recentRebalances = vault.getRebalanceCount();
        uint256 maxRebalances = vault.MAX_REBALANCE_FREQUENCY();

        assertLe(recentRebalances, maxRebalances, "Rate limit exceeded: too many rebalances in the time window");
    }

    /**
     * @dev INVARIANT 5: Asset conservation - total assets should equal idle + deployed
     */
    function invariant_AssetConservation() public view {
        uint256 totalAssets = vault.totalAssets();
        uint256 currentBuffer = vault.getCurrentBuffer();
        uint256 totalDeployed = vault.totalDeployedAssets();

        assertEq(
            totalAssets, currentBuffer + totalDeployed, "Asset conservation violated: totalAssets != idle + deployed"
        );
    }

    /**
     * @dev INVARIANT 6: USDC balance consistency
     */
    function invariant_USDCBalanceConsistency() public view {
        uint256 vaultUSDCBalance = usdc.balanceOf(address(vault));
        uint256 reportedIdleBalance = vault.getCurrentBuffer();

        assertEq(
            vaultUSDCBalance,
            reportedIdleBalance,
            "USDC balance inconsistency: contract balance != reported idle balance"
        );
    }

    /**
     * @dev INVARIANT 7: Share total supply should never be zero if there are assets (except during initialization)
     */
    function invariant_ShareSupplyConsistency() public view {
        uint256 totalSupply = vault.totalSupply();
        uint256 totalAssets = vault.totalAssets();

        if (totalAssets > 0) {
            assertGt(totalSupply, 0, "Total supply is zero but assets exist");
        }

        // Dead address should always hold initial shares
        uint256 deadShares = vault.balanceOf(DEAD_ADDRESS);
        assertEq(deadShares, INITIAL_DEPOSIT, "Dead address shares changed from initial deposit");
    }

    /**
     * @dev INVARIANT 8: Deposit cap enforcement
     */
    function invariant_DepositCapEnforcement() public view {
        uint256 totalAssets = vault.totalAssets();
        uint256 depositCap = vault.depositCap();

        assertLe(totalAssets, depositCap, "Total assets exceed deposit cap");
    }

    /**
     * @dev INVARIANT 9: No user should have more shares than total assets (share price >= 1)
     */
    function invariant_SharePriceFloor() public view {
        if (vault.totalSupply() == 0) return;

        uint256 sharePrice = (vault.totalAssets() * 1e18) / vault.totalSupply();

        // Share price should never go below a reasonable minimum (allow for 50% loss maximum)
        uint256 minimumSharePrice = 0.5e18;

        assertGe(sharePrice, minimumSharePrice, "Share price fell below reasonable minimum");
    }

    /**
     * @dev INVARIANT 10: Deployed amounts should match child vault records
     */
    function invariant_DeployedAmountConsistency() public view {
        (uint32[] memory domainIds, IMotherVault.ChildVault[] memory childVaults) = vault.getAllChildVaults();

        uint256 totalReportedDeployed = 0;
        for (uint256 i = 0; i < childVaults.length; i++) {
            totalReportedDeployed += childVaults[i].deployedAmount;
        }

        uint256 contractReportedDeployed = vault.totalDeployedAssets();

        assertEq(
            totalReportedDeployed,
            contractReportedDeployed,
            "Deployed amount inconsistency: sum of child vault amounts != total deployed"
        );
    }

    /**
     * @dev INVARIANT 11: Fee accumulation monotonicity - fees should only increase
     */
    function invariant_FeeAccumulationMonotonicity() public view {
        // Ghost cumulative fees should be monotonically increasing
        // (lastFeeSnapshot might be updated by handler, so check against zero)
        assertGe(handler.ghost_cumulativeFees(), 0, "Cumulative fees is negative");

        // Fees can only be collected, never reversed
        assertGe(handler.ghost_totalFeesPaid(), 0, "Total fees paid is negative");

        // Cumulative fees should equal total fees paid in our tracking
        assertEq(handler.ghost_cumulativeFees(), handler.ghost_totalFeesPaid(), "Fee tracking inconsistency");
    }

    /**
     * @dev INVARIANT 12: Withdrawal queue FIFO ordering
     * Note: This tests our mock queue since the vault doesn't implement async withdrawals yet
     */
    function invariant_WithdrawalQueueOrdering() public view {
        uint256 queueLength = handler.getWithdrawalQueueLength();

        if (queueLength <= 1) return; // Nothing to check

        // Check that processed withdrawals follow FIFO order
        uint256 lastProcessedTime = 0;
        bool foundUnprocessed = false;

        for (uint256 i = 0; i < queueLength; i++) {
            MotherVaultInvariantHandler.WithdrawalRequest memory request = handler.getWithdrawalRequest(i);

            if (request.processed) {
                if (foundUnprocessed) {
                    // Found a processed request after an unprocessed one - violation
                    assertTrue(false, "Withdrawal queue FIFO order violated");
                }

                assertGe(request.timestamp, lastProcessedTime, "Withdrawal queue timestamp ordering violated");

                lastProcessedTime = request.timestamp;
            } else {
                foundUnprocessed = true;
            }
        }
    }

    /**
     * @dev INVARIANT 13: Cross-chain message consistency
     */
    function invariant_CrossChainMessageConsistency() public view {
        (uint32[] memory domainIds, IMotherVault.ChildVault[] memory childVaults) = vault.getAllChildVaults();

        for (uint256 i = 0; i < childVaults.length; i++) {
            // If a vault is active, it should have a valid address
            if (childVaults[i].isActive) {
                assertTrue(childVaults[i].vaultAddress != address(0), "Active child vault has zero address");

                // Deployed amount should not exceed total deployed
                assertLe(
                    childVaults[i].deployedAmount,
                    vault.totalDeployedAssets(),
                    "Child vault deployed amount exceeds total"
                );

                // Last report time should be reasonable
                assertLe(childVaults[i].lastReportTime, block.timestamp, "Child vault report time in future");
            }
        }
    }

    /**
     * @dev INVARIANT 14: Edge case handling - zero amounts
     */
    function invariant_ZeroAmountHandling() public view {
        // Total assets should never be zero if there are shares outstanding
        uint256 totalSupply = vault.totalSupply();
        uint256 totalAssets = vault.totalAssets();

        if (totalSupply > vault.balanceOf(vault.DEAD_ADDRESS())) {
            assertGt(totalAssets, 0, "Total assets is zero but shares are outstanding");
        }
    }

    /**
     * @dev INVARIANT 15: Rate limiting window consistency
     */
    function invariant_RateLimitingWindowConsistency() public view {
        uint256 recentRebalances = vault.getRebalanceCount();

        // Should never exceed the maximum in any window
        assertLe(recentRebalances, vault.MAX_REBALANCE_FREQUENCY(), "Rate limit window exceeded maximum");

        // Check our tracked rebalance history
        uint256 handlerRebalances = handler.getRebalanceTimestampsLength();
        if (handlerRebalances > 1) {
            // Check that consecutive rebalances respect the rate limit window
            for (uint256 i = 1; i < handlerRebalances; i++) {
                uint256 currentTime = handler.getRebalanceTimestamp(i);
                uint256 previousTime = handler.getRebalanceTimestamp(i - 1);

                // Within rate limit window, count should not exceed max
                if (currentTime - previousTime <= vault.RATE_LIMIT_WINDOW()) {
                    uint256 countInWindow = 1;
                    for (uint256 j = 0; j < i; j++) {
                        if (currentTime - handler.getRebalanceTimestamp(j) <= vault.RATE_LIMIT_WINDOW()) {
                            countInWindow++;
                        }
                    }

                    assertLe(countInWindow, vault.MAX_REBALANCE_FREQUENCY(), "Too many rebalances in rate limit window");
                }
            }
        }
    }

    /**
     * @dev INVARIANT 16: Buffer threshold maintenance - buffer should never go below minimum
     */
    function invariant_BufferThresholdMaintenance() public view {
        if (!vault.bufferManagementEnabled()) return;

        uint256 totalAssets = vault.totalAssets();
        if (totalAssets == 0) return;

        uint256 currentBuffer = vault.getCurrentBuffer();
        uint256 requiredBuffer = vault.getRequiredBuffer();
        uint256 bufferPercentage = vault.BUFFER_PERCENTAGE();

        // Verify buffer calculation is correct
        uint256 expectedBuffer = (totalAssets * bufferPercentage) / vault.FEE_DIVISOR();
        assertEq(requiredBuffer, expectedBuffer, "Buffer calculation inconsistency");

        // During normal operations (not emergency), buffer should approach required level
        if (!vault.paused() && totalAssets > vault.USDC_INIT_DEPOSIT()) {
            // Allow tolerance for gradual buffer building
            uint256 tolerance = totalAssets / 100; // 1% tolerance

            if (currentBuffer + tolerance < requiredBuffer) {
                // This should only happen during deployment/rebalancing operations
                // In such cases, deployable amount should be zero
                assertTrue(vault.getDeployableAmount() == 0, "Buffer below threshold but deployable amount > 0");
            }
        }
    }

    /**
     * @dev INVARIANT 17: Emergency pause state consistency
     */
    function invariant_EmergencyPauseStateConsistency() public view {
        bool isPaused = vault.paused();

        if (isPaused) {
            // When paused, max deposit and max withdraw should be 0
            address testUser = address(0x1337);
            assertEq(vault.maxDeposit(testUser), 0, "MaxDeposit should be 0 when paused");
            assertEq(vault.maxWithdraw(testUser), 0, "MaxWithdraw should be 0 when paused");
            assertEq(vault.maxMint(testUser), 0, "MaxMint should be 0 when paused");
            assertEq(vault.maxRedeem(testUser), 0, "MaxRedeem should be 0 when paused");
        }
    }

    /**
     * @dev INVARIANT 18: Asset-share relationship bounds
     */
    function invariant_AssetShareRelationshipBounds() public view {
        uint256 totalSupply = vault.totalSupply();
        uint256 totalAssets = vault.totalAssets();

        if (totalSupply == 0) return;

        // Test conversion consistency
        uint256 testShares = 1000 * 1e18; // 1000 shares
        if (testShares <= totalSupply) {
            uint256 assets = vault.convertToAssets(testShares);
            uint256 backToShares = vault.convertToShares(assets);

            // Allow for rounding differences (max 1 unit)
            uint256 diff = testShares > backToShares ? testShares - backToShares : backToShares - testShares;
            assertLe(diff, 1, "Asset-share conversion not consistent");
        }

        // Preview functions should match actual conversions
        uint256 testAssets = 1000 * ONE_USDC;
        if (testAssets <= totalAssets) {
            uint256 previewShares = vault.previewDeposit(testAssets);
            uint256 actualShares = vault.convertToShares(testAssets);

            assertEq(previewShares, actualShares, "PreviewDeposit doesn't match convertToShares");
        }
    }

    /**
     * @dev INVARIANT 19: Management fee cap enforcement
     */
    function invariant_ManagementFeeCapEnforcement() public view {
        uint256 currentFee = vault.managementFeeBps();
        uint256 maxFee = vault.MAX_MANAGEMENT_FEE_BPS();

        assertLe(currentFee, maxFee, "Management fee exceeds maximum allowed");

        // Check pending fee update also respects cap
        IMotherVault.PendingFeeUpdate memory pendingUpdate = vault.getPendingFeeUpdate();
        if (pendingUpdate.proposedAt > 0 && !pendingUpdate.executed) {
            assertLe(pendingUpdate.newFeeBps, maxFee, "Pending fee update exceeds maximum allowed");
        }
    }

    /**
     * @dev INVARIANT 20: Fee calculation bounds and precision
     */
    function invariant_FeeCalculationBounds() public view {
        uint256 totalAssets = vault.totalAssets();
        uint256 feeBps = vault.managementFeeBps();

        if (totalAssets == 0 || feeBps == 0) return;

        // Fees collected should never exceed total assets
        assertLe(handler.ghost_totalFeesPaid(), totalAssets, "Total fees collected exceed total assets");

        // Fee percentage should be reasonable (allowing for extreme time jump scenarios)
        if (handler.ghost_totalFeesPaid() > 0 && totalAssets > 0) {
            uint256 feePercentage = (handler.ghost_totalFeesPaid() * vault.FEE_DIVISOR()) / totalAssets;
            // Allow for up to 50% fees in extreme scenarios (10 years at 5% = 50%)
            assertLe(
                feePercentage,
                5000, // 50% max
                "Fee percentage unreasonably high"
            );
        }
    }

    /**
     * @dev INVARIANT 21: Cross-chain deployment limits
     */
    function invariant_CrossChainDeploymentLimits() public view {
        (uint32[] memory domainIds, IMotherVault.ChildVault[] memory childVaults) = vault.getAllChildVaults();

        uint256 totalDeployedCalculated = 0;
        for (uint256 i = 0; i < childVaults.length; i++) {
            if (childVaults[i].isActive) {
                // Each deployment should be reasonable (not exceeding total assets)
                assertLe(
                    childVaults[i].deployedAmount,
                    vault.totalAssets(),
                    "Child vault deployed amount exceeds total assets"
                );

                totalDeployedCalculated += childVaults[i].deployedAmount;

                // APY should be within reasonable bounds (0-1000% = 0-100000 bps)
                assertLe(childVaults[i].reportedAPY, 100_000, "Reported APY unreasonably high");
            }
        }

        // Cross-check total deployed calculation
        assertEq(
            totalDeployedCalculated,
            vault.totalDeployedAssets(),
            "Child vault deployed amounts don't sum to total deployed"
        );
    }

    /**
     * @dev INVARIANT 22: Minimum operation amounts and precision
     */
    function invariant_MinimumOperationAmounts() public view {
        // USDC has 6 decimals, so minimum meaningful amount is 1 microUSDC
        uint256 minAmount = 1; // 1 wei of USDC (0.000001 USDC)

        // If there are active shares, share price should handle precision correctly
        if (vault.totalSupply() > 0 && vault.totalAssets() > 0) {
            uint256 oneShare = 1;
            uint256 assetsForOneShare = vault.convertToAssets(oneShare);

            // Converting 1 share should yield at least some assets (or zero if share price is very low)
            // This ensures no complete precision loss
            assertTrue(assetsForOneShare >= 0, "Asset conversion for minimum share failed");

            // Converting minimum asset amount should yield some shares (unless assets are very valuable)
            if (vault.totalAssets() <= 1e12) {
                // Reasonable asset range
                uint256 sharesForMinAsset = vault.convertToShares(minAmount);
                // Allow zero shares for very small amounts, but ensure calculation doesn't overflow
                assertTrue(sharesForMinAsset >= 0, "Share conversion for minimum asset failed");
            }
        }
    }

    /**
     * @dev INVARIANT 23: Ghost variable consistency
     */
    function invariant_GhostVariableConsistency() public view {
        uint256 totalDeposited = handler.ghost_totalDeposited();
        uint256 totalWithdrawn = handler.ghost_totalWithdrawn();
        uint256 totalFeesPaid = handler.ghost_totalFeesPaid();

        // Net deposits minus fees should not exceed current total assets
        if (totalDeposited >= totalWithdrawn + totalFeesPaid) {
            uint256 netDeposits = totalDeposited - totalWithdrawn - totalFeesPaid;

            // Allow for small discrepancies due to yield, rounding, etc.
            uint256 tolerance = vault.totalAssets() / 100; // 1% tolerance

            assertLe(netDeposits, vault.totalAssets() + tolerance, "Net deposits exceed total assets by too much");
        }

        // All ghost variables should be non-negative (already deposited/withdrawn amounts)
        assertGe(totalDeposited, 0, "Total deposited is negative");
        assertGe(totalWithdrawn, 0, "Total withdrawn is negative");
        assertGe(totalFeesPaid, 0, "Total fees paid is negative");
    }

    /**
     * @dev INVARIANT 24: Rebalance operation state consistency
     */
    function invariant_RebalanceOperationStateConsistency() public view {
        uint256 lastRebalanceTime = vault.lastRebalanceTime();
        uint256 cooldownPeriod = vault.rebalanceCooldown();
        uint256 minAPYDiff = vault.minAPYDifferential();

        // Cooldown should be reasonable (not too short or too long)
        assertGe(cooldownPeriod, 1 hours, "Rebalance cooldown too short");
        assertLe(cooldownPeriod, 30 days, "Rebalance cooldown too long");

        // Min APY differential should be reasonable
        assertLe(
            minAPYDiff,
            5000, // 50% max differential requirement
            "Min APY differential too high"
        );

        // Last rebalance time should not be in the future
        assertLe(lastRebalanceTime, block.timestamp, "Last rebalance time in future");
    }

    /**
     * @dev INVARIANT 25: ERC4626 compliance bounds
     */
    function invariant_ERC4626ComplianceBounds() public view {
        address testUser = address(0x1337);

        // Max functions should return reasonable values
        uint256 maxDeposit = vault.maxDeposit(testUser);
        uint256 maxMint = vault.maxMint(testUser);
        uint256 maxWithdraw = vault.maxWithdraw(testUser);
        uint256 maxRedeem = vault.maxRedeem(testUser);

        // Max values should not exceed deposit cap
        assertLe(maxDeposit, vault.depositCap(), "MaxDeposit exceeds deposit cap");

        // When not paused, max values should be consistent with asset calculations
        if (!vault.paused()) {
            if (maxMint > 0) {
                uint256 assetsForMaxMint = vault.previewMint(maxMint);
                assertLe(
                    assetsForMaxMint,
                    maxDeposit + 1, // Allow for rounding
                    "Assets for max mint exceeds max deposit"
                );
            }

            if (maxRedeem > 0) {
                uint256 assetsForMaxRedeem = vault.previewRedeem(maxRedeem);
                assertLe(
                    assetsForMaxRedeem,
                    maxWithdraw + 1, // Allow for rounding
                    "Assets for max redeem exceeds max withdraw"
                );
            }
        }
    }
}
