// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title IEthereumBridgeHub
 * @notice Interface for the Ethereum bridge hub that routes between Base and Katana
 * @dev Handles CCTP from Base and Unified Bridge to Katana
 */
interface IEthereumBridgeHub {
    // Events
    event RelayedToKatana(uint256 amount, address recipient);
    event RelayedToBase(uint256 amount, address recipient);
    event HyperlaneMessageProcessed(bytes32 messageId);
    
    // Errors
    error UnauthorizedSender();
    error InvalidAddress();
    error InvalidAmount();
    error BridgeFailed();
    
    // Core bridge functions
    function relayToKatana(uint256 amount, address recipient) external;
    function relayToBase(uint256 amount, address recipient) external;
    function receiveFromBase(uint256 amount) external;
    function receiveFromKatana(uint256 amount) external;
    
    // Hyperlane message handling
    function handle(
        uint32 origin,
        bytes32 sender,
        bytes calldata message
    ) external payable;
    
    // Admin functions
    function setMotherVault(address _motherVault) external;
    function setKatanaChildVault(address _vault) external;
    function pause() external;
    function unpause() external;
    function emergencyWithdraw(
        address token,
        uint256 amount,
        address recipient
    ) external;
    
    // View functions
    function usdc() external view returns (address);
    function cctpBridge() external view returns (address);
    function unifiedBridge() external view returns (address);
    function hyperlaneMailbox() external view returns (address);
    function motherVault() external view returns (address);
    function katanaChildVault() external view returns (address);
    function owner() external view returns (address);
    function getBalance() external view returns (uint256);
    function getBridgeStats() external view returns (
        uint256 fromBase,
        uint256 toKatana,
        uint256 fromKatana,
        uint256 toBase,
        uint256 currentBalance
    );
    
    // Constants
    function BASE_CCTP_DOMAIN() external view returns (uint32);
    function ETHEREUM_CCTP_DOMAIN() external view returns (uint32);
    function KATANA_NETWORK_ID() external view returns (uint32);
    
    // Tracking variables
    function totalFromBase() external view returns (uint256);
    function totalToKatana() external view returns (uint256);
    function totalFromKatana() external view returns (uint256);
    function totalToBase() external view returns (uint256);
}