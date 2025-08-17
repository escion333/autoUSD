// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { ITokenMessenger } from "../../contracts/interfaces/CCTP/ITokenMessenger.sol";

contract MockTokenMessenger is ITokenMessenger {
    uint64 private _nextNonce = 1;
    address private _burnToken;
    uint32 private _localDomain = 6;
    address private _messageTransmitter;

    mapping(address => uint256) public override burnLimitsPerMessage;

    constructor(address burnToken) {
        _burnToken = burnToken;
        burnLimitsPerMessage[burnToken] = 1_000_000e6;
        _messageTransmitter = address(this);
    }

    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken
    )
        external
        override
        returns (uint64 nonce)
    {
        require(burnToken == _burnToken, "Invalid burn token");
        require(amount <= burnLimitsPerMessage[burnToken], "Exceeds burn limit");

        nonce = _nextNonce++;

        return nonce;
    }

    function replaceDepositForBurn(
        bytes calldata originalMessage,
        bytes calldata originalAttestation,
        bytes32 newDestinationCaller,
        bytes32 newMintRecipient
    )
        external
        override
    { }

    function localMessageTransmitter() external view override returns (address) {
        return _messageTransmitter;
    }

    function localDomain() external view override returns (uint32) {
        return _localDomain;
    }

    function setLocalDomain(uint32 domain) external {
        _localDomain = domain;
    }
}
