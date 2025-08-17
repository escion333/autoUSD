// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Test } from "forge-std/Test.sol";
import { HealthMonitor } from "../../contracts/core/HealthMonitor.sol";
import { IHealthMonitor } from "../../contracts/interfaces/IHealthMonitor.sol";

contract MockMotherVault {
    bool public isPaused;
    uint256 public totalAssets;

    function setPaused(bool _paused) external {
        isPaused = _paused;
    }

    function setTotalAssets(uint256 _assets) external {
        totalAssets = _assets;
    }

    function maxDeposit(address) external pure returns (uint256) {
        return 1000e6;
    }

    function getAllChildVaults() external pure returns (uint32[] memory, bytes memory) {
        uint32[] memory domains = new uint32[](0);
        return (domains, "");
    }
}

contract MockCrossChainMessenger {
    function estimateMessageFee(uint32) external pure returns (uint256) {
        return 0.001 ether;
    }
}

contract MockRebalancer {
    bool public canRebalance = true;
    uint256 public lastRebalanceTime;

    struct RebalanceConfig {
        uint256 minAPYDifferentialBps;
        uint256 maxRebalanceAmount;
        uint256 minRebalanceAmount;
        uint256 rebalanceCooldown;
        uint256 maxGasCostUSD;
        uint256 targetAllocationRatio;
    }

    RebalanceConfig public config = RebalanceConfig(100, 1_000_000e6, 1000e6, 1 days, 50e6, 0);

    function setCanRebalance(bool _can) external {
        canRebalance = _can;
    }

    function setLastRebalanceTime(uint256 _time) external {
        lastRebalanceTime = _time;
    }

    function getRebalanceConfig() external view returns (RebalanceConfig memory) {
        return config;
    }

    struct RebalanceDecision {
        uint32 sourceChainId;
        uint32 targetChainId;
        uint256 amountToMove;
        uint256 expectedAPYImprovement;
        uint256 estimatedGasCost;
        bool shouldExecute;
        string reason;
    }

    function evaluateRebalance() external pure returns (RebalanceDecision memory) {
        return RebalanceDecision(0, 0, 0, 0, 0, false, "No action needed");
    }
}

contract HealthMonitorTest is Test {
    HealthMonitor public healthMonitor;
    MockMotherVault public mockMotherVault;
    MockCrossChainMessenger public mockMessenger;
    MockRebalancer public mockRebalancer;

    address public admin = address(this);

    function setUp() public {
        mockMotherVault = new MockMotherVault();
        mockMessenger = new MockCrossChainMessenger();
        mockRebalancer = new MockRebalancer();

        healthMonitor =
            new HealthMonitor(address(mockMotherVault), address(mockMessenger), address(mockRebalancer), admin);
    }

    function testHealthMonitorDeployment() public {
        assertEq(address(healthMonitor.motherVault()), address(mockMotherVault));
        assertEq(address(healthMonitor.crossChainMessenger()), address(mockMessenger));
        assertEq(address(healthMonitor.rebalancer()), address(mockRebalancer));
    }

    function testGetSystemHealth() public view {
        IHealthMonitor.VaultHealth memory health = healthMonitor.getSystemHealth();
        assertTrue(health.isHealthy);
        assertEq(health.status, "All systems operational");
    }

    function testCheckCriticalFunctions() public view {
        bool functional = healthMonitor.checkCriticalFunctions();
        assertTrue(functional);
    }

    function testUpdateSystemMetrics() public {
        healthMonitor.updateSystemMetrics();

        (uint256 totalTVL, uint256 totalActiveVaults,,, bool emergencyMode,) = healthMonitor.systemMetrics();
        assertEq(totalTVL, 0);
        assertEq(totalActiveVaults, 0);
        assertFalse(emergencyMode);
    }

    function testRecordFailedOperation() public {
        string memory opType = "deposit";
        address contractAddr = address(mockMotherVault);
        string memory errorMsg = "Insufficient balance";
        bytes32 txHash = keccak256("test");

        healthMonitor.recordFailedOperation(opType, contractAddr, errorMsg, txHash);

        uint256 count = healthMonitor.getFailedOperationCount();
        assertEq(count, 1);

        IHealthMonitor.FailedOperation[] memory ops = healthMonitor.getRecentFailedOperations(1);
        assertEq(ops.length, 1);
        assertEq(ops[0].operationType, opType);
        assertEq(ops[0].contractAddress, contractAddr);
        assertEq(ops[0].errorMessage, errorMsg);
        assertEq(ops[0].transactionHash, txHash);
    }

    function testGetRebalancingMetrics() public view {
        (bool canRebalance, uint256 lastTime, uint256 cooldown) = healthMonitor.getRebalancingMetrics();
        assertTrue(canRebalance);
        assertEq(lastTime, 0);
        assertEq(cooldown, 0);
    }

    function testPerformManualHealthCheck() public {
        (bool healthy, string[] memory issues) = healthMonitor.performManualHealthCheck();
        assertTrue(healthy);
        assertEq(issues.length, 0);
    }

    function testSystemHealthWithPausedVault() public {
        mockMotherVault.setPaused(true);

        IHealthMonitor.VaultHealth memory health = healthMonitor.getSystemHealth();
        assertFalse(health.isHealthy);
        assertEq(health.status, "Mother Vault is paused");
    }
}
