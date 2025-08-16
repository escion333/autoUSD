// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {ICrossChainMessenger} from "../../contracts/interfaces/ICrossChainMessenger.sol";

contract MockCrossChainMessenger is ICrossChainMessenger {
    function sendCrossChainMessage(
        CrossChainMessage calldata message
    ) external payable override returns (bytes32 messageId) {
        emit MessageSent(message.targetChainId, message.messageType, bytes32(0), message.nonce);
        return bytes32(0);
    }

    function handle(
        uint32,
        bytes32,
        bytes calldata
    ) external payable override {}

    function getMessageStatus(bytes32) external pure override returns (bool processed, bool success) {
        return (false, false);
    }

    function estimateMessageFee(uint32) external pure returns (uint256) {
        return 0;
    }

    function getHyperlaneMailbox() external pure override returns (address) {
        return address(0);
    }

    function getCCTPTokenMessenger() external pure override returns (address) {
        return address(0);
    }

    function getInterchainGasPaymaster() external pure override returns (address) {
        return address(0);
    }
}
