// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMasterChef {
    function pendingSushi(uint256 pid, address user) external view returns (uint256);
    function harvest(uint256 pid, address to) external;
}
