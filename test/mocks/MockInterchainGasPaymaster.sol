// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IInterchainGasPaymaster } from "../../contracts/interfaces/Hyperlane/IInterchainGasPaymaster.sol";

contract MockInterchainGasPaymaster is IInterchainGasPaymaster {
    function payForGas(bytes32, uint32, uint256, address) external payable override {
        // Mock implementation - just accept payment
    }

    function quoteGasPayment(uint32, uint256) external pure override returns (uint256) {
        // Return a fixed amount for testing
        return 1000;
    }

    function owner() external pure returns (address) {
        return address(0);
    }

    function setBeneficiary(address) external pure {
        // Mock implementation
    }

    function beneficiary() external pure returns (address) {
        return address(0);
    }

    function setGasOracles(uint32[] calldata, address[] calldata) external pure {
        // Mock implementation
    }

    function getExchangeRateAndGasPrice(uint32) external pure returns (uint128, uint128) {
        return (1e10, 1e9); // Mock exchange rate and gas price
    }
}
