// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/ICCTPBridge.sol";
import "./interfaces/Hyperlane/IMessageRecipient.sol";

// Unified Bridge interface for Ethereum-Katana bridging
interface IUnifiedBridge {
    function bridgeAsset(
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 amount,
        address token,
        bool forceUpdateGlobalExitRoot,
        bytes calldata permitData
    ) external payable;
}

/**
 * @title EthereumBridgeHub
 * @notice Lightweight bridge hub on Ethereum Sepolia for routing between Base and Katana
 * @dev Handles CCTP from Base and Unified Bridge to Katana
 */
contract EthereumBridgeHub is Ownable(msg.sender), ReentrancyGuard, Pausable, IMessageRecipient {
    using SafeERC20 for IERC20;

    // Core components
    IERC20 public immutable usdc;
    ICCTPBridge public immutable cctpBridge;
    IUnifiedBridge public immutable unifiedBridge;
    address public immutable hyperlaneMailbox;
    
    // Network configuration
    uint32 public constant BASE_CCTP_DOMAIN = 10002;
    uint32 public constant ETHEREUM_CCTP_DOMAIN = 0;
    uint32 public constant KATANA_NETWORK_ID = 29; // For Unified Bridge
    
    // Addresses
    address public motherVault;
    address public katanaChildVault;
    
    // Tracking
    uint256 public totalFromBase;
    uint256 public totalToKatana;
    uint256 public totalFromKatana;
    uint256 public totalToBase;
    
    // Events
    event RelayedToKatana(uint256 amount, address recipient);
    event RelayedToBase(uint256 amount, address recipient);
    event HyperlaneMessageProcessed(bytes32 messageId);
    
    // Errors
    error UnauthorizedSender();
    error InvalidAddress();
    error InvalidAmount();
    error BridgeFailed();
    
    modifier onlyAuthorized() {
        if (msg.sender != owner() && msg.sender != motherVault && msg.sender != address(cctpBridge)) {
            revert UnauthorizedSender();
        }
        _;
    }
    
    constructor(
        address _usdc,
        address _cctpBridge,
        address _unifiedBridge,
        address _hyperlaneMailbox
    ) {
        if (_usdc == address(0)) revert InvalidAddress();
        if (_cctpBridge == address(0)) revert InvalidAddress();
        if (_unifiedBridge == address(0)) revert InvalidAddress();
        if (_hyperlaneMailbox == address(0)) revert InvalidAddress();
        
        usdc = IERC20(_usdc);
        cctpBridge = ICCTPBridge(_cctpBridge);
        unifiedBridge = IUnifiedBridge(_unifiedBridge);
        hyperlaneMailbox = _hyperlaneMailbox;
    }
    
    /**
     * @notice Relay USDC from Base to Katana
     * @dev Called after receiving USDC via CCTP from Base
     * @param amount Amount of USDC to relay
     * @param recipient Final recipient on Katana
     */
    function relayToKatana(uint256 amount, address recipient) external onlyAuthorized nonReentrant whenNotPaused {
        if (amount == 0) revert InvalidAmount();
        if (recipient == address(0)) revert InvalidAddress();
        
        // Ensure we have the USDC
        uint256 balance = usdc.balanceOf(address(this));
        if (balance < amount) revert InvalidAmount();
        
        // Approve Unified Bridge
        usdc.forceApprove(address(unifiedBridge), amount);
        
        // Bridge to Katana via Unified Bridge (may require ETH for gas)
        uint256 bridgeFee = address(this).balance > 0.001 ether ? 0.001 ether : address(this).balance;
        try unifiedBridge.bridgeAsset{value: bridgeFee}(
            KATANA_NETWORK_ID,
            recipient,
            amount,
            address(usdc),
            true, // forceUpdateGlobalExitRoot
            "" // no permit data
        ) {
            totalToKatana += amount;
            emit RelayedToKatana(amount, recipient);
        } catch {
            revert BridgeFailed();
        }
    }
    
    /**
     * @notice Relay USDC from Katana back to Base
     * @dev Called after receiving USDC from Katana via Unified Bridge
     * @param amount Amount of USDC to relay
     * @param recipient Final recipient on Base
     */
    function relayToBase(uint256 amount, address recipient) external onlyAuthorized nonReentrant whenNotPaused {
        if (amount == 0) revert InvalidAmount();
        if (recipient == address(0)) revert InvalidAddress();
        
        // Ensure we have the USDC
        uint256 balance = usdc.balanceOf(address(this));
        if (balance < amount) revert InvalidAmount();
        
        // Approve CCTP Bridge
        usdc.forceApprove(address(cctpBridge), amount);
        
        // Bridge back to Base via CCTP
        try cctpBridge.bridgeUSDC(
            amount,
            BASE_CCTP_DOMAIN, // Base Sepolia CCTP domain (10002)
            recipient
        ) {
            totalToBase += amount;
            emit RelayedToBase(amount, recipient);
        } catch {
            revert BridgeFailed();
        }
    }
    
    /**
     * @notice Handle incoming Hyperlane messages
     * @dev Implements IMessageRecipient for cross-chain coordination
     */
    function handle(
        uint32 origin,
        bytes32 sender,
        bytes calldata message
    ) external payable override {
        // Only accept messages from Hyperlane mailbox
        require(msg.sender == hyperlaneMailbox, "EthereumBridgeHub: Invalid mailbox");
        
        // Process the message (decode and route appropriately)
        // This is simplified - actual implementation would decode and handle various message types
        emit HyperlaneMessageProcessed(keccak256(abi.encode(origin, sender, message)));
    }
    
    /**
     * @notice Process incoming USDC from CCTP
     * @dev Called by CCTP bridge when receiving from Base
     */
    function receiveFromBase(uint256 amount) external {
        require(msg.sender == address(cctpBridge), "EthereumBridgeHub: Only CCTP");
        totalFromBase += amount;
        
        // Auto-relay to Katana if child vault is set and we have balance
        if (katanaChildVault != address(0) && usdc.balanceOf(address(this)) >= amount) {
            relayToKatana(amount, katanaChildVault);
        }
    }
    
    /**
     * @notice Process incoming USDC from Unified Bridge
     * @dev Called when receiving from Katana
     */
    function receiveFromKatana(uint256 amount) external {
        // In practice, Unified Bridge would transfer directly
        // This is for tracking purposes
        totalFromKatana += amount;
        
        // Auto-relay to Base if mother vault is set and we have balance
        if (motherVault != address(0) && usdc.balanceOf(address(this)) >= amount) {
            relayToBase(amount, motherVault);
        }
    }
    
    // Admin functions
    
    function setMotherVault(address _motherVault) external onlyOwner {
        if (_motherVault == address(0)) revert InvalidAddress();
        motherVault = _motherVault;
    }
    
    function setKatanaChildVault(address _vault) external onlyOwner {
        if (_vault == address(0)) revert InvalidAddress();
        katanaChildVault = _vault;
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @notice Emergency withdrawal
     * @dev Only for recovery in case of bridge issues
     */
    function emergencyWithdraw(
        address token,
        uint256 amount,
        address recipient
    ) external onlyOwner {
        if (recipient == address(0)) revert InvalidAddress();
        
        if (token == address(0)) {
            // Withdraw ETH
            (bool success, ) = recipient.call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            // Withdraw token
            IERC20(token).safeTransfer(recipient, amount);
        }
    }
    
    // Allow contract to receive ETH for bridge fees
    receive() external payable {}
    
    // View functions
    
    function getBalance() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }
    
    function getETHBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    function getBridgeStats() external view returns (
        uint256 fromBase,
        uint256 toKatana,
        uint256 fromKatana,
        uint256 toBase,
        uint256 currentBalance
    ) {
        return (
            totalFromBase,
            totalToKatana,
            totalFromKatana,
            totalToBase,
            usdc.balanceOf(address(this))
        );
    }
}