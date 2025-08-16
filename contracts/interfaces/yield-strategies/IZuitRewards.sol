// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IZuitRewards {
    function pendingRewards(address user, address pair) external view returns (uint256);
    function claimRewards(address pair) external;
}
