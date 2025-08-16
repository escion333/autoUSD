// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IRebalancer {
    
    struct ChainMetrics {
        uint32 chainId;
        uint256 deployedAmount;
        uint256 currentAPY;
        uint256 lastUpdateTime;
        uint256 projectedYield;
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
    
    struct RebalanceConfig {
        uint256 minAPYDifferentialBps;  
        uint256 maxRebalanceAmount;     
        uint256 minRebalanceAmount;     
        uint256 rebalanceCooldown;      
        uint256 maxGasCostUSD;          
        uint256 targetAllocationRatio;  
    }
    
    event RebalanceTriggered(
        uint32 indexed fromChain,
        uint32 indexed toChain,
        uint256 amount,
        uint256 apyDifferential
    );
    
    event RebalanceCompleted(
        uint32 indexed fromChain,
        uint32 indexed toChain,
        uint256 amount,
        uint256 gasUsed
    );
    
    event MetricsUpdated(uint32 indexed chainId, uint256 apy, uint256 totalValue);
    
    event ConfigUpdated(string parameter, uint256 oldValue, uint256 newValue);
    
    error InsufficientAPYDifferential(uint256 actual, uint256 required);
    error RebalanceCooldownActive(uint256 remainingTime);
    error RebalanceAmountTooSmall(uint256 amount, uint256 minimum);
    error RebalanceAmountTooLarge(uint256 amount, uint256 maximum);
    error GasCostExceedsLimit(uint256 estimatedCost, uint256 limit);
    error NoRebalanceNeeded();
    
    function evaluateRebalance() external view returns (RebalanceDecision memory);
    
    function executeRebalance(RebalanceDecision calldata decision) external returns (bool);
    
    function updateChainMetrics(uint32 chainId, uint256 apy, uint256 totalValue) external;
    
    function getChainMetrics(uint32 chainId) external view returns (ChainMetrics memory);
    
    function getAllChainMetrics() external view returns (ChainMetrics[] memory);
    
    function calculateOptimalAllocation() external view returns (
        uint32[] memory chainIds,
        uint256[] memory allocations
    );
    
    function estimateRebalanceCost(
        uint32 sourceChain,
        uint32 targetChain,
        uint256 amount
    ) external view returns (uint256 gasCostUSD);
    
    function getRebalanceConfig() external view returns (RebalanceConfig memory);
    
    function updateRebalanceConfig(RebalanceConfig calldata config) external;
    
    function lastRebalanceTime() external view returns (uint256);
    
    function canRebalance() external view returns (bool);
    
    function getAPYDifferential(uint32 chain1, uint32 chain2) external view returns (uint256);
    
    function emergencyRebalance(
        uint32 sourceChain,
        uint32 targetChain,
        uint256 amount
    ) external;
}