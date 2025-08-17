// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title ICCTPBridge
 * @notice Interface for CCTP Bridge operations
 */
interface ICCTPBridge {
    // Events
    event TokensBurned(uint256 amount, uint32 destinationDomain, address recipient);
    event TokensMinted(uint256 amount, address recipient);
    event MessageSent(bytes32 messageId, uint32 destinationDomain);
    event MessageReceived(bytes32 messageId, uint32 sourceDomain);
    
    // Core functions
    function burnAndSend(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken
    ) external returns (uint64 nonce);
    
    function receiveMessage(
        bytes calldata message,
        bytes calldata attestation
    ) external returns (bool success);
    
    // Bridge USDC to another chain
    function bridgeUSDC(
        uint256 amount, 
        uint256 destinationChainId, 
        address recipient
    ) external returns (uint64 nonce);
    
    // Configuration functions
    function setSupportedDomain(uint32 domain, bool supported) external;
    function setMotherVault(address vault) external;
    
    // View functions
    function tokenMessenger() external view returns (address);
    function messageTransmitter() external view returns (address);
    function usdc() external view returns (address);
    function supportedDomains(uint32 domain) external view returns (bool);
}