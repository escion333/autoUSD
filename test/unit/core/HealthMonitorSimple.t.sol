// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Test, console2 } from "forge-std/Test.sol";
import { HealthMonitor } from "../../../contracts/core/HealthMonitor.sol";
import { IHealthMonitor } from "../../../contracts/interfaces/IHealthMonitor.sol";
import { MockMotherVault } from "../../mocks/MockMotherVault.sol";
import { MockCrossChainMessenger } from "../../mocks/MockCrossChainMessenger.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";

/**
 * @title HealthMonitorSimpleTest
 * @notice Simple test suite for HealthMonitor focusing on interface compliance
 */
contract HealthMonitorSimpleTest is Test {
    HealthMonitor public healthMonitor;
    MockMotherVault public motherVault;
    MockCrossChainMessenger public messenger;
    MockERC20 public usdc;

    address public admin = address(0x1);
    address public user = address(0x2);

    uint32 public constant ARBITRUM_DOMAIN = 42_161;
    uint32 public constant OPTIMISM_DOMAIN = 10;

    // Events from the actual interface
    event HealthCheckCompleted(uint256 indexed timestamp, bool indexed systemHealthy, string status);
    event VaultHealthUpdated(uint32 indexed domainId, bool indexed isHealthy, string status);
    event FailedOperationRecorded(string indexed operationType, address indexed contractAddress, string errorMessage);
    event SystemMetricsUpdated(uint256 indexed totalTVL, uint256 indexed activeVaults, bool indexed emergencyMode);
    event ContractsUpdated(
        address indexed motherVault, address indexed crossChainMessenger, address indexed rebalancer
    );

    function setUp() public {
        usdc = new MockERC20("USD Coin", "USDC", 6);
        motherVault = new MockMotherVault(address(usdc));
        messenger = new MockCrossChainMessenger();

        healthMonitor = new HealthMonitor(address(motherVault), address(messenger), address(0x123), admin);

        usdc.mint(address(motherVault), 10_000_000e6);
    }

    function test_Constructor() public {
        assertEq(address(healthMonitor.motherVault()), address(motherVault));
        assertEq(address(healthMonitor.crossChainMessenger()), address(messenger));
        assertTrue(healthMonitor.hasRole(healthMonitor.DEFAULT_ADMIN_ROLE(), admin));
    }

    function test_GetSystemHealth() public {
        IHealthMonitor.VaultHealth memory health = healthMonitor.getSystemHealth();
        assertTrue(health.isHealthy);
        assertTrue(health.lastUpdate > 0);
    }

    function test_GetChildVaultHealth() public {
        IHealthMonitor.VaultHealth memory health = healthMonitor.getChildVaultHealth(ARBITRUM_DOMAIN);
        // Should return default healthy state for non-existent vault
        assertTrue(health.isHealthy);
    }

    function test_CheckCriticalFunctions() public {
        bool functional = healthMonitor.checkCriticalFunctions();
        assertTrue(functional);
    }

    function test_UpdateSystemMetrics() public {
        vm.expectEmit(true, true, true, false);
        emit SystemMetricsUpdated(0, 0, false);

        healthMonitor.updateSystemMetrics();
    }

    function test_RecordFailedOperation() public {
        string memory operationType = "DEPOSIT";
        address contractAddr = address(motherVault);
        string memory errorMsg = "Insufficient balance";
        bytes32 txHash = keccak256("test transaction");

        vm.expectEmit(true, true, false, true);
        emit FailedOperationRecorded(operationType, contractAddr, errorMsg);

        healthMonitor.recordFailedOperation(operationType, contractAddr, errorMsg, txHash);

        assertEq(healthMonitor.getFailedOperationCount(), 1);
    }

    function test_GetRecentFailedOperations() public {
        // Record some failed operations
        healthMonitor.recordFailedOperation("DEPOSIT", address(motherVault), "Error 1", bytes32(uint256(1)));
        healthMonitor.recordFailedOperation("WITHDRAW", address(messenger), "Error 2", bytes32(uint256(2)));

        IHealthMonitor.FailedOperation[] memory operations = healthMonitor.getRecentFailedOperations(1);
        assertEq(operations.length, 1);
        assertEq(operations[0].operationType, "WITHDRAW"); // Should get most recent

        operations = healthMonitor.getRecentFailedOperations(0); // Get all
        assertEq(operations.length, 2);
    }

    function test_GetChildVaultAPYs() public {
        (uint32[] memory domainIds, uint256[] memory apyValues, uint256[] memory lastUpdated) =
            healthMonitor.getChildVaultAPYs();

        // Should return empty arrays initially
        assertEq(domainIds.length, 0);
        assertEq(apyValues.length, 0);
        assertEq(lastUpdated.length, 0);
    }

    function test_GetRebalancingMetrics() public {
        (bool canRebalance, uint256 lastRebalanceTime, uint256 cooldownRemaining) =
            healthMonitor.getRebalancingMetrics();

        assertTrue(canRebalance); // Should be able to rebalance initially
        assertEq(lastRebalanceTime, 0); // No rebalance yet
        assertEq(cooldownRemaining, 0); // No cooldown
    }

    function test_PerformManualHealthCheck() public {
        vm.expectEmit(true, true, false, true);
        emit HealthCheckCompleted(block.timestamp, true, "System healthy");

        (bool systemHealthy, string[] memory issues) = healthMonitor.performManualHealthCheck();

        assertTrue(systemHealthy);
        assertEq(issues.length, 0); // No issues
    }

    function test_UpdateContracts() public {
        address newMotherVault = address(0x100);
        address newMessenger = address(0x200);
        address newRebalancer = address(0x300);

        vm.expectEmit(true, true, true, true);
        emit ContractsUpdated(newMotherVault, newMessenger, newRebalancer);

        vm.prank(admin);
        healthMonitor.updateContracts(newMotherVault, newMessenger, newRebalancer);
    }

    function test_UpdateContracts_OnlyAdmin() public {
        vm.prank(user);
        vm.expectRevert();
        healthMonitor.updateContracts(address(0x100), address(0x200), address(0x300));
    }

    function test_RecordFailedOperation_AccessControl() public {
        // Should be able to call from any address (no access control on recording failures)
        vm.prank(user);
        healthMonitor.recordFailedOperation("TEST", address(this), "test error", bytes32(0));

        assertEq(healthMonitor.getFailedOperationCount(), 1);
    }

    function test_MultipleFailedOperations() public {
        // Record multiple operations
        for (uint256 i = 0; i < 5; i++) {
            healthMonitor.recordFailedOperation(
                "OPERATION", address(uint160(i + 1)), string(abi.encodePacked("Error ", i)), bytes32(i)
            );
        }

        assertEq(healthMonitor.getFailedOperationCount(), 5);

        // Get limited results
        IHealthMonitor.FailedOperation[] memory recent = healthMonitor.getRecentFailedOperations(3);
        assertEq(recent.length, 3);

        // Verify they're in reverse order (most recent first)
        assertEq(recent[0].contractAddress, address(5));
        assertEq(recent[1].contractAddress, address(4));
        assertEq(recent[2].contractAddress, address(3));
    }

    function test_VaultHealthWithMockData() public {
        // Test with some vault data
        motherVault.setDeployedAmount(ARBITRUM_DOMAIN, 1000e6);

        IHealthMonitor.VaultHealth memory health = healthMonitor.getChildVaultHealth(ARBITRUM_DOMAIN);
        assertTrue(health.isHealthy);
        assertTrue(health.lastUpdate > 0);
    }

    function test_SystemHealthIntegration() public {
        // Update some system state
        healthMonitor.updateSystemMetrics();

        // Perform health check
        (bool healthy, string[] memory issues) = healthMonitor.performManualHealthCheck();
        assertTrue(healthy);

        // Get system health
        IHealthMonitor.VaultHealth memory systemHealth = healthMonitor.getSystemHealth();
        assertTrue(systemHealth.isHealthy);
    }

    function testFuzz_RecordFailedOperations(uint8 count) public {
        count = uint8(bound(count, 1, 50)); // Limit to reasonable range

        for (uint256 i = 0; i < count; i++) {
            healthMonitor.recordFailedOperation("FUZZ_TEST", address(uint160(i + 1000)), "Fuzz error", bytes32(i));
        }

        assertEq(healthMonitor.getFailedOperationCount(), count);

        // Test getting recent operations
        IHealthMonitor.FailedOperation[] memory recent = healthMonitor.getRecentFailedOperations(count);
        assertEq(recent.length, count);
    }

    function test_EmptyOperationType() public {
        healthMonitor.recordFailedOperation("", address(this), "Empty operation type", bytes32(0));
        assertEq(healthMonitor.getFailedOperationCount(), 1);
    }

    function test_EmptyErrorMessage() public {
        healthMonitor.recordFailedOperation("TEST", address(this), "", bytes32(0));
        assertEq(healthMonitor.getFailedOperationCount(), 1);
    }

    function test_ZeroAddressContract() public {
        healthMonitor.recordFailedOperation("TEST", address(0), "Zero address", bytes32(0));
        assertEq(healthMonitor.getFailedOperationCount(), 1);
    }
}
