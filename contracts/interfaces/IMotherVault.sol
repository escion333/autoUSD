// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMotherVault is IERC4626 {
    
    struct ChildVault {
        uint32 domainId;      
        address vaultAddress;  
        uint256 lastReportTime;
        uint256 deployedAmount;
        uint256 reportedAPY;   
        bool isActive;         
    }
    
    struct StrategicDeployParams {
        uint32 targetChainId;
        uint256 amount;
        uint256 minAPYDifferential;
    }
    
    event ChildVaultAdded(uint32 indexed domainId, address indexed vault);
    event ChildVaultRemoved(uint32 indexed domainId, address indexed vault);
    event StrategicDeployInitiated(uint32 indexed targetChain, uint256 amount);
    event YieldReported(uint32 indexed domainId, uint256 apy, uint256 totalValue);
    event EmergencyPauseActivated(address indexed initiator);
    event DepositCapUpdated(uint256 oldCap, uint256 newCap);
    event FundsDeployedToChild(uint32 indexed domainId, uint256 amount, bytes32 indexed messageId);
    event WithdrawalRequestSent(uint32 indexed domainId, uint256 amount, bytes32 indexed messageId);
    event FundsReceivedFromChild(uint32 indexed sourceDomain, uint256 amount);
    event ManagementFeeCollected(uint256 feeAmount, address indexed feeSink);
    event EmergencyWithdrawal(address indexed recipient, uint256 amount);
    
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
    
    function handleIncomingMessage(uint32 origin, bytes32 sender, bytes calldata message) external;
    
    function handleCCTPReceive(uint256 amount, uint32 sourceDomain, bytes32 sender) external;
    
    function reportYield(uint32 domainId, uint256 apy, uint256 totalValue) external;
    
    function emergencyPause() external;
    
    function emergencyUnpause() external;
    
    function emergencyWithdrawAll() external;
    
    function setDepositCap(uint256 newCap) external;
    
    function setManagementFee(uint256 feeBps) external;
    
    function setRebalanceCooldown(uint256 cooldownPeriod) external;
    
    function setMinAPYDifferential(uint256 minDifferentialBps) external;
    
    function collectManagementFees() external returns (uint256 feeAmount);
    
    function lastRebalanceTime() external view returns (uint256);
    
    function managementFeeBps() external view returns (uint256);
    
    function rebalanceCooldown() external view returns (uint256);
    
    function minAPYDifferential() external view returns (uint256);
    
    function feeSink() external view returns (address);
    
    function isPaused() external view returns (bool);
}