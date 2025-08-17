// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title AggLayerAdapter
 * @notice Adapter for bridging USDC from Polygon to Katana via AggLayer Unified Bridge
 * @dev Implements the bridge interface for AggLayer/Polygon zkEVM Bridge V2
 */
contract AggLayerAdapter is Ownable(msg.sender), ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // AggLayer Unified Bridge interface
    interface IPolygonZkEVMBridge {
        function bridgeAsset(
            uint32 destinationNetwork,
            address destinationAddress,
            uint256 amount,
            address token,
            bool forceUpdateGlobalExitRoot,
            bytes calldata permitData
        ) external payable;
        
        function bridgeMessage(
            uint32 destinationNetwork,
            address destinationAddress,
            bool forceUpdateGlobalExitRoot,
            bytes calldata metadata
        ) external payable;
        
        function claimAsset(
            bytes32[32] calldata smtProof,
            uint32 index,
            bytes32 mainnetExitRoot,
            bytes32 rollupExitRoot,
            uint32 originNetwork,
            address originTokenAddress,
            uint32 destinationNetwork,
            address destinationAddress,
            uint256 amount,
            bytes calldata metadata
        ) external;
    }
    
    // State variables
    IPolygonZkEVMBridge public immutable bridge;
    address public immutable usdc;
    address public bridgeVault;
    address public katanaChildVault;
    
    // Network IDs (to be configured based on actual AggLayer deployment)
    uint32 public polygonNetworkId = 1; // Polygon network ID in AggLayer
    uint32 public katanaNetworkId = 2;  // Katana network ID in AggLayer
    
    // Events
    event BridgeInitiated(
        uint256 amount,
        address indexed recipient,
        uint32 destinationNetwork,
        bytes32 indexed txHash
    );
    event BridgeVaultUpdated(address indexed newVault);
    event KatanaVaultUpdated(address indexed newVault);
    event NetworkIdsUpdated(uint32 polygon, uint32 katana);
    
    constructor(
        address _bridge,
        address _usdc,
        address _bridgeVault
    ) {
        require(_bridge != address(0), "AggLayerAdapter: Invalid bridge");
        require(_usdc != address(0), "AggLayerAdapter: Invalid USDC");
        require(_bridgeVault != address(0), "AggLayerAdapter: Invalid vault");
        
        bridge = IPolygonZkEVMBridge(_bridge);
        usdc = _usdc;
        bridgeVault = _bridgeVault;
    }
    
    /**
     * @notice Bridge USDC to Katana network
     * @param amount Amount of USDC to bridge
     * @param recipient Recipient address on Katana
     */
    function bridgeToKatana(
        uint256 amount,
        address recipient
    ) external nonReentrant {
        require(msg.sender == bridgeVault, "AggLayerAdapter: Only BridgeVault");
        require(amount > 0, "AggLayerAdapter: Zero amount");
        require(recipient != address(0), "AggLayerAdapter: Invalid recipient");
        
        // Transfer USDC from BridgeVault
        IERC20(usdc).safeTransferFrom(msg.sender, address(this), amount);
        
        // Reset approval first then set new approval
        IERC20(usdc).forceApprove(address(bridge), amount);
        
        // Bridge assets to Katana
        // Send any ETH held by this contract as bridge fee
        uint256 ethBalance = address(this).balance;
        bridge.bridgeAsset{value: ethBalance}(
            katanaNetworkId,
            recipient,
            amount,
            usdc,
            true, // Force update global exit root
            "" // No permit data
        );
        
        emit BridgeInitiated(amount, recipient, katanaNetworkId, keccak256(abi.encode(block.timestamp, amount, recipient)));
    }
    
    /**
     * @notice Bridge USDC to Katana with custom network ID
     * @param amount Amount of USDC to bridge
     * @param recipient Recipient address on destination
     * @param destinationNetwork Custom destination network ID
     */
    function bridgeToNetwork(
        uint256 amount,
        address recipient,
        uint32 destinationNetwork
    ) external nonReentrant {
        require(msg.sender == bridgeVault || msg.sender == owner(), "AggLayerAdapter: Unauthorized");
        require(amount > 0, "AggLayerAdapter: Zero amount");
        require(recipient != address(0), "AggLayerAdapter: Invalid recipient");
        
        // Transfer USDC from sender
        IERC20(usdc).safeTransferFrom(msg.sender, address(this), amount);
        
        // Reset approval first then set new approval
        IERC20(usdc).forceApprove(address(bridge), amount);
        
        // Bridge assets
        // Send any ETH held by this contract as bridge fee
        uint256 ethBalance = address(this).balance;
        bridge.bridgeAsset{value: ethBalance}(
            destinationNetwork,
            recipient,
            amount,
            usdc,
            true,
            ""
        );
        
        emit BridgeInitiated(amount, recipient, destinationNetwork, keccak256(abi.encode(block.timestamp, amount, recipient)));
    }
    
    /**
     * @notice Claim bridged assets (called on destination chain)
     * @dev This would be called on Katana to claim USDC sent from Polygon
     */
    function claimAsset(
        bytes32[32] calldata smtProof,
        uint32 index,
        bytes32 mainnetExitRoot,
        bytes32 rollupExitRoot,
        uint32 originNetwork,
        address originTokenAddress,
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 amount,
        bytes calldata metadata
    ) external {
        bridge.claimAsset(
            smtProof,
            index,
            mainnetExitRoot,
            rollupExitRoot,
            originNetwork,
            originTokenAddress,
            destinationNetwork,
            destinationAddress,
            amount,
            metadata
        );
    }
    
    // Admin functions
    
    function setBridgeVault(address _vault) external onlyOwner {
        require(_vault != address(0), "AggLayerAdapter: Invalid vault");
        bridgeVault = _vault;
        emit BridgeVaultUpdated(_vault);
    }
    
    function setKatanaChildVault(address _vault) external onlyOwner {
        require(_vault != address(0), "AggLayerAdapter: Invalid vault");
        katanaChildVault = _vault;
        emit KatanaVaultUpdated(_vault);
    }
    
    function setNetworkIds(uint32 _polygon, uint32 _katana) external onlyOwner {
        polygonNetworkId = _polygon;
        katanaNetworkId = _katana;
        emit NetworkIdsUpdated(_polygon, _katana);
    }
    
    /**
     * @notice Fund adapter with ETH for bridge fees
     */
    function fundBridgeFees() external payable {
        require(msg.value > 0, "AggLayerAdapter: No ETH sent");
    }
    
    /**
     * @notice Get ETH balance for bridge fees
     */
    function getBridgeFeeBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @notice Emergency withdrawal function
     * @param token Token to withdraw (address(0) for ETH)
     * @param amount Amount to withdraw
     * @param recipient Recipient address
     */
    function emergencyWithdraw(
        address token,
        uint256 amount,
        address recipient
    ) external onlyOwner {
        require(recipient != address(0), "AggLayerAdapter: Invalid recipient");
        
        if (token == address(0)) {
            // Withdraw ETH
            (bool success, ) = recipient.call{value: amount}("");
            require(success, "AggLayerAdapter: ETH transfer failed");
        } else {
            // Withdraw token
            IERC20(token).safeTransfer(recipient, amount);
        }
    }
    
    // Receive ETH for bridge fees
    receive() external payable {}
}