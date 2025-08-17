// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";

contract SimpleTest is Test {
    function test_AnvilConnection() public {
        // Simple test to verify Anvil is working
        uint256 chainId = block.chainid;
        assertEq(chainId, 31_337, "Should be on Anvil chain");

        console.log("Chain ID:", chainId);
        console.log("Block number:", block.number);
        console.log("Timestamp:", block.timestamp);
    }

    function test_BasicMath() public {
        uint256 a = 100;
        uint256 b = 200;
        uint256 sum = a + b;

        assertEq(sum, 300, "Math should work");
        console.log("100 + 200 =", sum);
    }
}
