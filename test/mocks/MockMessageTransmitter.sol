// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IMessageTransmitter} from "../../contracts/interfaces/CCTP/IMessageTransmitter.sol";

contract MockMessageTransmitter is IMessageTransmitter {
    uint32 private _localDomain = 6;
    uint64 private _nextNonce = 1;
    uint256 private _maxMessageBodySize = 8192;
    bool private _receiveMessageResult = true;
    
    mapping(bytes32 => bool) public usedNonces;
    
    function replaceMessage(
        bytes calldata originalMessage,
        bytes calldata originalAttestation,
        bytes calldata newMessageBody,
        bytes32 newDestinationCaller
    ) external override {
    }
    
    function receiveMessage(
        bytes calldata message,
        bytes calldata attestation
    ) external override returns (bool success) {
        bytes32 messageHash = keccak256(message);
        require(!usedNonces[messageHash], "Nonce already used");
        
        if (_receiveMessageResult) {
            usedNonces[messageHash] = true;
        }
        
        return _receiveMessageResult;
    }
    
    function setReceiveMessageResult(bool result) external {
        _receiveMessageResult = result;
    }
    
    function localDomain() external view override returns (uint32) {
        return _localDomain;
    }
    
    function maxMessageBodySize() external view override returns (uint256) {
        return _maxMessageBodySize;
    }
}