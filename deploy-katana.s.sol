// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "./contracts/yield-strategies/KatanaChildVault.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployKatana is Script {
    // Mock addresses for Katana deployment (will be configured later)
    address constant USDC_KATANA = address(0x1111111111111111111111111111111111111111);
    address constant SUSHI_ROUTER = address(0x2222222222222222222222222222222222222222);
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy KatanaChildVault
        KatanaChildVault childVault = new KatanaChildVault(
            USDC_KATANA,         // _usdc
            SUSHI_ROUTER,        // _katanaRouter
            address(0),          // _katanaPair (will be created)
            address(0),          // _masterChef (mock for now)
            address(0),          // _sushiToken (mock for now)
            address(0),          // _crossChainMessenger (set later)
            address(0),          // _cctpBridge (set later)
            deployer             // _admin
        );
        
        console.log("KatanaChildVault deployed:", address(childVault));
        
        vm.stopBroadcast();
    }
}