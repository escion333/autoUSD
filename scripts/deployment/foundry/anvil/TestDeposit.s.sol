// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Minimal test contract for Anvil deployment
contract TestUSDC is ERC20 {
    constructor() ERC20("Test USDC", "USDC") {
        _mint(msg.sender, 1000000 * 10**6);
    }
    
    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract TestDeposit is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy test USDC
        TestUSDC usdc = new TestUSDC();
        
        vm.stopBroadcast();
        
        console.log("Test USDC deployed at:", address(usdc));
        console.log("Balance:", usdc.balanceOf(deployer) / 1e6, "USDC");
        
        // Save deployment
        vm.writeFile("deployments/test.txt", vm.toString(address(usdc)));
    }
}