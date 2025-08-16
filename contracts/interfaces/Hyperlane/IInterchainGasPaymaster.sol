// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title IInterchainGasPaymaster
 * @notice Interface for Hyperlane's Interchain Gas Paymaster
 * @dev Handles gas payments for cross-chain messages
 */
interface IInterchainGasPaymaster {
    /**
     * @notice Pay for gas for a dispatched message
     * @param messageId The ID of the dispatched message
     * @param destinationDomain The domain of the destination chain
     * @param gasAmount The amount of destination gas to pay for
     * @param refundAddress The address to refund excess payment to
     */
    function payForGas(
        bytes32 messageId,
        uint32 destinationDomain,
        uint256 gasAmount,
        address refundAddress
    ) external payable;

    /**
     * @notice Quote the gas payment required
     * @param destinationDomain The domain of the destination chain
     * @param gasAmount The amount of destination gas
     * @return The payment required in wei
     */
    function quoteGasPayment(
        uint32 destinationDomain,
        uint256 gasAmount
    ) external view returns (uint256);

    event GasPayment(
        bytes32 indexed messageId,
        uint32 indexed destinationDomain,
        uint256 gasAmount,
        uint256 payment
    );
}