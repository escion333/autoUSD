// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title IBridgeVault
 * @notice Interface for intermediate bridge vault on Polygon
 */
interface IBridgeVault {
    // Events
    event FundsReceived(uint256 amount, address from);
    event FundsBridgedToKatana(uint256 amount);
    event FundsReturnedToBase(uint256 amount, address recipient);
    
    // Functions
    function receiveFromBase(uint256 amount) external;
    function bridgeToKatana() external;
    function returnToBase(uint256 amount, address recipient) external;
    function setMotherVault(address _motherVault) external;
    function setCCTPBridge(address _bridge) external;
    function setAggLayerAdapter(address _adapter) external;
    function setMinBridgeAmount(uint256 _amount) external;
    function setBridgeCooldown(uint256 _cooldown) external;
    
    // View functions
    function asset() external view returns (address);
    function owner() external view returns (address);
    function motherVault() external view returns (address);
    function cctpBridge() external view returns (address);
    function aggLayerAdapter() external view returns (address);
    function minBridgeAmount() external view returns (uint256);
    function bridgeCooldown() external view returns (uint256);
    function lastBridgeTime() external view returns (uint256);
}