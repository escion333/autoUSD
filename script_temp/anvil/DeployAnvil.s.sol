// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "../../contracts/MotherVault.sol";
import "../../contracts/core/CCTPBridge.sol";
import "../../contracts/core/CrossChainMessenger.sol";
import "../../contracts/core/Rebalancer.sol";
import "../../contracts/core/YieldDistributor.sol";
import "../../contracts/core/HealthMonitor.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Simple mock contracts for Anvil testing
contract MockUSDC is ERC20 {
    address public owner;
    
    constructor() ERC20("Mock USDC", "USDC") {
        owner = msg.sender;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "MockUSDC: Only owner can mint");
        _;
    }
    
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract MockMailbox {
    event MessageDispatched(uint32 domain, bytes32 recipient, bytes message);
    
    function dispatch(uint32 domain, bytes32 recipient, bytes memory message) 
        external 
        payable 
        returns (bytes32) 
    {
        emit MessageDispatched(domain, recipient, message);
        return keccak256(abi.encode(block.timestamp, domain, recipient));
    }
    
    function quoteDispatch(uint32, bytes32, bytes memory) 
        external 
        pure 
        returns (uint256) 
    {
        return 0.001 ether;
    }
}

contract MockTokenMessenger {
    event BurnInitiated(uint32 domain, uint256 amount);
    
    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken
    ) external returns (uint64 nonce) {
        emit BurnInitiated(destinationDomain, amount);
        return uint64(block.timestamp);
    }
}

contract MockMessageTransmitter {
    function receiveMessage(bytes memory, bytes calldata) external pure returns (bool) {
        return true;
    }
}

contract MockGasPaymaster {
    function payGas(bytes32, uint256, uint256, address) external payable {}
}

contract DeployAnvil is Script {
    // Domain IDs
    uint32 constant BASE_DOMAIN = 6; // CCTP v2 domain for Base
    uint32 constant KATANA_DOMAIN = 100; // Custom domain for Katana (not CCTP)
    uint32 constant ZIRCUIT_DOMAIN = 101; // Custom domain for Zircuit (not CCTP)
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address treasury = deployer; // Use deployer as treasury for testing
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy mock infrastructure
        MockUSDC usdc = new MockUSDC();
        MockMailbox mailbox = new MockMailbox();
        MockTokenMessenger tokenMessenger = new MockTokenMessenger();
        MockMessageTransmitter messageTransmitter = new MockMessageTransmitter();
        MockGasPaymaster gasPaymaster = new MockGasPaymaster();
        
        // Mint test USDC to deployer first
        usdc.mint(deployer, 10000 * 1e6); // 10k USDC
        console.log("Minted 10,000 USDC to deployer");
        
        // Deploy MotherVault
        MotherVault motherVault = new MotherVault(
            address(usdc),
            "autoUSD Vault",
            "aUSD"
        );
        
        // Approve vault for initialization (needs 100 USDC for initial deposit)
        usdc.approve(address(motherVault), 100 * 1e6);
        console.log("Approved MotherVault for initialization");
        
        motherVault.initialize(
            address(usdc),
            deployer
        );
        
        // Deploy CCTPBridge
        CCTPBridge cctpBridge = new CCTPBridge(
            address(tokenMessenger),
            address(messageTransmitter),
            address(usdc),
            deployer // admin
        );
        
        // Deploy CrossChainMessenger
        CrossChainMessenger messenger = new CrossChainMessenger(
            address(mailbox),
            address(gasPaymaster),
            address(cctpBridge),
            address(motherVault),
            deployer // admin
        );
        
        // Deploy Rebalancer
        Rebalancer rebalancer = new Rebalancer(
            address(motherVault)
        );
        
        // Deploy YieldDistributor
        YieldDistributor yieldDist = new YieldDistributor(
            address(usdc),
            address(motherVault),
            treasury,
            50 // 0.5% management fee
        );
        
        // Deploy HealthMonitor
        HealthMonitor healthMon = new HealthMonitor(
            address(motherVault),
            address(messenger),
            address(rebalancer),
            deployer // admin
        );
        
        // Configure MotherVault with error handling
        try motherVault.setDepositCap(100 * 1e6) {
            console.log("Deposit cap set to $100");
        } catch Error(string memory reason) {
            console.log("Failed to set deposit cap:", reason);
        }
        
        try motherVault.setManagementFee(50) {
            console.log("Management fee set to 0.5%");
        } catch Error(string memory reason) {
            console.log("Failed to set management fee:", reason);
        }
        
        try motherVault.setRebalanceCooldown(3600) {
            console.log("Rebalance cooldown set to 1 hour");
        } catch Error(string memory reason) {
            console.log("Failed to set rebalance cooldown:", reason);
        }
        
        try motherVault.setMinAPYDifferential(500) {
            console.log("Min APY differential set to 5%");
        } catch Error(string memory reason) {
            console.log("Failed to set APY differential:", reason);
        }
        
        try motherVault.setBufferManagement(true) {
            console.log("Buffer management enabled");
        } catch Error(string memory reason) {
            console.log("Failed to enable buffer management:", reason);
        }
        
        // Add supported domains to CCTP
        try cctpBridge.setSupportedDomain(KATANA_DOMAIN, true) {
            console.log("CCTP: Katana domain supported");
        } catch Error(string memory reason) {
            console.log("Failed to add Katana domain:", reason);
        }
        
        try cctpBridge.setSupportedDomain(ZIRCUIT_DOMAIN, true) {
            console.log("CCTP: Zircuit domain supported");
        } catch Error(string memory reason) {
            console.log("Failed to add Zircuit domain:", reason);
        }
        
        // Approve vault for additional testing with specific amount
        uint256 approvalAmount = 1000 * 1e6; // $1000 approval
        usdc.approve(address(motherVault), approvalAmount);
        console.log("Approved MotherVault for additional $1000 USDC");
        
        vm.stopBroadcast();
        
        // Log deployment info
        console.log("\n===== BASE CHAIN DEPLOYMENT =====");
        console.log("Chain ID:", block.chainid);
        console.log("Deployer:", deployer);
        console.log("\n--- Core Contracts ---");
        console.log("MotherVault:", address(motherVault));
        console.log("CCTPBridge:", address(cctpBridge));
        console.log("CrossChainMessenger:", address(messenger));
        console.log("Rebalancer:", address(rebalancer));
        console.log("YieldDistributor:", address(yieldDist));
        console.log("HealthMonitor:", address(healthMon));
        console.log("\n--- Mock Infrastructure ---");
        console.log("USDC:", address(usdc));
        console.log("Hyperlane Mailbox:", address(mailbox));
        console.log("CCTP TokenMessenger:", address(tokenMessenger));
        console.log("\n--- Configuration ---");
        console.log("Deposit Limit: $100");
        console.log("Management Fee: 0.5%");
        console.log("Rebalance Threshold: 5% APY");
        console.log("Test USDC Balance:", usdc.balanceOf(deployer) / 1e6, "USDC");
        
        // Log key addresses for manual saving
        console.log("\n===== SAVE THESE ADDRESSES =====");
        console.log("export MOTHER_VAULT=", address(motherVault));
        console.log("export CCTP_BRIDGE=", address(cctpBridge));
        console.log("export MESSENGER=", address(messenger));
        console.log("export REBALANCER=", address(rebalancer));
        console.log("export YIELD_DIST=", address(yieldDist));
        console.log("export HEALTH_MON=", address(healthMon));
        console.log("export USDC=", address(usdc));
        console.log("export MAILBOX=", address(mailbox));
        console.log("export TOKEN_MESSENGER=", address(tokenMessenger));
    }
}