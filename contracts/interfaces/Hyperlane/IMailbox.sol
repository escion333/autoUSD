// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title IMailbox
 * @notice Interface for Hyperlane V3 Mailbox contract
 * @dev Handles sending and receiving of cross-chain messages
 */
interface IMailbox {
    /**
     * @notice Dispatch a message to another chain
     * @param destinationDomain The domain ID of the destination chain
     * @param recipientAddress The recipient address on the destination chain (bytes32 format)
     * @param messageBody The message content to send
     * @return messageId The unique identifier for this message
     */
    function dispatch(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata messageBody
    )
        external
        payable
        returns (bytes32 messageId);

    /**
     * @notice Process an incoming message from another chain
     * @param metadata Message metadata including origin info
     * @param message The message body
     */
    function process(bytes calldata metadata, bytes calldata message) external;

    /**
     * @notice Get the local domain ID
     * @return The local domain identifier
     */
    function localDomain() external view returns (uint32);

    /**
     * @notice Check if a message has been delivered
     * @param messageId The message identifier
     * @return Whether the message has been delivered
     */
    function delivered(bytes32 messageId) external view returns (bool);

    /**
     * @notice Get the default ISM (Interchain Security Module)
     * @return The address of the default ISM
     */
    function defaultIsm() external view returns (address);

    /**
     * @notice Get the recipient ISM for a given recipient
     * @param recipient The recipient address
     * @return The ISM address for the recipient
     */
    function recipientIsm(address recipient) external view returns (address);

    /**
     * @notice Quote the gas payment required for a dispatch
     * @param destinationDomain The destination domain
     * @param messageBody The message body
     * @return The required gas payment in wei
     */
    function quoteDispatch(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata messageBody
    )
        external
        view
        returns (uint256);

    event Dispatch(address indexed sender, uint32 indexed destination, bytes32 indexed recipient, bytes message);

    event ProcessId(bytes32 indexed messageId);

    event Process(uint32 indexed origin, bytes32 indexed sender, address indexed recipient);
}
