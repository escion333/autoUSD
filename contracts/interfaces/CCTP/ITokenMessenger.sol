// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title ITokenMessenger
 * @notice Interface for Circle's CCTP TokenMessenger contract
 * @dev Used for burning USDC on source chain and initiating cross-chain transfers
 */
interface ITokenMessenger {
    /**
     * @notice Burn USDC on the local chain and send a message to mint on the destination chain
     * @param amount Amount of USDC to burn
     * @param destinationDomain Destination domain ID (e.g., 0 for Ethereum, 6 for Avalanche)
     * @param mintRecipient Address to receive USDC on destination chain (32 bytes, left-padded)
     * @param burnToken Address of the USDC token on the local chain
     * @return nonce Unique nonce for this burn transaction
     */
    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken
    )
        external
        returns (uint64 nonce);

    /**
     * @notice Replace a burn message to change the mint recipient or destination caller
     * @param originalMessage Original message bytes from depositForBurn
     * @param originalAttestation Attestation for the original message
     * @param newDestinationCaller New destination caller address (optional)
     * @param newMintRecipient New mint recipient address (optional)
     */
    function replaceDepositForBurn(
        bytes calldata originalMessage,
        bytes calldata originalAttestation,
        bytes32 newDestinationCaller,
        bytes32 newMintRecipient
    )
        external;

    /**
     * @notice Get the maximum burn amount per message
     * @param burnToken Address of the token to burn
     * @return Maximum burn amount
     */
    function burnLimitsPerMessage(address burnToken) external view returns (uint256);

    /**
     * @notice Get the local Message Transmitter contract address
     * @return Address of the Message Transmitter
     */
    function localMessageTransmitter() external view returns (address);

    /**
     * @notice Get the local domain ID
     * @return Local domain ID
     */
    function localDomain() external view returns (uint32);
}
