// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title IMessageTransmitter
 * @notice Interface for Circle's CCTP MessageTransmitter contract
 * @dev Handles receiving and processing of cross-chain messages with attestations
 */
interface IMessageTransmitter {
    /**
     * @notice Receive and process a cross-chain message with attestation
     * @param message The message bytes from the source chain
     * @param attestation The attestation signature from Circle's attestation service
     * @return success Whether the message was successfully processed
     */
    function receiveMessage(
        bytes calldata message,
        bytes calldata attestation
    ) external returns (bool success);

    /**
     * @notice Check if a message has been received
     * @param messageHash Hash of the message
     * @return True if the message has been received
     */
    function usedNonces(bytes32 messageHash) external view returns (bool);

    /**
     * @notice Get the local domain ID
     * @return Local domain ID
     */
    function localDomain() external view returns (uint32);

    /**
     * @notice Get the maximum message body size
     * @return Maximum message body size in bytes
     */
    function maxMessageBodySize() external view returns (uint256);

    /**
     * @notice Replace a message
     * @param originalMessage Original message bytes
     * @param originalAttestation Original attestation
     * @param newMessageBody New message body
     * @param newDestinationCaller New destination caller
     */
    function replaceMessage(
        bytes calldata originalMessage,
        bytes calldata originalAttestation,
        bytes calldata newMessageBody,
        bytes32 newDestinationCaller
    ) external;

    event MessageReceived(
        address indexed caller,
        uint32 sourceDomain,
        uint64 indexed nonce,
        bytes32 sender,
        bytes messageBody
    );

    event MessageSent(
        bytes message
    );
}