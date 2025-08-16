// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IChildVault {
    
    struct YieldReport {
        uint256 totalDeposited;
        uint256 totalValue;     
        uint256 currentAPY;     
        uint256 timestamp;
        uint256 accrued;        
    }
    
    event DepositReceived(uint256 amount, uint256 totalDeposits);
    event WithdrawalInitiated(uint256 amount, address indexed recipient);
    event YieldReported(uint256 apy, uint256 totalValue, uint256 accrued);
    event YieldHarvested(uint256 amount);
    event EmergencyWithdrawal(uint256 amount);
    event StrategyUpdated(address indexed oldStrategy, address indexed newStrategy);
    
    error OnlyMotherVault();
    error InvalidAmount(uint256 amount);
    error InsufficientBalance(uint256 requested, uint256 available);
    error StrategyCallFailed(bytes reason);
    error NotPaused();
    error AlreadyPaused();
    
    function USDC() external view returns (IERC20);
    
    function motherVault() external view returns (address);
    
    function motherChainId() external view returns (uint32);
    
    function yieldStrategy() external view returns (address);
    
    function totalDeposited() external view returns (uint256);
    
    function totalValue() external view returns (uint256);
    
    function getYieldReport() external view returns (YieldReport memory);
    
    function depositFromMother(uint256 amount) external;
    
    function withdrawToMother(uint256 amount) external;
    
    function withdrawAllToMother() external;
    
    function reportYieldToMother() external;
    
    function calculateCurrentAPY() external view returns (uint256);
    
    function harvestYield() external returns (uint256);
    
    function emergencyWithdrawAll() external;
    
    function pause() external;
    
    function unpause() external;
    
    function isPaused() external view returns (bool);
    
    function setYieldStrategy(address newStrategy) external;
    
    function updateMotherVault(address newMotherVault) external;
}