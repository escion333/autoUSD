// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IHealthMonitor} from "../interfaces/IHealthMonitor.sol";
import {IMotherVault} from "../interfaces/IMotherVault.sol";
import {ICrossChainMessenger} from "../interfaces/ICrossChainMessenger.sol";
import {IRebalancer} from "../interfaces/IRebalancer.sol";

/**
 * @title HealthMonitor
 * @notice Monitors system health across all autoUSD components for POC validation
 * @dev Provides admin dashboard functions and basic metrics collection
 */
contract HealthMonitor is IHealthMonitor, AccessControl, Pausable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MONITOR_ROLE = keccak256("MONITOR_ROLE");

    // Core contract addresses
    IMotherVault public motherVault;
    ICrossChainMessenger public crossChainMessenger;
    IRebalancer public rebalancer;

    // Health tracking structures (defined in interface)

    // State variables
    SystemMetrics public systemMetrics;
    mapping(uint32 => VaultHealth) public childVaultHealth;
    FailedOperation[] public failedOperations;
    uint256 public constant HEALTH_CHECK_INTERVAL = 1 hours;
    uint256 public constant STALE_DATA_THRESHOLD = 24 hours;

    // Events (defined in interface)

    constructor(
        address _motherVault,
        address _crossChainMessenger,
        address _rebalancer,
        address _admin
    ) {
        require(_motherVault != address(0), "Invalid Mother Vault");
        require(_crossChainMessenger != address(0), "Invalid Cross Chain Messenger");
        require(_rebalancer != address(0), "Invalid Rebalancer");
        require(_admin != address(0), "Invalid Admin");

        motherVault = IMotherVault(_motherVault);
        crossChainMessenger = ICrossChainMessenger(_crossChainMessenger);
        rebalancer = IRebalancer(_rebalancer);

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(MONITOR_ROLE, _admin);

        // Initialize system metrics
        systemMetrics = SystemMetrics({
            totalTVL: 0,
            totalActiveVaults: 0,
            lastRebalanceTime: 0,
            pendingMessages: 0,
            emergencyMode: false,
            lastHealthCheck: block.timestamp
        });
    }

    /**
     * @notice Comprehensive system health check
     * @return systemHealth Overall system health information
     */
    function getSystemHealth() external view override returns (VaultHealth memory systemHealth) {
        bool isHealthy = true;
        string memory status = "All systems operational";

        // Check if Mother Vault is paused or has issues
        try motherVault.isPaused() returns (bool isPaused) {
            if (isPaused) {
                isHealthy = false;
                status = "Mother Vault is paused";
            }
        } catch {
            isHealthy = false;
            status = "Mother Vault is unresponsive";
        }

        // Check if rebalancer is functional
        if (isHealthy) {
            try rebalancer.canRebalance() returns (bool canRebalance) {
                if (!canRebalance && block.timestamp > systemMetrics.lastRebalanceTime + 7 days) {
                    isHealthy = false;
                    status = "Rebalancer stuck - no rebalance for 7+ days";
                }
            } catch {
                isHealthy = false;
                status = "Rebalancer is unresponsive";
            }
        }

        // Check for stale data
        if (isHealthy && block.timestamp > systemMetrics.lastHealthCheck + STALE_DATA_THRESHOLD) {
            isHealthy = false;
            status = "Health data is stale";
        }

        systemHealth = VaultHealth({
            tvl: systemMetrics.totalTVL,
            lastUpdate: systemMetrics.lastHealthCheck,
            isHealthy: isHealthy,
            status: status
        });
    }

    /**
     * @notice Get health status of a specific child vault
     * @param domainId The domain ID of the child vault
     * @return vaultHealth Health information for the specified vault
     */
    function getChildVaultHealth(uint32 domainId) external view override returns (VaultHealth memory vaultHealth) {
        vaultHealth = childVaultHealth[domainId];
        
        // If no health data exists, try to get it from Mother Vault
        if (vaultHealth.lastUpdate == 0) {
            try motherVault.getChildVault(domainId) returns (IMotherVault.ChildVault memory childVault) {
                if (childVault.isActive) {
                    vaultHealth = VaultHealth({
                        tvl: childVault.deployedAmount,
                        lastUpdate: childVault.lastReportTime,
                        isHealthy: block.timestamp - childVault.lastReportTime < STALE_DATA_THRESHOLD,
                        status: block.timestamp - childVault.lastReportTime < STALE_DATA_THRESHOLD 
                            ? "Active" 
                            : "Stale data"
                    });
                } else {
                    vaultHealth = VaultHealth({
                        tvl: 0,
                        lastUpdate: 0,
                        isHealthy: false,
                        status: "Inactive vault"
                    });
                }
            } catch {
                vaultHealth = VaultHealth({
                    tvl: 0,
                    lastUpdate: 0,
                    isHealthy: false,
                    status: "Vault query failed"
                });
            }
        }
    }

    /**
     * @notice Check if critical functions are operational
     * @return allFunctional True if all critical functions are working
     */
    function checkCriticalFunctions() external view override returns (bool allFunctional) {
        allFunctional = true;

        // Check Mother Vault functions
        try motherVault.totalAssets() returns (uint256) {
            // Function call succeeded
        } catch {
            allFunctional = false;
        }

        // Check if deposits are possible
        if (allFunctional) {
            try motherVault.maxDeposit(address(this)) returns (uint256) {
                // Function call succeeded
            } catch {
                allFunctional = false;
            }
        }

        // Check rebalancer
        if (allFunctional) {
            try rebalancer.evaluateRebalance() returns (IRebalancer.RebalanceDecision memory) {
                // Function call succeeded
            } catch {
                allFunctional = false;
            }
        }

        return allFunctional;
    }

    /**
     * @notice Update system metrics (called by authorized roles)
     * @dev Should be called regularly to maintain accurate health data
     */
    function updateSystemMetrics() external override onlyRole(MONITOR_ROLE) {
        uint256 totalTVL = 0;
        uint256 activeVaults = 0;
        bool allHealthy = true;

        // Get data from Mother Vault
        try motherVault.totalAssets() returns (uint256 assets) {
            totalTVL = assets;
        } catch {
            allHealthy = false;
        }

        // Get child vault data
        try motherVault.getAllChildVaults() returns (uint32[] memory domainIds, IMotherVault.ChildVault[] memory vaults) {
            for (uint256 i = 0; i < domainIds.length; i++) {
                if (vaults[i].isActive) {
                    activeVaults++;
                    
                    // Update child vault health
                    bool vaultHealthy = block.timestamp - vaults[i].lastReportTime < STALE_DATA_THRESHOLD;
                    childVaultHealth[domainIds[i]] = VaultHealth({
                        tvl: vaults[i].deployedAmount,
                        lastUpdate: vaults[i].lastReportTime,
                        isHealthy: vaultHealthy,
                        status: vaultHealthy ? "Active" : "Stale data"
                    });

                    emit VaultHealthUpdated(domainIds[i], vaultHealthy, vaultHealthy ? "Active" : "Stale data");
                }
            }
        } catch {
            allHealthy = false;
        }

        // Get rebalancer data
        uint256 lastRebalanceTime = 0;
        try rebalancer.lastRebalanceTime() returns (uint256 timestamp) {
            lastRebalanceTime = timestamp;
        } catch {
            allHealthy = false;
        }

        // Check emergency mode
        bool emergencyMode = false;
        try motherVault.isPaused() returns (bool isPaused) {
            emergencyMode = isPaused;
        } catch {
            emergencyMode = true; // Assume emergency if we can't check
        }

        // Update system metrics
        systemMetrics = SystemMetrics({
            totalTVL: totalTVL,
            totalActiveVaults: activeVaults,
            lastRebalanceTime: lastRebalanceTime,
            pendingMessages: 0, // TODO: Implement message tracking
            emergencyMode: emergencyMode,
            lastHealthCheck: block.timestamp
        });

        emit SystemMetricsUpdated(totalTVL, activeVaults, emergencyMode);
        emit HealthCheckCompleted(block.timestamp, allHealthy, allHealthy ? "System healthy" : "Issues detected");
    }

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
    ) external override onlyRole(MONITOR_ROLE) {
        failedOperations.push(FailedOperation({
            timestamp: block.timestamp,
            operationType: operationType,
            contractAddress: contractAddress,
            errorMessage: errorMessage,
            transactionHash: transactionHash
        }));

        emit FailedOperationRecorded(operationType, contractAddress, errorMessage);
    }

    /**
     * @notice Get recent failed operations
     * @param limit Maximum number of operations to return (0 for all)
     * @return operations Array of recent failed operations
     */
    function getRecentFailedOperations(uint256 limit) external view override returns (FailedOperation[] memory operations) {
        uint256 total = failedOperations.length;
        uint256 returnCount = (limit == 0 || limit > total) ? total : limit;
        
        operations = new FailedOperation[](returnCount);
        
        for (uint256 i = 0; i < returnCount; i++) {
            operations[i] = failedOperations[total - 1 - i]; // Return newest first
        }
    }

    /**
     * @notice Get basic APY reporting from child vaults
     * @return domainIds Array of domain IDs
     * @return apyValues Array of APY values (in basis points)
     * @return lastUpdated Array of last update timestamps
     */
    function getChildVaultAPYs() external view override returns (
        uint32[] memory domainIds,
        uint256[] memory apyValues,
        uint256[] memory lastUpdated
    ) {
        try motherVault.getAllChildVaults() returns (uint32[] memory _domainIds, IMotherVault.ChildVault[] memory vaults) {
            domainIds = _domainIds;
            apyValues = new uint256[](domainIds.length);
            lastUpdated = new uint256[](domainIds.length);
            
            for (uint256 i = 0; i < domainIds.length; i++) {
                apyValues[i] = vaults[i].reportedAPY;
                lastUpdated[i] = vaults[i].lastReportTime;
            }
        } catch {
            // Return empty arrays if query fails
            domainIds = new uint32[](0);
            apyValues = new uint256[](0);
            lastUpdated = new uint256[](0);
        }
    }

    /**
     * @notice Get rebalancing metrics for admin dashboard
     * @return canRebalance Whether rebalancing is currently possible
     * @return lastRebalanceTime Timestamp of last rebalance
     * @return cooldownRemaining Seconds remaining in cooldown period
     */
    function getRebalancingMetrics() external view override returns (
        bool canRebalance,
        uint256 lastRebalanceTime,
        uint256 cooldownRemaining
    ) {
        try rebalancer.canRebalance() returns (bool _canRebalance) {
            canRebalance = _canRebalance;
        } catch {
            canRebalance = false;
        }

        try rebalancer.lastRebalanceTime() returns (uint256 _lastRebalanceTime) {
            lastRebalanceTime = _lastRebalanceTime;
        } catch {
            lastRebalanceTime = 0;
        }

        // Calculate cooldown remaining
        try rebalancer.getRebalanceConfig() returns (IRebalancer.RebalanceConfig memory config) {
            if (block.timestamp < lastRebalanceTime + config.rebalanceCooldown) {
                cooldownRemaining = (lastRebalanceTime + config.rebalanceCooldown) - block.timestamp;
            } else {
                cooldownRemaining = 0;
            }
        } catch {
            cooldownRemaining = 0;
        }
    }

    /**
     * @notice Manual health check trigger for admin use
     * @return systemHealthy Overall system health status
     * @return issues Array of detected issues
     */
    function performManualHealthCheck() external override onlyRole(ADMIN_ROLE) returns (
        bool systemHealthy,
        string[] memory issues
    ) {
        string[] memory tempIssues = new string[](10); // Max 10 issues
        uint256 issueCount = 0;
        systemHealthy = true;

        // Check Mother Vault
        try motherVault.isPaused() returns (bool isPaused) {
            if (isPaused) {
                tempIssues[issueCount] = "Mother Vault is paused";
                issueCount++;
                systemHealthy = false;
            }
        } catch {
            tempIssues[issueCount] = "Mother Vault is unresponsive";
            issueCount++;
            systemHealthy = false;
        }

        // Check rebalancer
        try rebalancer.canRebalance() returns (bool canRebalance) {
            if (!canRebalance) {
                try rebalancer.lastRebalanceTime() returns (uint256 lastTime) {
                    if (block.timestamp > lastTime + 7 days) {
                        tempIssues[issueCount] = "No rebalance for over 7 days";
                        issueCount++;
                        systemHealthy = false;
                    }
                } catch {
                    tempIssues[issueCount] = "Cannot access rebalance timing";
                    issueCount++;
                    systemHealthy = false;
                }
            }
        } catch {
            tempIssues[issueCount] = "Rebalancer is unresponsive";
            issueCount++;
            systemHealthy = false;
        }

        // Check child vaults
        try motherVault.getAllChildVaults() returns (uint32[] memory domainIds, IMotherVault.ChildVault[] memory vaults) {
            for (uint256 i = 0; i < domainIds.length && issueCount < 8; i++) {
                if (vaults[i].isActive && block.timestamp > vaults[i].lastReportTime + STALE_DATA_THRESHOLD) {
                    tempIssues[issueCount] = string(abi.encodePacked("Child vault ", uint2str(domainIds[i]), " has stale data"));
                    issueCount++;
                    systemHealthy = false;
                }
            }
        } catch {
            tempIssues[issueCount] = "Cannot access child vault data";
            issueCount++;
            systemHealthy = false;
        }

        // Create properly sized return array
        issues = new string[](issueCount);
        for (uint256 i = 0; i < issueCount; i++) {
            issues[i] = tempIssues[i];
        }

        emit HealthCheckCompleted(block.timestamp, systemHealthy, systemHealthy ? "Manual check passed" : "Issues found");
    }

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
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_motherVault != address(0), "Invalid Mother Vault");
        require(_crossChainMessenger != address(0), "Invalid Cross Chain Messenger");
        require(_rebalancer != address(0), "Invalid Rebalancer");

        motherVault = IMotherVault(_motherVault);
        crossChainMessenger = ICrossChainMessenger(_crossChainMessenger);
        rebalancer = IRebalancer(_rebalancer);

        emit ContractsUpdated(_motherVault, _crossChainMessenger, _rebalancer);
    }

    /**
     * @notice Emergency pause the health monitor
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the health monitor
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @notice Get total number of failed operations
     * @return count Total number of recorded failed operations
     */
    function getFailedOperationCount() external view override returns (uint256 count) {
        return failedOperations.length;
    }

    /**
     * @notice Helper function to convert uint to string
     * @param _i Integer to convert
     * @return _uintAsString String representation
     */
    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}