// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IMailbox} from "../../contracts/interfaces/Hyperlane/IMailbox.sol";

contract MockMailbox is IMailbox {
    uint256 private quoteDispatchAmount;
    bytes32 private nextMessageId;
    uint32 public localDomain = 8453; // Base

    function setQuoteDispatch(uint256 amount) external {
        quoteDispatchAmount = amount;
    }

    function setNextMessageId(bytes32 messageId) external {
        nextMessageId = messageId;
    }

    function dispatch(
        uint32,
        bytes32,
        bytes calldata
    ) external payable override returns (bytes32) {
        require(msg.value >= quoteDispatchAmount, "Insufficient payment");
        return nextMessageId != bytes32(0) ? nextMessageId : keccak256(abi.encode(block.timestamp));
    }

    function quoteDispatch(
        uint32,
        bytes32,
        bytes calldata
    ) external view override returns (uint256) {
        return quoteDispatchAmount;
    }

    function process(
        bytes calldata,
        bytes calldata
    ) external pure override {
        // Mock implementation
    }

    function recipientIsm(address) external pure override returns (address) {
        return address(0);
    }

    function defaultIsm() external pure override returns (address) {
        return address(0);
    }

    function delivered(bytes32) external pure override returns (bool) {
        return false;
    }

    function owner() external pure returns (address) {
        return address(0);
    }

    function pendingOwner() external pure returns (address) {
        return address(0);
    }

    function transferOwnership(address) external pure {
        // Mock implementation
    }

    function renounceOwnership() external pure {
        // Mock implementation
    }
}