// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { ICrossChainMessenger } from "../../contracts/interfaces/ICrossChainMessenger.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockMotherVault {
    event DepositFromChild(address vault, bytes payload);
    event WithdrawalToChild(address vault, bytes payload);
    event YieldReport(address vault, bytes payload);
    event RebalanceCommand(address vault, bytes payload);
    event EmergencyPause(address vault);
    event EmergencyUnpause(address vault);
    event EmergencyWithdrawAll(address vault, bytes payload);
    event IncomingMessageHandled(uint32 origin, bytes32 sender, bytes message);
    event RebalanceInitiated(uint32 sourceChainId, uint32 targetChainId, uint256 amount);
    event FundsDeployedToChild(uint32 domainId, uint256 amount);
    event FundsReceivedFromChild(uint32 indexed sourceDomain, uint256 amount);
    event CCTPReceiveHandled(uint256 amount, uint32 sourceDomain, bytes32 messageHash);

    bool public rebalanceInitiated;
    bool public shouldRevert = false;

    // Mock accounting state
    uint256 public totalIdle = 50_000 * 1e6; // 50k USDC idle
    uint256 public totalDeployed = 950_000 * 1e6; // 950k USDC deployed
    uint256 public bufferTarget = 50_000 * 1e6; // 50k USDC buffer

    // Child vault tracking
    mapping(uint32 => uint256) public deployedAmounts;

    // Extended mock state for comprehensive testing
    uint256 public totalSupply = 1_000_000 * 1e6; // Mock share supply
    uint256 public managementFeeBps = 50; // 0.5% management fee
    bool public bufferManagementEnabled = true;
    uint256 public bufferPercentage = 500; // 5% buffer requirement
    bool public rebalanceInProgress = false;
    uint256 public pendingWithdrawals = 0;
    uint256[] public withdrawalQueue;
    uint256 public availableForWithdrawal = 0;

    // Callback tracking
    bool public callbackCalled = false;
    uint256 public lastCallbackAmount;
    uint32 public lastCallbackDomain;
    bytes32 public lastCallbackHash;
    bool public bufferStatusEventEmitted = false;

    // Domain mappings for testing
    uint32 public constant KATANA_DOMAIN = 100; // Custom domain for Katana (not CCTP)

    IERC20 public immutable usdc;

    constructor(address _usdc) {
        usdc = IERC20(_usdc);
    }

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function handleCCTPReceive(uint256 amount, uint32 sourceDomain, bytes32 messageHash) external {
        if (shouldRevert) {
            revert("Mock callback revert");
        }

        // Track callback for testing
        callbackCalled = true;
        lastCallbackAmount = amount;
        lastCallbackDomain = sourceDomain;
        lastCallbackHash = messageHash;

        // Update accounting like real MotherVault
        if (deployedAmounts[sourceDomain] >= amount) {
            totalIdle += amount;
            totalDeployed -= amount;
            deployedAmounts[sourceDomain] -= amount;
        }

        // Update available for withdrawal
        availableForWithdrawal = _calculateAvailableForWithdrawal();

        emit CCTPReceiveHandled(amount, sourceDomain, messageHash);
        emit FundsReceivedFromChild(sourceDomain, amount);
    }

    function handleIncomingMessage(uint32 origin, bytes32 sender, bytes calldata message) external {
        emit IncomingMessageHandled(origin, sender, message);

        (ICrossChainMessenger.MessageType messageType, bytes memory payload) =
            abi.decode(message, (ICrossChainMessenger.MessageType, bytes));

        // Minimal routing logic for mock
        if (messageType == ICrossChainMessenger.MessageType.DEPOSIT_REQUEST) {
            // Do nothing, just succeed
        } else if (messageType == ICrossChainMessenger.MessageType.WITHDRAWAL_REQUEST) {
            // Do nothing, just succeed
        }
    }

    function handleDepositFromChild(address vault, bytes calldata payload) external returns (bytes memory) {
        emit DepositFromChild(vault, payload);
        return abi.encode(true);
    }

    function handleWithdrawalToChild(address vault, bytes calldata payload) external returns (bytes memory) {
        emit WithdrawalToChild(vault, payload);
        return abi.encode(true);
    }

    function handleYieldReport(address vault, bytes calldata payload) external returns (bytes memory) {
        emit YieldReport(vault, payload);
        return abi.encode(true);
    }

    function handleRebalanceCommand(address vault, bytes calldata payload) external returns (bytes memory) {
        emit RebalanceCommand(vault, payload);
        return abi.encode(true);
    }

    function handleEmergencyPause(address vault) external returns (bytes memory) {
        emit EmergencyPause(vault);
        return abi.encode(true);
    }

    function handleEmergencyUnpause(address vault) external returns (bytes memory) {
        emit EmergencyUnpause(vault);
        return abi.encode(true);
    }

    function handleEmergencyWithdrawAll(address vault, bytes calldata payload) external returns (bytes memory) {
        emit EmergencyWithdrawAll(vault, payload);
        return abi.encode(true);
    }

    function initiateRebalance(uint32 sourceChainId, uint32 targetChainId, uint256 amount) external {
        rebalanceInitiated = true;
        emit RebalanceInitiated(sourceChainId, targetChainId, amount);
    }

    function deployToChildVault(uint32 domainId, uint256 amount) external {
        require(amount <= _getDeployableAmount(), "Insufficient deployable funds");
        totalIdle -= amount;
        totalDeployed += amount;
        deployedAmounts[domainId] += amount;
        rebalanceInitiated = true; // Set flag for deployment as well
        emit FundsDeployedToChild(domainId, amount);
    }

    // Required for IMotherVaultWithBuffer interface
    function getDeployableAmount() external view returns (uint256) {
        return _getDeployableAmount();
    }

    function _getDeployableAmount() internal view returns (uint256) {
        if (totalIdle <= bufferTarget) {
            return 0;
        }
        return totalIdle - bufferTarget;
    }

    function isBufferSufficient() external view returns (bool) {
        return totalIdle >= bufferTarget;
    }

    function totalAssets() external view returns (uint256) {
        return totalIdle + totalDeployed;
    }

    function getCurrentBuffer() external view returns (uint256) {
        return totalIdle;
    }

    // Helper functions for testing
    function setTotalIdle(uint256 _totalIdle) external {
        totalIdle = _totalIdle;
    }

    function setTotalDeployed(uint256 _totalDeployed) external {
        totalDeployed = _totalDeployed;
    }

    function setBufferTarget(uint256 _bufferTarget) external {
        bufferTarget = _bufferTarget;
    }

    function setDeployedAmount(uint32 domainId, uint256 amount) external {
        deployedAmounts[domainId] = amount;
    }

    function getDeployedAmount(uint32 domainId) external view returns (uint256) {
        return deployedAmounts[domainId];
    }

    // Extended mock functions for comprehensive testing
    function getTotalIdle() external view returns (uint256) {
        return totalIdle;
    }

    function getTotalDeployed() external view returns (uint256) {
        return totalDeployed;
    }

    function getTotalAssets() external view returns (uint256) {
        return totalIdle + totalDeployed;
    }

    function setTotalSupply(uint256 _totalSupply) external {
        totalSupply = _totalSupply;
    }

    function convertToAssets(uint256 shares) external view returns (uint256) {
        if (totalSupply == 0) return shares;
        return (shares * this.getTotalAssets()) / totalSupply;
    }

    function setManagementFeeBps(uint256 _feeBps) external {
        managementFeeBps = _feeBps;
    }

    function calculateManagementFee() external view returns (uint256) {
        // Simplified fee calculation for testing
        return (this.getTotalAssets() * managementFeeBps) / 10_000;
    }

    function setBufferManagementEnabled(bool _enabled) external {
        bufferManagementEnabled = _enabled;
    }

    function setBufferPercentage(uint256 _percentage) external {
        bufferPercentage = _percentage;
    }

    function getRequiredBuffer() external view returns (uint256) {
        if (!bufferManagementEnabled) return 0;
        return (this.getTotalAssets() * bufferPercentage) / 10_000;
    }

    function setRebalanceInProgress(bool _inProgress) external {
        rebalanceInProgress = _inProgress;
    }

    function isRebalanceInProgress() external view returns (bool) {
        return rebalanceInProgress;
    }

    function setPendingWithdrawals(uint256 _pending) external {
        pendingWithdrawals = _pending;
    }

    function getPendingWithdrawals() external view returns (uint256) {
        return pendingWithdrawals;
    }

    function setWithdrawalQueue(uint256[] memory _queue) external {
        delete withdrawalQueue;
        for (uint256 i = 0; i < _queue.length; i++) {
            withdrawalQueue.push(_queue[i]);
        }
    }

    function getWithdrawalQueueSize() external view returns (uint256) {
        return withdrawalQueue.length;
    }

    function getTotalQueuedWithdrawals() external view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < withdrawalQueue.length; i++) {
            total += withdrawalQueue[i];
        }
        return total;
    }

    function getAvailableForWithdrawal() external view returns (uint256) {
        return availableForWithdrawal;
    }

    function _calculateAvailableForWithdrawal() internal view returns (uint256) {
        if (!bufferManagementEnabled) return totalIdle;

        uint256 requiredBuffer = (this.getTotalAssets() * bufferPercentage) / 10_000;
        if (totalIdle <= requiredBuffer) return 0;

        return totalIdle - requiredBuffer;
    }

    // Callback tracking functions
    function wasCallbackCalled() external view returns (bool) {
        return callbackCalled;
    }

    function getLastCallbackAmount() external view returns (uint256) {
        return lastCallbackAmount;
    }

    function getLastCallbackDomain() external view returns (uint32) {
        return lastCallbackDomain;
    }

    function getLastCallbackHash() external view returns (bytes32) {
        return lastCallbackHash;
    }

    function resetCallbackTracking() external {
        callbackCalled = false;
        lastCallbackAmount = 0;
        lastCallbackDomain = 0;
        lastCallbackHash = bytes32(0);
    }

    function wasBufferStatusEventEmitted() external view returns (bool) {
        return bufferStatusEventEmitted;
    }

    function setBufferStatusEventEmitted(bool _emitted) external {
        bufferStatusEventEmitted = _emitted;
    }

    // Mock deposit/withdraw functions for integration tests
    function deposit(uint256 assets, address /*receiver*/ ) external returns (uint256 shares) {
        // Simple 1:1 conversion for testing
        shares = assets;
        totalIdle += assets;
        totalSupply += shares;
        return shares;
    }

    function withdraw(uint256 assets, address receiver, address /*owner*/ ) external returns (uint256 shares) {
        require(assets <= availableForWithdrawal, "Insufficient available funds");
        shares = assets; // 1:1 for simplicity
        totalIdle -= assets;
        totalSupply -= shares;

        // Transfer USDC to receiver
        usdc.transfer(receiver, assets);
        return shares;
    }
}
