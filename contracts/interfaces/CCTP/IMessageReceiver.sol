// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IMessageReceiver
 * @notice Interface for a contract that can receive messages from a CCTP TokenMessenger
 * @dev A contract implementing this interface can be set as the `destinationCaller` in a CCTP transfer
 */
interface IMessageReceiver {
    /**
     * @notice Handles a message received from a remote TokenMessenger
     * @param remoteDomain The CCTP domain of the source chain
     * @param remoteTokenMessenger The address of the TokenMessenger on the source chain
     * @param message The message body, containing details of the transfer
     */
    function handleReceiveMessage(
        uint32 remoteDomain,
        bytes32 remoteTokenMessenger,
        bytes calldata message
    ) external;
}
