// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

contract MockMotherVault {
    event DepositFromChild(address vault, bytes payload);
    event WithdrawalToChild(address vault, bytes payload);
    event YieldReport(address vault, bytes payload);
    event RebalanceCommand(address vault, bytes payload);
    event EmergencyPause(address vault);
    event EmergencyUnpause(address vault);
    event EmergencyWithdrawAll(address vault, bytes payload);

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
}