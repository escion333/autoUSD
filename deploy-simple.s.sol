// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "./contracts/MotherVault.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeploySimple is Script {
    address constant USDC_BASE_SEPOLIA = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy MotherVault
        MotherVault motherVault = new MotherVault(
            USDC_BASE_SEPOLIA,
            "autoUSD Vault", 
            "aUSD"
        );
        
        console.log("MotherVault deployed:", address(motherVault));
        
        vm.stopBroadcast();
    }
}