// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMotherVault is IERC4626 {
    struct ChildVault {
        uint32 domainId;
        address vaultAddress;
        uint256 lastReportTime;
        uint256 deployedAmount;
        uint256 reportedAPY;
        bool isActive;
    }

    struct PendingFeeUpdate {
        uint256 newFeeBps;
        uint256 proposedAt;
        bool executed;
    }

    struct StrategicDeployParams {
        uint32 targetChainId;
        uint256 amount;
        uint256 minAPYDifferential;
    }

    // Core vault events
    event ChildVaultAdded(uint32 indexed domainId, address indexed vault);
    event ChildVaultRemoved(uint32 indexed domainId, address indexed vault);
    event StrategicDeployInitiated(uint32 indexed targetChain, uint256 indexed amount);
    event YieldReported(uint32 indexed domainId, uint256 indexed apy, uint256 totalValue);
    event EmergencyPauseActivated(address indexed initiator);
    event EmergencyPauseDeactivated(address indexed initiator, uint256 indexed timestamp);
    event DepositCapUpdated(uint256 oldCap, uint256 newCap);

    // Cross-chain operation events
    event FundsDeployedToChild(uint32 indexed domainId, uint256 indexed amount, bytes32 indexed messageId);
    event WithdrawalRequestSent(uint32 indexed domainId, uint256 indexed amount, bytes32 indexed messageId);
    event FundsReceivedFromChild(uint32 indexed sourceDomain, uint256 indexed amount);
    event RebalanceCompleted(
        uint32 indexed sourceChain, uint32 indexed targetChain, uint256 indexed amount, uint256 gasUsed
    );

    // Fee management events
    event ManagementFeeCollected(uint256 indexed feeAmount, address indexed feeSink);
    event ManagementFeeUpdated(uint256 indexed oldFee, uint256 indexed newFee);
    event FeeSinkUpdated(address indexed oldSink, address indexed newSink);
    event FeesCollected(uint256 indexed amount, address indexed recipient, uint256 indexed timestamp);
    event FeeUpdateProposed(uint256 indexed oldFeeBps, uint256 indexed newFeeBps, uint256 indexed executeAfter);
    event FeeUpdateExecuted(uint256 indexed oldFeeBps, uint256 indexed newFeeBps, address indexed executor);

    // Buffer management events
    event BufferRefilled(uint32 indexed sourceChain, uint256 indexed amount, uint256 indexed newBufferBalance);

    // Administrative events
    event EmergencyWithdrawal(address indexed recipient, uint256 indexed amount);
    event ThresholdUpdated(string indexed parameter, uint256 indexed oldValue, uint256 indexed newValue);
    event ChildVaultRegistered(uint32 indexed domainId, address indexed vaultAddress, uint256 indexed timestamp);
    event ChildVaultUnregistered(uint32 indexed domainId, address indexed vaultAddress, uint256 indexed timestamp);
    event HealthCheckFailed(string indexed reason, uint256 indexed timestamp, address indexed reporter);

    // Buffer management events (continued)
    event BufferRefillRequested(uint32 indexed chainId, uint256 indexed amount);
    event BufferStatusChanged(uint256 indexed requiredBuffer, uint256 indexed currentBuffer, bool indexed sufficient);
    event BufferManagementToggled(bool indexed enabled);

    error DepositExceedsCap(uint256 requested, uint256 cap);
    error InsufficientAPYDifferential(uint256 differential, uint256 required);
    error RebalanceCooldownActive(uint256 timeRemaining);
    error ChildVaultNotActive(uint32 domainId);
    error InvalidChildVault(address vault);
    error CrossChainMessageFailed(uint32 domainId, bytes reason);
    error EmergencyPauseActive();

    function USDC() external view returns (IERC20);

    function depositCap() external view returns (uint256);

    function totalDeployedAssets() external view returns (uint256);

    function getChildVault(uint32 domainId) external view returns (ChildVault memory);

    function getAllChildVaults() external view returns (uint32[] memory domainIds, ChildVault[] memory vaults);

    function addChildVault(uint32 domainId, address vaultAddress) external;

    function removeChildVault(uint32 domainId) external;

    function strategicDeploy(StrategicDeployParams calldata params) external;

    function deployToChildVault(uint32 domainId, uint256 amount) external;

    function initiateRebalance(uint32 sourceChainId, uint32 targetChainId, uint256 amount) external;

    function handleIncomingMessage(uint32 origin, bytes32 sender, bytes calldata message) external;

    function handleCCTPReceive(uint256 amount, uint32 sourceDomain, bytes32 sender) external;

    function reportYield(uint32 domainId, uint256 apy, uint256 totalValue) external;

    function emergencyPause() external;

    function emergencyUnpause() external;

    function emergencyWithdrawAll() external;

    function setDepositCap(uint256 newCap) external;

    function setManagementFee(uint256 feeBps) external;

    function proposeManagementFeeUpdate(uint256 newFeeBps) external;

    function executeManagementFeeUpdate() external;

    function getPendingFeeUpdate() external view returns (PendingFeeUpdate memory);

    function canExecuteFeeUpdate() external view returns (bool canExecute, uint256 timeRemaining);

    function setFeeSink(address newFeeSink) external;

    function setRebalanceCooldown(uint256 cooldownPeriod) external;

    function setMinAPYDifferential(uint256 minDifferentialBps) external;

    function collectManagementFees() external returns (uint256 feeAmount);

    function lastRebalanceTime() external view returns (uint256);

    function managementFeeBps() external view returns (uint256);

    function rebalanceCooldown() external view returns (uint256);

    function minAPYDifferential() external view returns (uint256);

    function feeSink() external view returns (address);

    function isPaused() external view returns (bool);

    // Buffer management functions
    function getRequiredBuffer() external view returns (uint256);

    function getCurrentBuffer() external view returns (uint256);

    function isBufferSufficient() external view returns (bool);

    function getDeployableAmount() external view returns (uint256);

    function requestBufferRefill() external;

    function setBufferManagement(bool enabled) external;

    function bufferManagementEnabled() external view returns (bool);

    // Fee governance functions
    function reportHealthCheckFailure(string calldata reason, address reporter) external;

    function getFeeGovernanceParams() external pure returns (uint256 maxFeeBps, uint256 timelockPeriod);
}
