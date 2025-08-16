// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Test, console } from "forge-std/Test.sol";
import { Rebalancer } from "../contracts/core/Rebalancer.sol";
import { IRebalancer } from "../contracts/interfaces/IRebalancer.sol";
import { MockMotherVault } from "./mocks/MockMotherVault.sol";

contract RebalancerTest is Test {
    Rebalancer public rebalancer;
    MockMotherVault public mockMotherVault;

    address public admin;
    address public rebalancerRoleHolder;
    address public metricsUpdaterRoleHolder;
    address public pauserRoleHolder;
    address public randomUser;

    function setUp() public {
        admin = makeAddr("admin");
        rebalancerRoleHolder = makeAddr("rebalancerRoleHolder");
        metricsUpdaterRoleHolder = makeAddr("metricsUpdaterRoleHolder");
        pauserRoleHolder = makeAddr("pauserRoleHolder");
        randomUser = makeAddr("randomUser");

        vm.startPrank(admin);
        mockMotherVault = new MockMotherVault();
        rebalancer = new Rebalancer(address(mockMotherVault));

        rebalancer.grantRole(rebalancer.REBALANCER_ROLE(), rebalancerRoleHolder);
        rebalancer.grantRole(rebalancer.METRICS_UPDATER_ROLE(), metricsUpdaterRoleHolder);
        rebalancer.grantRole(rebalancer.PAUSER_ROLE(), pauserRoleHolder);
        vm.stopPrank();
    }

    function test_InitialRoles() public view {
        assertTrue(rebalancer.hasRole(rebalancer.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(rebalancer.hasRole(rebalancer.REBALANCER_ROLE(), admin));
        assertTrue(rebalancer.hasRole(rebalancer.REBALANCER_ROLE(), rebalancerRoleHolder));
        assertTrue(rebalancer.hasRole(rebalancer.METRICS_UPDATER_ROLE(), metricsUpdaterRoleHolder));
        assertTrue(rebalancer.hasRole(rebalancer.PAUSER_ROLE(), pauserRoleHolder));
    }

    function test_AdminFunctionsFailWithoutAdminRole() public {
        IRebalancer.RebalanceConfig memory config = rebalancer.getRebalanceConfig();
        
        vm.startPrank(randomUser);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", randomUser, rebalancer.DEFAULT_ADMIN_ROLE()));
        rebalancer.updateRebalanceConfig(config);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", randomUser, rebalancer.DEFAULT_ADMIN_ROLE()));
        rebalancer.emergencyRebalance(1, 2, 1000);
        vm.stopPrank();
    }

    function test_UpdateConfig() public {
        vm.startPrank(admin);  // Use admin who has DEFAULT_ADMIN_ROLE
        IRebalancer.RebalanceConfig memory newConfig = IRebalancer.RebalanceConfig({
            minAPYDifferentialBps: 200,
            maxRebalanceAmount: 2_000_000 * 1e6,
            minRebalanceAmount: 2_000 * 1e6,
            rebalanceCooldown: 2 days,
            maxGasCostUSD: 100 * 1e6,
            targetAllocationRatio: 0
        });
        rebalancer.updateRebalanceConfig(newConfig);
        IRebalancer.RebalanceConfig memory updatedConfig = rebalancer.getRebalanceConfig();
        assertEq(updatedConfig.minAPYDifferentialBps, 200);
        assertEq(updatedConfig.maxRebalanceAmount, 2_000_000 * 1e6);
        assertEq(updatedConfig.minRebalanceAmount, 2_000 * 1e6);
        assertEq(updatedConfig.rebalanceCooldown, 2 days);
        assertEq(updatedConfig.maxGasCostUSD, 100 * 1e6);
        vm.stopPrank();
    }

    function test_UpdateMetrics() public {
        vm.startPrank(metricsUpdaterRoleHolder);
        rebalancer.updateChainMetrics(1, 500, 100_000 * 1e6);
        IRebalancer.ChainMetrics memory metrics = rebalancer.getChainMetrics(1);
        assertEq(metrics.chainId, 1);
        assertEq(metrics.currentAPY, 500);
        assertEq(metrics.deployedAmount, 100_000 * 1e6);
        vm.stopPrank();
    }

    function test_EvaluateRebalance_NoRebalanceNeeded() public {
        vm.startPrank(metricsUpdaterRoleHolder);
        rebalancer.updateChainMetrics(1, 500, 100_000 * 1e6);
        rebalancer.updateChainMetrics(2, 505, 100_000 * 1e6);
        vm.stopPrank();

        IRebalancer.RebalanceDecision memory decision = rebalancer.evaluateRebalance();
        assertFalse(decision.shouldExecute);
    }

    function test_EvaluateRebalance_RebalanceNeeded() public {
        vm.startPrank(metricsUpdaterRoleHolder);
        rebalancer.updateChainMetrics(1, 500, 100_000 * 1e6);
        rebalancer.updateChainMetrics(2, 600, 100_000 * 1e6);
        vm.stopPrank();

        // Warp past cooldown period
        vm.warp(block.timestamp + 1 days + 1);

        IRebalancer.RebalanceDecision memory decision = rebalancer.evaluateRebalance();
        assertTrue(decision.shouldExecute);
        assertEq(decision.sourceChainId, 1);
        assertEq(decision.targetChainId, 2);
    }

    function test_ExecuteRebalance() public {
        vm.startPrank(metricsUpdaterRoleHolder);
        rebalancer.updateChainMetrics(1, 500, 100_000 * 1e6);
        rebalancer.updateChainMetrics(2, 600, 100_000 * 1e6);
        vm.stopPrank();

        // Warp past cooldown period
        vm.warp(block.timestamp + 1 days + 1);

        IRebalancer.RebalanceDecision memory decision = rebalancer.evaluateRebalance();
        assertTrue(decision.shouldExecute);

        vm.startPrank(rebalancerRoleHolder);
        rebalancer.executeRebalance(decision);
        vm.stopPrank();

        assertTrue(mockMotherVault.rebalanceInitiated());
    }

    function test_ExecuteRebalance_FailsOnCooldown() public {
        vm.startPrank(metricsUpdaterRoleHolder);
        rebalancer.updateChainMetrics(1, 500, 100_000 * 1e6);
        rebalancer.updateChainMetrics(2, 600, 100_000 * 1e6);
        vm.stopPrank();

        // Warp past initial cooldown
        vm.warp(block.timestamp + 1 days + 1);

        IRebalancer.RebalanceDecision memory decision = rebalancer.evaluateRebalance();
        assertTrue(decision.shouldExecute);

        vm.startPrank(rebalancerRoleHolder);
        rebalancer.executeRebalance(decision);

        vm.warp(block.timestamp + 1 hours);

        IRebalancer.RebalanceDecision memory decision2 = rebalancer.evaluateRebalance();
        assertFalse(decision2.shouldExecute, "Should not execute due to cooldown");
    }

    function test_PauseAndUnpause() public {
        vm.startPrank(pauserRoleHolder);
        rebalancer.pause();
        assertTrue(rebalancer.paused());

        vm.startPrank(rebalancerRoleHolder);
        IRebalancer.RebalanceDecision memory decision;
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        rebalancer.executeRebalance(decision);
        vm.stopPrank();

        vm.startPrank(pauserRoleHolder);
        rebalancer.unpause();
        assertFalse(rebalancer.paused());
        vm.stopPrank();
    }
}