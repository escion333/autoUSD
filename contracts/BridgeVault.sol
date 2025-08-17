// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IBridgeVault.sol";
import "./interfaces/ICCTPBridge.sol";

// Interface for AggLayer adapter
interface IAggLayerAdapter {
    function bridgeToKatana(uint256 amount, address recipient) external;
}

/**
 * @title BridgeVault
 * @notice Intermediate vault on Polygon for bridging between Base and Katana
 * @dev Handles CCTP from Base and AggLayer bridging to Katana
 */
contract BridgeVault is IBridgeVault, Ownable(msg.sender), ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // State variables
    IERC20 private immutable _asset; // USDC
    address public motherVault;
    address public cctpBridge;
    address public aggLayerAdapter;
    
    uint256 public minBridgeAmount = 10 * 1e6; // $10 minimum
    uint256 public bridgeCooldown = 1 hours;
    uint256 public lastBridgeTime;
    
    // Katana network configuration
    uint32 public constant KATANA_DOMAIN = 100; // Custom domain for Katana (not CCTP)
    address public katanaChildVault;
    
    // Tracking
    uint256 public totalReceived;
    uint256 public totalBridgedToKatana;
    uint256 public totalReturnedToBase;
    
    modifier onlyAuthorized() {
        require(
            msg.sender == owner() || 
            msg.sender == motherVault,
            "BridgeVault: Unauthorized"
        );
        _;
    }
    
    modifier onlyBridge() {
        require(
            msg.sender == cctpBridge,
            "BridgeVault: Only CCTP bridge"
        );
        _;
    }
    
    constructor(
        address asset_,
        address _motherVault,
        address _cctpBridge
    ) {
        require(asset_ != address(0), "BridgeVault: Invalid asset");
        require(_motherVault != address(0), "BridgeVault: Invalid mother vault");
        require(_cctpBridge != address(0), "BridgeVault: Invalid CCTP bridge");
        
        _asset = IERC20(asset_);
        motherVault = _motherVault;
        cctpBridge = _cctpBridge;
    }
    
    /**
     * @notice Receive funds from Base via CCTP
     * @param amount Amount of USDC received
     */
    function receiveFromBase(uint256 amount) external override onlyAuthorized nonReentrant {
        require(amount > 0, "BridgeVault: Zero amount");
        
        // Transfer USDC from sender
        _asset.safeTransferFrom(msg.sender, address(this), amount);
        
        totalReceived += amount;
        emit FundsReceived(amount, msg.sender);
        
        // Auto-bridge if conditions met
        if (_shouldAutoBridge()) {
            _bridgeToKatana();
        }
    }
    
    /**
     * @notice Bridge accumulated funds to Katana via AggLayer
     */
    function bridgeToKatana() external override onlyAuthorized whenNotPaused {
        _bridgeToKatana();
    }
    
    /**
     * @notice Internal bridge logic
     */
    function _bridgeToKatana() private {
        uint256 balance = _asset.balanceOf(address(this));
        require(balance >= minBridgeAmount, "BridgeVault: Below minimum");
        require(
            block.timestamp >= lastBridgeTime + bridgeCooldown,
            "BridgeVault: Cooldown active"
        );
        require(aggLayerAdapter != address(0), "BridgeVault: No adapter");
        require(katanaChildVault != address(0), "BridgeVault: No child vault");
        
        // Approve AggLayer adapter to spend USDC
        _asset.forceApprove(aggLayerAdapter, balance);
        
        // Bridge to Katana via AggLayer adapter
        // The adapter will handle the actual bridge call to AggLayer Unified Bridge
        IAggLayerAdapter(aggLayerAdapter).bridgeToKatana(
            balance,
            katanaChildVault
        );
        
        totalBridgedToKatana += balance;
        lastBridgeTime = block.timestamp;
        
        emit FundsBridgedToKatana(balance);
    }
    
    /**
     * @notice Return funds to Base via CCTP
     * @param amount Amount to return
     * @param recipient Recipient on Base
     */
    function returnToBase(
        uint256 amount,
        address recipient
    ) external override onlyAuthorized nonReentrant {
        require(amount > 0, "BridgeVault: Zero amount");
        require(recipient != address(0), "BridgeVault: Invalid recipient");
        
        uint256 balance = _asset.balanceOf(address(this));
        require(balance >= amount, "BridgeVault: Insufficient balance");
        
        // Approve CCTP bridge
        _asset.forceApprove(cctpBridge, amount);
        
        // Bridge back to Base
        ICCTPBridge(cctpBridge).bridgeUSDC(
            amount,
            84532, // Base Sepolia chain ID (testnet)
            recipient
        );
        
        totalReturnedToBase += amount;
        emit FundsReturnedToBase(amount, recipient);
    }
    
    /**
     * @notice Check if auto-bridge conditions are met
     */
    function _shouldAutoBridge() private view returns (bool) {
        uint256 balance = _asset.balanceOf(address(this));
        return balance >= minBridgeAmount && 
               block.timestamp >= lastBridgeTime + bridgeCooldown &&
               aggLayerAdapter != address(0) &&
               katanaChildVault != address(0);
    }
    
    // Admin functions
    
    function setMotherVault(address _motherVault) external override onlyOwner {
        require(_motherVault != address(0), "BridgeVault: Invalid address");
        motherVault = _motherVault;
    }
    
    function setCCTPBridge(address _bridge) external override onlyOwner {
        require(_bridge != address(0), "BridgeVault: Invalid address");
        cctpBridge = _bridge;
    }
    
    function setAggLayerAdapter(address _adapter) external override onlyOwner {
        require(_adapter != address(0), "BridgeVault: Invalid address");
        aggLayerAdapter = _adapter;
    }
    
    function setKatanaChildVault(address _vault) external onlyOwner {
        require(_vault != address(0), "BridgeVault: Invalid address");
        katanaChildVault = _vault;
    }
    
    function setMinBridgeAmount(uint256 _amount) external override onlyOwner {
        require(_amount > 0, "BridgeVault: Zero amount");
        minBridgeAmount = _amount;
    }
    
    function setBridgeCooldown(uint256 _cooldown) external override onlyOwner {
        bridgeCooldown = _cooldown;
    }
    
    // Emergency functions
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    function emergencyWithdraw(
        address token,
        uint256 amount,
        address recipient
    ) external onlyOwner {
        require(recipient != address(0), "BridgeVault: Invalid recipient");
        
        if (token == address(0)) {
            // Withdraw ETH
            (bool success, ) = recipient.call{value: amount}("");
            require(success, "BridgeVault: ETH transfer failed");
        } else {
            // Withdraw token
            IERC20(token).safeTransfer(recipient, amount);
        }
    }
    
    // View functions
    
    function asset() external view override returns (address) {
        return address(_asset);
    }
    
    function owner() public view override(Ownable, IBridgeVault) returns (address) {
        return Ownable.owner();
    }
    
    function getBalance() external view returns (uint256) {
        return _asset.balanceOf(address(this));
    }
    
    function getStats() external view returns (
        uint256 received,
        uint256 bridged,
        uint256 returned,
        uint256 currentBalance
    ) {
        return (
            totalReceived,
            totalBridgedToKatana,
            totalReturnedToBase,
            _asset.balanceOf(address(this))
        );
    }
}