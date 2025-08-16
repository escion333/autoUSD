// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title IHealthMonitor
 * @notice Interface for the HealthMonitor contract
 */
interface IHealthMonitor {
    
    struct VaultHealth {
        uint256 tvl;
        uint256 lastUpdate;
        bool isHealthy;
        string status;
    }

    struct SystemMetrics {
        uint256 totalTVL;
        uint256 totalActiveVaults;
        uint256 lastRebalanceTime;
        uint256 pendingMessages;
        bool emergencyMode;
        uint256 lastHealthCheck;
    }

    struct FailedOperation {
        uint256 timestamp;
        string operationType;
        address contractAddress;
        string errorMessage;
        bytes32 transactionHash;
    }

    // Events
    event HealthCheckCompleted(uint256 timestamp, bool systemHealthy, string status);
    event VaultHealthUpdated(uint32 indexed domainId, bool isHealthy, string status);
    event FailedOperationRecorded(string operationType, address contractAddress, string errorMessage);
    event SystemMetricsUpdated(uint256 totalTVL, uint256 activeVaults, bool emergencyMode);
    event ContractsUpdated(address motherVault, address crossChainMessenger, address rebalancer);

    /**
     * @notice Get comprehensive system health status
     * @return systemHealth Overall system health information
     */
    function getSystemHealth() external view returns (VaultHealth memory systemHealth);

    /**
     * @notice Get health status of a specific child vault
     * @param domainId The domain ID of the child vault
     * @return vaultHealth Health information for the specified vault
     */
    function getChildVaultHealth(uint32 domainId) external view returns (VaultHealth memory vaultHealth);

    /**
     * @notice Check if critical functions are operational
     * @return allFunctional True if all critical functions are working
     */
    function checkCriticalFunctions() external view returns (bool allFunctional);

    /**
     * @notice Update system metrics
     */
    function updateSystemMetrics() external;

    /**
     * @notice Record a failed operation for monitoring
     * @param operationType Type of operation that failed
     * @param contractAddress Address of the contract where failure occurred
     * @param errorMessage Error message or reason for failure
     * @param transactionHash Hash of the failed transaction
     */
    function recordFailedOperation(
        string calldata operationType,
        address contractAddress,
        string calldata errorMessage,
        bytes32 transactionHash
    ) external;

    /**
     * @notice Get recent failed operations
     * @param limit Maximum number of operations to return (0 for all)
     * @return operations Array of recent failed operations
     */
    function getRecentFailedOperations(uint256 limit) external view returns (FailedOperation[] memory operations);

    /**
     * @notice Get basic APY reporting from child vaults
     * @return domainIds Array of domain IDs
     * @return apyValues Array of APY values (in basis points)
     * @return lastUpdated Array of last update timestamps
     */
    function getChildVaultAPYs() external view returns (
        uint32[] memory domainIds,
        uint256[] memory apyValues,
        uint256[] memory lastUpdated
    );

    /**
     * @notice Get rebalancing metrics for admin dashboard
     * @return canRebalance Whether rebalancing is currently possible
     * @return lastRebalanceTime Timestamp of last rebalance
     * @return cooldownRemaining Seconds remaining in cooldown period
     */
    function getRebalancingMetrics() external view returns (
        bool canRebalance,
        uint256 lastRebalanceTime,
        uint256 cooldownRemaining
    );

    /**
     * @notice Manual health check trigger for admin use
     * @return systemHealthy Overall system health status
     * @return issues Array of detected issues
     */
    function performManualHealthCheck() external returns (
        bool systemHealthy,
        string[] memory issues
    );

    /**
     * @notice Update contract addresses (admin only)
     * @param _motherVault New Mother Vault address
     * @param _crossChainMessenger New Cross Chain Messenger address
     * @param _rebalancer New Rebalancer address
     */
    function updateContracts(
        address _motherVault,
        address _crossChainMessenger,
        address _rebalancer
    ) external;

    /**
     * @notice Get total number of failed operations
     * @return count Total number of recorded failed operations
     */
    function getFailedOperationCount() external view returns (uint256 count);
}