// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "../../contracts/MotherVault.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract IntegrationTest is Script {
    address constant USDC_ADDRESS = 0x291ffdb46E1ee4F7800E549D14203ADDa5172fa7; // From previous deployment
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        IERC20 usdc = IERC20(USDC_ADDRESS);
        
        // Deploy a simple MotherVault for testing
        MotherVault vault = new MotherVault(
            USDC_ADDRESS,
            "Test autoUSD",
            "tAUSD"
        );
        
        vault.initialize(USDC_ADDRESS, deployer);
        
        // Set deposit cap
        vault.setDepositCap(1000 * 1e6); // $1000 cap
        
        console.log("=== Integration Test ===");
        console.log("Vault deployed at:", address(vault));
        console.log("USDC balance:", usdc.balanceOf(deployer) / 1e6, "USDC");
        
        // Test deposit
        uint256 depositAmount = 100 * 1e6; // $100
        usdc.approve(address(vault), depositAmount);
        
        console.log("\nDepositing", depositAmount / 1e6, "USDC...");
        uint256 shares = vault.deposit(depositAmount, deployer);
        
        console.log("Received shares:", shares);
        console.log("Vault balance:", vault.balanceOf(deployer));
        console.log("Total assets:", vault.totalAssets() / 1e6, "USDC");
        
        // Test withdrawal
        console.log("\nTesting withdrawal...");
        uint256 maxWithdraw = vault.maxWithdraw(deployer);
        console.log("Max withdrawable:", maxWithdraw / 1e6, "USDC");
        
        if (maxWithdraw > 0) {
            uint256 withdrawAmount = maxWithdraw / 2; // Withdraw half
            console.log("Withdrawing", withdrawAmount / 1e6, "USDC...");
            
            uint256 withdrawn = vault.withdraw(withdrawAmount, deployer, deployer);
            console.log("Withdrawn:", withdrawn / 1e6, "USDC");
            console.log("Remaining shares:", vault.balanceOf(deployer));
            console.log("Final USDC balance:", usdc.balanceOf(deployer) / 1e6, "USDC");
        }
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("=== Integration test complete! ===");
    }
}