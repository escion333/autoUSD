// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title IMessageRecipient
 * @notice Interface that must be implemented by contracts receiving Hyperlane messages
 * @dev Contracts receiving messages from Hyperlane must implement this interface
 */
interface IMessageRecipient {
    /**
     * @notice Handle an incoming message from another chain
     * @param _origin The domain ID of the origin chain
     * @param _sender The sender address on the origin chain (bytes32 format)
     * @param _message The message body
     */
    function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable;
}
