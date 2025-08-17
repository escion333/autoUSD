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
        return 0.001 ether;
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
 * @title CoreInvariantHandler
 * @dev Simplified handler for core invariant tests
 */
contract CoreInvariantHandler is Test {
    MotherVault public vault;
    MockUSDC public usdc;
    MockCrossChainMessenger public messenger;
    MockCCTPBridge public cctpBridge;

    address[] public actors;
    uint256 public constant MAX_ACTORS = 3;
    uint256 public constant ONE_USDC = 1e6;
    uint256 public constant MIN_OPERATION_AMOUNT = 1 * ONE_USDC;
    uint256 public constant MAX_OPERATION_AMOUNT = 1000 * ONE_USDC;

    // Track ghost variables
    uint256 public ghost_totalDeposited;
    uint256 public ghost_totalWithdrawn;
    uint256 public lastSharePrice = 1e18;

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

            usdc.mint(actor, 10_000 * ONE_USDC);
            vm.prank(actor);
            usdc.approve(address(vault), type(uint256).max);
            vm.deal(actor, 10 ether);
        }
    }

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

    function warp(uint256 timeSeed) external {
        uint256 timeAdvance = bound(timeSeed, 1 hours, 7 days);
        skip(timeAdvance);
        _updateSharePrice();
    }

    function _updateSharePrice() internal {
        if (vault.totalSupply() == 0) return;

        uint256 currentSharePrice = (vault.totalAssets() * 1e18) / vault.totalSupply();
        lastSharePrice = currentSharePrice;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

/**
 * @title CoreInvariantsTest
 * @dev Core invariant tests for the MotherVault contract
 */
contract CoreInvariantsTest is StdInvariant, Test {
    MotherVault public vault;
    MockUSDC public usdc;
    MockCrossChainMessenger public messenger;
    MockCCTPBridge public cctpBridge;
    CoreInvariantHandler public handler;

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

        // Grant necessary roles
        vault.grantRole(vault.MANAGER_ROLE(), address(this));
        vault.grantRole(vault.REBALANCER_ROLE(), address(this));
        vault.grantRole(vault.PAUSER_ROLE(), address(this));

        // Set reasonable parameters
        vault.setDepositCap(1_000_000 * ONE_USDC);
        vault.setRebalanceCooldown(1 hours);
        vault.setMinAPYDifferential(100);

        // Deploy handler
        handler = new CoreInvariantHandler(vault, usdc, messenger, cctpBridge);

        // Grant roles to handler
        vault.grantRole(vault.MANAGER_ROLE(), address(handler));
        vault.grantRole(vault.REBALANCER_ROLE(), address(handler));
        vault.grantRole(vault.PAUSER_ROLE(), address(handler));

        // Target the handler
        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = handler.deposit.selector;
        selectors[1] = handler.withdraw.selector;
        selectors[2] = handler.warp.selector;

        targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));
    }

    /**
     * @dev INVARIANT 1: Share price should never decrease significantly except during losses
     */
    function invariant_SharePriceMonotonicity() public view {
        if (vault.totalSupply() == 0) return;

        uint256 currentSharePrice = (vault.totalAssets() * 1e18) / vault.totalSupply();

        // Allow for small precision loss (up to 0.1%)
        uint256 tolerance = handler.lastSharePrice() / 1000;

        assertGe(
            currentSharePrice + tolerance, handler.lastSharePrice(), "Share price decreased beyond acceptable tolerance"
        );
    }

    /**
     * @dev INVARIANT 2: Asset conservation - total assets should equal idle + deployed
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
     * @dev INVARIANT 3: USDC balance consistency
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
     * @dev INVARIANT 4: Share supply consistency
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
     * @dev INVARIANT 5: Deposit cap enforcement
     */
    function invariant_DepositCapEnforcement() public view {
        uint256 totalAssets = vault.totalAssets();
        uint256 depositCap = vault.depositCap();

        assertLe(totalAssets, depositCap, "Total assets exceed deposit cap");
    }

    /**
     * @dev INVARIANT 6: Buffer management (if enabled)
     */
    function invariant_BufferManagement() public view {
        if (!vault.bufferManagementEnabled()) return;

        uint256 currentBuffer = vault.getCurrentBuffer();
        uint256 requiredBuffer = vault.getRequiredBuffer();

        if (vault.totalAssets() > 0) {
            uint256 tolerance = vault.totalAssets() / 1000; // 0.1% tolerance

            if (currentBuffer + tolerance < requiredBuffer) {
                assertTrue(
                    vault.getDeployableAmount() == 0,
                    "Buffer requirement violated: insufficient funds available for withdrawal"
                );
            }
        }
    }
}
