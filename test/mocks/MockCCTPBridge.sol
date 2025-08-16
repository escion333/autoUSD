// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {CCTPBridge} from "../../contracts/core/CCTPBridge.sol";
import {MockERC20} from "./MockERC20.sol";
import {MockTokenMessenger} from "./MockTokenMessenger.sol";
import {MockMessageTransmitter} from "./MockMessageTransmitter.sol";

contract MockCCTPBridge is CCTPBridge {

    constructor(
        address _usdc,
        address _tokenMessenger,
        address _messageTransmitter,
        address _crossChainMessenger
    ) CCTPBridge(_usdc, _tokenMessenger, _messageTransmitter, _crossChainMessenger) {}

    function bridgeUSDC(
        uint256 amount,
        uint256 destinationChainId,
        address recipient
    ) public override returns (uint64 nonce) {
        // Mock behavior: just emit the event
        emit BridgeInitiated(0, amount, uint32(destinationChainId), recipient, msg.sender);
        return 0;
    }
}
