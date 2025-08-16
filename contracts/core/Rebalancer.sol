// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IRebalancer } from "../interfaces/IRebalancer.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IMotherVault } from "../interfaces/IMotherVault.sol";

interface IMotherVaultWithBuffer is IMotherVault {
    function getDeployableAmount() external view returns (uint256);
    function isBufferSufficient() external view returns (bool);
}

interface IMotherVaultWithRebalance is IMotherVault {
    function initiateRebalance(uint32 sourceChainId, uint32 targetChainId, uint256 amount) external;
    function deployToChildVault(uint32 domainId, uint256 amount) external;
}

contract Rebalancer is IRebalancer, ReentrancyGuard, Pausable, AccessControl {
    bytes32 public constant REBALANCER_ROLE = keccak256("REBALANCER_ROLE");
    bytes32 public constant METRICS_UPDATER_ROLE = keccak256("METRICS_UPDATER_ROLE");

    IMotherVault public motherVault;
    mapping(uint32 => ChainMetrics) public chainMetrics;
    uint32[] public activeChains;
    RebalanceConfig public rebalanceConfig;
    uint256 private _lastRebalanceTime;
    uint256 public bufferThreshold = 500; // 5% in basis points

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    constructor(address _motherVault) {
        if (_motherVault == address(0)) {
            revert("Zero address not allowed");
        }
        motherVault = IMotherVault(_motherVault);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REBALANCER_ROLE, msg.sender);
        _grantRole(METRICS_UPDATER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);

        rebalanceConfig = RebalanceConfig({
            minAPYDifferentialBps: 100, // 1%
            maxRebalanceAmount: 1_000_000 * 1e6, // 1M USDC
            minRebalanceAmount: 1_000 * 1e6, // 1k USDC
            rebalanceCooldown: 1 days,
            maxGasCostUSD: 50 * 1e6, // $50
            targetAllocationRatio: 0
        });
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function evaluateRebalance() external view override returns (RebalanceDecision memory decision) {
        // First, check buffer sufficiency
        if (!checkBufferBeforeRebalance()) {
            return RebalanceDecision(0, 0, 0, 0, 0, false, "Buffer insufficient");
        }
        
        // Check if there are idle funds to deploy (above buffer requirement)
        uint256 deployableAmount = getDeployableAmount();
        if (deployableAmount >= rebalanceConfig.minRebalanceAmount) {
            uint32 bestTargetChain = 0;
            uint256 bestApy = 0;
            for (uint i = 0; i < activeChains.length; i++) {
                uint32 chainId = activeChains[i];
                if (chainMetrics[chainId].currentAPY > bestApy) {
                    bestApy = chainMetrics[chainId].currentAPY;
                    bestTargetChain = chainId;
                }
            }
            if (bestTargetChain != 0) {
                 return RebalanceDecision(
                    0, // Source chain 0 indicates deploying idle funds
                    bestTargetChain,
                    deployableAmount > rebalanceConfig.maxRebalanceAmount ? rebalanceConfig.maxRebalanceAmount : deployableAmount,
                    bestApy,
                    0,
                    true,
                    "Deploy idle funds"
                );
            }
        }
        
        uint256 chainsCount = activeChains.length;
        if (chainsCount < 2) {
            return RebalanceDecision(0, 0, 0, 0, 0, false, "Insufficient active chains");
        }

        uint32 sourceChainId = 0;
        uint32 targetChainId = 0;
        uint256 lowestApy = type(uint256).max;
        uint256 highestApy = 0;

        for (uint i = 0; i < chainsCount; i++) {
            uint32 chainId = activeChains[i];
            ChainMetrics memory metrics = chainMetrics[chainId];
            if (metrics.currentAPY < lowestApy) {
                lowestApy = metrics.currentAPY;
                sourceChainId = chainId;
            }
            if (metrics.currentAPY > highestApy) {
                highestApy = metrics.currentAPY;
                targetChainId = chainId;
            }
        }

        if (sourceChainId == targetChainId || highestApy <= lowestApy) {
            return RebalanceDecision(0, 0, 0, 0, 0, false, "No APY differential");
        }

        uint256 apyDifferentialBps = (highestApy - lowestApy) * 10_000 / lowestApy;
        if (apyDifferentialBps < rebalanceConfig.minAPYDifferentialBps) {
            return RebalanceDecision(
                sourceChainId,
                targetChainId,
                0,
                apyDifferentialBps,
                0,
                false,
                "APY differential too low"
            );
        }

        uint256 amountToMove = chainMetrics[sourceChainId].deployedAmount / 2;
        if (amountToMove > rebalanceConfig.maxRebalanceAmount) {
            amountToMove = rebalanceConfig.maxRebalanceAmount;
        }

        if (amountToMove < rebalanceConfig.minRebalanceAmount) {
            return RebalanceDecision(
                sourceChainId,
                targetChainId,
                amountToMove,
                apyDifferentialBps,
                0,
                false,
                "Amount too small"
            );
        }

        uint256 estimatedGasCost = estimateRebalanceCost(sourceChainId, targetChainId, amountToMove);
        if (estimatedGasCost > rebalanceConfig.maxGasCostUSD) {
            return RebalanceDecision(
                sourceChainId,
                targetChainId,
                amountToMove,
                apyDifferentialBps,
                estimatedGasCost,
                false,
                "Gas cost too high"
            );
        }

        if (block.timestamp < _lastRebalanceTime + rebalanceConfig.rebalanceCooldown) {
            return RebalanceDecision(
                sourceChainId,
                targetChainId,
                amountToMove,
                apyDifferentialBps,
                estimatedGasCost,
                false,
                "Cooldown active"
            );
        }

        return RebalanceDecision(
            sourceChainId,
            targetChainId,
            amountToMove,
            apyDifferentialBps,
            estimatedGasCost,
            true,
            "Rebalance recommended"
        );
    }

    function updateChainMetrics(uint32 chainId, uint256 apy, uint256 totalValue)
        external
        override
        onlyRole(METRICS_UPDATER_ROLE)
    {
        if (chainMetrics[chainId].lastUpdateTime == 0) {
            activeChains.push(chainId);
        }
        chainMetrics[chainId] = ChainMetrics({
            chainId: chainId,
            deployedAmount: totalValue,
            currentAPY: apy,
            lastUpdateTime: block.timestamp,
            projectedYield: (totalValue * apy) / 10_000
        });
        emit MetricsUpdated(chainId, apy, totalValue);
    }

    function getChainMetrics(uint32 chainId) external view override returns (ChainMetrics memory) {
        return chainMetrics[chainId];
    }

    function getAllChainMetrics() external view override returns (ChainMetrics[] memory) {
        uint256 chainCount = activeChains.length;
        ChainMetrics[] memory allMetrics = new ChainMetrics[](chainCount);
        for (uint i = 0; i < chainCount; i++) {
            allMetrics[i] = chainMetrics[activeChains[i]];
        }
        return allMetrics;
    }

    function calculateOptimalAllocation()
        external
        view
        override
        returns (uint32[] memory chainIds, uint256[] memory allocations)
    {
        uint256 totalAssets = 0;
        uint chainCount = activeChains.length;
        for (uint i = 0; i < chainCount; i++) {
            totalAssets += chainMetrics[activeChains[i]].deployedAmount;
        }

        if (totalAssets == 0) {
            return (new uint32[](0), new uint256[](0));
        }

        chainIds = new uint32[](chainCount);
        allocations = new uint256[](chainCount);

        uint256 totalYield = 0;
        for (uint i = 0; i < chainCount; i++) {
            totalYield += chainMetrics[activeChains[i]].projectedYield;
        }

        if (totalYield == 0) {
            // If no yield, propose equal allocation
            for (uint i = 0; i < chainCount; i++) {
                chainIds[i] = activeChains[i];
                allocations[i] = (totalAssets * 1e18) / chainCount;
            }
            return (chainIds, allocations);
        }

        for (uint i = 0; i < chainCount; i++) {
            uint32 chainId = activeChains[i];
            chainIds[i] = chainId;
            allocations[i] = (chainMetrics[chainId].projectedYield * totalAssets * 1e18) / totalYield;
        }

        return (chainIds, allocations);
    }

    function getRebalanceConfig() external view override returns (RebalanceConfig memory) {
        return rebalanceConfig;
    }

    function updateRebalanceConfig(RebalanceConfig calldata newConfig) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        emit ConfigUpdated("minAPYDifferentialBps", rebalanceConfig.minAPYDifferentialBps, newConfig.minAPYDifferentialBps);
        emit ConfigUpdated("maxRebalanceAmount", rebalanceConfig.maxRebalanceAmount, newConfig.maxRebalanceAmount);
        emit ConfigUpdated("minRebalanceAmount", rebalanceConfig.minRebalanceAmount, newConfig.minRebalanceAmount);
        emit ConfigUpdated("rebalanceCooldown", rebalanceConfig.rebalanceCooldown, newConfig.rebalanceCooldown);
        emit ConfigUpdated("maxGasCostUSD", rebalanceConfig.maxGasCostUSD, newConfig.maxGasCostUSD);
        rebalanceConfig = newConfig;
    }

    function lastRebalanceTime() external view override returns (uint256) {
        return _lastRebalanceTime;
    }

    function canRebalance() external view override returns (bool) {
        return block.timestamp >= _lastRebalanceTime + rebalanceConfig.rebalanceCooldown;
    }

    function getAPYDifferential(uint32 chain1, uint32 chain2) external view override returns (uint256) {
        uint256 apy1 = chainMetrics[chain1].currentAPY;
        uint256 apy2 = chainMetrics[chain2].currentAPY;
        if (apy1 > apy2) {
            return ((apy1 - apy2) * 10_000) / apy2;
        } else {
            return ((apy2 - apy1) * 10_000) / apy1;
        }
    }

    function executeRebalance(RebalanceDecision calldata decision)
        external
        override
        onlyRole(REBALANCER_ROLE)
        whenNotPaused
        nonReentrant
        returns (bool)
    {
        require(decision.shouldExecute, "Decision not executable");
        
        // Double-check buffer before execution
        require(checkBufferBeforeRebalance(), "Buffer insufficient for execution");
        
        // Update last rebalance time
        _lastRebalanceTime = block.timestamp;

        if (decision.sourceChainId == 0) {
            // Deploy idle funds to the best chain (only deployable amount above buffer)
            uint256 maxDeployable = getDeployableAmount();
            uint256 actualAmount = decision.amountToMove > maxDeployable ? maxDeployable : decision.amountToMove;
            require(actualAmount > 0, "No deployable amount available");
            
            IMotherVaultWithRebalance(address(motherVault)).deployToChildVault(
                decision.targetChainId,
                actualAmount
            );
        } else {
            // Execute inter-chain rebalance through MotherVault
            IMotherVaultWithRebalance(address(motherVault)).initiateRebalance(
                decision.sourceChainId,
                decision.targetChainId,
                decision.amountToMove
            );
        }
        
        emit RebalanceTriggered(
            decision.sourceChainId,
            decision.targetChainId,
            decision.amountToMove,
            decision.expectedAPYImprovement
        );
        
        return true;
    }

    function estimateRebalanceCost(
        uint32 sourceChain,
        uint32 targetChain,
        uint256 amount
    ) public pure override returns (uint256 gasCostUSD) {
        // Base cost for CCTP bridge + Hyperlane messaging
        uint256 baseCost = 10 * 1e6; // $10 base
        
        // Additional cost based on amount (simulating gas scaling)
        uint256 amountFactor = (amount / 100_000e6); // per 100k USDC
        uint256 scaledCost = amountFactor * 2 * 1e6; // $2 per 100k
        
        return baseCost + scaledCost;
    }

    function emergencyRebalance(uint32 sourceChain, uint32 targetChain, uint256 amount)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        IMotherVaultWithRebalance(address(motherVault)).initiateRebalance(sourceChain, targetChain, amount);

        emit RebalanceTriggered(sourceChain, targetChain, amount, 0);
    }

    function getDeployableAmount() public view returns (uint256) {
        return IMotherVaultWithBuffer(address(motherVault)).getDeployableAmount();
    }

    function checkBufferBeforeRebalance() internal view returns (bool) {
        return IMotherVaultWithBuffer(address(motherVault)).isBufferSufficient();
    }
}

