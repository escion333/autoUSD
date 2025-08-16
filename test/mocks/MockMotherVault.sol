// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ICrossChainMessenger} from "../../contracts/interfaces/ICrossChainMessenger.sol";

contract MockMotherVault {
    event DepositFromChild(address vault, bytes payload);
    event WithdrawalToChild(address vault, bytes payload);
    event YieldReport(address vault, bytes payload);
    event RebalanceCommand(address vault, bytes payload);
    event EmergencyPause(address vault);
    event EmergencyUnpause(address vault);
    event EmergencyWithdrawAll(address vault, bytes payload);
    event IncomingMessageHandled(uint32 origin, bytes32 sender, bytes message);
    event RebalanceInitiated(uint32 sourceChainId, uint32 targetChainId, uint256 amount);

    bool public rebalanceInitiated;

    function handleIncomingMessage(uint32 origin, bytes32 sender, bytes calldata message) external {
        emit IncomingMessageHandled(origin, sender, message);
        
        (ICrossChainMessenger.MessageType messageType, bytes memory payload) = abi.decode(message, (ICrossChainMessenger.MessageType, bytes));
        
        // Minimal routing logic for mock
        if (messageType == ICrossChainMessenger.MessageType.DEPOSIT_REQUEST) {
            // Do nothing, just succeed
        } else if (messageType == ICrossChainMessenger.MessageType.WITHDRAWAL_REQUEST) {
            // Do nothing, just succeed
        }
    }

    function handleDepositFromChild(address vault, bytes calldata payload) external returns (bytes memory) {
        emit DepositFromChild(vault, payload);
        return abi.encode(true);
    }

    function handleWithdrawalToChild(address vault, bytes calldata payload) external returns (bytes memory) {
        emit WithdrawalToChild(vault, payload);
        return abi.encode(true);
    }

    function handleYieldReport(address vault, bytes calldata payload) external returns (bytes memory) {
        emit YieldReport(vault, payload);
        return abi.encode(true);
    }

    function handleRebalanceCommand(address vault, bytes calldata payload) external returns (bytes memory) {
        emit RebalanceCommand(vault, payload);
        return abi.encode(true);
    }

    function handleEmergencyPause(address vault) external returns (bytes memory) {
        emit EmergencyPause(vault);
        return abi.encode(true);
    }

    function handleEmergencyUnpause(address vault) external returns (bytes memory) {
        emit EmergencyUnpause(vault);
        return abi.encode(true);
    }

    function handleEmergencyWithdrawAll(address vault, bytes calldata payload) external returns (bytes memory) {
        emit EmergencyWithdrawAll(vault, payload);
        return abi.encode(true);
    }

    function initiateRebalance(uint32 sourceChainId, uint32 targetChainId, uint256 amount) external {
        rebalanceInitiated = true;
        emit RebalanceInitiated(sourceChainId, targetChainId, amount);
    }
}
