// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface ICrossChainMessenger {
    
    enum MessageType {
        DEPOSIT_REQUEST,
        WITHDRAWAL_REQUEST,
        YIELD_REPORT,
        REBALANCE_COMMAND,
        EMERGENCY_PAUSE,
        EMERGENCY_UNPAUSE,
        EMERGENCY_WITHDRAW_ALL
    }
    
    struct CrossChainMessage {
        MessageType messageType;
        uint32 targetChainId;
        address targetVault;
        bytes payload;
        uint256 nonce;
        uint256 timestamp;
    }
    
    event MessageSent(
        uint32 indexed targetChainId,
        MessageType indexed messageType,
        bytes32 messageId,
        uint256 nonce
    );
    
    event MessageReceived(
        uint32 indexed sourceChainId,
        MessageType indexed messageType,
        bytes32 messageId,
        uint256 nonce
    );
    
    event MessageProcessed(
        bytes32 indexed messageId,
        bool success,
        bytes returnData
    );
    
    error InvalidMessageType(uint8 messageType);
    error InvalidSourceChain(uint32 chainId);
    error InvalidSender(address sender);
    error MessageAlreadyProcessed(bytes32 messageId);
    error MessageProcessingFailed(bytes reason);
    
    function sendCrossChainMessage(CrossChainMessage calldata message) external payable returns (bytes32 messageId);
    
    function handle(
        uint32 origin,
        bytes32 sender,
        bytes calldata message
    ) external;
    
    function getMessageStatus(bytes32 messageId) external view returns (bool processed, bool success);
    
    function estimateMessageFee(uint32 targetChainId, bytes calldata message) external view returns (uint256);
    
    function getHyperlaneMailbox() external view returns (address);
    
    function getCCTPTokenMessenger() external view returns (address);
    
    function getInterchainGasPaymaster() external view returns (address);
}