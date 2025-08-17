// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockMasterChef {
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    mapping(uint256 => uint256) public totalStaked;

    function deposit(uint256 _pid, uint256 _amount) external {
        userInfo[_pid][msg.sender].amount += _amount;
        totalStaked[_pid] += _amount;
    }

    function withdraw(uint256 _pid, uint256 _amount) external {
        require(userInfo[_pid][msg.sender].amount >= _amount, "Insufficient balance");
        userInfo[_pid][msg.sender].amount -= _amount;
        totalStaked[_pid] -= _amount;
    }

    function pendingSushi(uint256 _pid, address _user) external view returns (uint256) {
        // Mock pending rewards - return 1% of staked amount
        return userInfo[_pid][_user].amount / 100;
    }

    function harvest(uint256 _pid) external {
        // Mock harvest - no actual token transfer for simplicity
    }
}
