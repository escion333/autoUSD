// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";

/**
 * @title SetupDomainMapping Script
 * @notice Automates domain mapping and cross-chain infrastructure setup
 * @dev Configures Hyperlane domains, CCTP domains, and network relationships
 */
contract SetupDomainMapping is Script {
    struct DomainConfig {
        uint32 domainId;
        uint256 chainId;
        string name;
        address hyperlaneMailbox;
        address cctpTokenMessenger;
        address cctpMessageTransmitter;
        address interchainGasPaymaster;
        address usdc;
        bool isTestnet;
    }

    struct NetworkMapping {
        DomainConfig base;
        DomainConfig katana;
        DomainConfig zircuit;
    }

    function run() external {
        console.log("Setting up domain mapping and cross-chain infrastructure...");
        
        NetworkMapping memory networks = loadNetworkMapping();
        validateNetworkMapping(networks);
        
        // Deploy/update configuration based on current chain
        uint256 currentChain = block.chainid;
        if (currentChain == networks.base.chainId) {
            setupBaseConfiguration(networks);
        } else if (currentChain == networks.katana.chainId) {
            setupKatanaConfiguration(networks);
        } else if (currentChain == networks.zircuit.chainId) {
            setupZircuitConfiguration(networks);
        } else {
            revert("Unsupported chain for domain mapping setup");
        }
        
        console.log("SUCCESS: Domain mapping setup completed!");
    }

    function loadNetworkMapping() internal view returns (NetworkMapping memory networks) {
        // Load Base configuration
        networks.base = DomainConfig({
            domainId: uint32(vm.envUint("BASE_DOMAIN")),
            chainId: getBaseChainId(),
            name: "Base",
            hyperlaneMailbox: vm.envAddress("HYPERLANE_MAILBOX_BASE"),
            cctpTokenMessenger: vm.envAddress("CCTP_TOKEN_MESSENGER"),
            cctpMessageTransmitter: vm.envAddress("CCTP_MESSAGE_TRANSMITTER"),
            interchainGasPaymaster: vm.envAddress("INTERCHAIN_GAS_PAYMASTER"),
            usdc: vm.envAddress("USDC_ADDRESS"),
            isTestnet: isTestnetEnvironment()
        });

        // Load Katana configuration
        networks.katana = DomainConfig({
            domainId: uint32(vm.envUint("KATANA_DOMAIN")),
            chainId: getKatanaChainId(),
            name: "Katana",
            hyperlaneMailbox: vm.envAddress("HYPERLANE_MAILBOX_KATANA"),
            cctpTokenMessenger: loadAddressOrZero("KATANA_CCTP_TOKEN_MESSENGER"),
            cctpMessageTransmitter: loadAddressOrZero("KATANA_CCTP_MESSAGE_TRANSMITTER"),
            interchainGasPaymaster: loadAddressOrZero("KATANA_INTERCHAIN_GAS_PAYMASTER"),
            usdc: loadAddressOrZero("KATANA_USDC"),
            isTestnet: isTestnetEnvironment()
        });

        // Load Zircuit configuration
        networks.zircuit = DomainConfig({
            domainId: uint32(vm.envUint("ZIRCUIT_DOMAIN")),
            chainId: getZircuitChainId(),
            name: "Zircuit",
            hyperlaneMailbox: vm.envAddress("HYPERLANE_MAILBOX_ZIRCUIT"),
            cctpTokenMessenger: loadAddressOrZero("ZIRCUIT_CCTP_TOKEN_MESSENGER"),
            cctpMessageTransmitter: loadAddressOrZero("ZIRCUIT_CCTP_MESSAGE_TRANSMITTER"),
            interchainGasPaymaster: loadAddressOrZero("ZIRCUIT_INTERCHAIN_GAS_PAYMASTER"),
            usdc: loadAddressOrZero("ZIRCUIT_USDC"),
            isTestnet: isTestnetEnvironment()
        });

        console.log("Network mapping loaded:");
        logDomainConfig(networks.base);
        logDomainConfig(networks.katana);
        logDomainConfig(networks.zircuit);
    }

    function loadAddressOrZero(string memory envVar) internal view returns (address) {
        try vm.envAddress(envVar) returns (address addr) {
            return addr;
        } catch {
            return address(0);
        }
    }

    function getBaseChainId() internal pure returns (uint256) {
        // Return appropriate Base chain ID based on environment
        // This could be determined by other environment variables
        return 8453; // Base mainnet - update based on actual deployment
    }

    function getKatanaChainId() internal pure returns (uint256) {
        // Return appropriate Katana chain ID
        return 1001; // Example - update with actual Katana chain ID
    }

    function getZircuitChainId() internal pure returns (uint256) {
        // Return appropriate Zircuit chain ID  
        return 48900; // Example - update with actual Zircuit chain ID
    }

    function isTestnetEnvironment() internal view returns (bool) {
        // Determine if this is a testnet deployment
        try vm.envString("NETWORK_TYPE") returns (string memory networkType) {
            return keccak256(bytes(networkType)) == keccak256(bytes("testnet"));
        } catch {
            // Default to mainnet if not specified
            return false;
        }
    }

    function validateNetworkMapping(NetworkMapping memory networks) internal pure {
        // Validate domain uniqueness
        require(networks.base.domainId != networks.katana.domainId, "Base and Katana domain IDs must be different");
        require(networks.base.domainId != networks.zircuit.domainId, "Base and Zircuit domain IDs must be different");
        require(networks.katana.domainId != networks.zircuit.domainId, "Katana and Zircuit domain IDs must be different");

        // Validate chain uniqueness
        require(networks.base.chainId != networks.katana.chainId, "Base and Katana chain IDs must be different");
        require(networks.base.chainId != networks.zircuit.chainId, "Base and Zircuit chain IDs must be different");
        require(networks.katana.chainId != networks.zircuit.chainId, "Katana and Zircuit chain IDs must be different");

        // Validate required addresses for Base (primary chain)
        require(networks.base.hyperlaneMailbox != address(0), "Base Hyperlane mailbox required");
        require(networks.base.cctpTokenMessenger != address(0), "Base CCTP token messenger required");
        require(networks.base.usdc != address(0), "Base USDC address required");

        console.log("SUCCESS: Network mapping validation passed");
    }

    function setupBaseConfiguration(NetworkMapping memory networks) internal {
        console.log("\n--- Setting up Base Chain Configuration ---");
        
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
        vm.startBroadcast(deployer);

        // Create domain mapping configuration file
        string memory domainMappingConfig = generateDomainMappingConfig(networks);
        string memory filename = networks.base.isTestnet ? 
            "deployments/domain_mapping_testnet.json" : 
            "deployments/domain_mapping_mainnet.json";
        
        vm.writeFile(filename, domainMappingConfig);
        console.log("Domain mapping configuration saved to:", filename);

        // Create Hyperlane configuration
        string memory hyperlaneConfig = generateHyperlaneConfig(networks);
        string memory hyperlaneFilename = networks.base.isTestnet ?
            "deployments/hyperlane_testnet.json" :
            "deployments/hyperlane_mainnet.json";
        
        vm.writeFile(hyperlaneFilename, hyperlaneConfig);
        console.log("Hyperlane configuration saved to:", hyperlaneFilename);

        // Create CCTP configuration
        string memory cctpConfig = generateCCTPConfig(networks);
        string memory cctpFilename = networks.base.isTestnet ?
            "deployments/cctp_testnet.json" :
            "deployments/cctp_mainnet.json";
        
        vm.writeFile(cctpFilename, cctpConfig);
        console.log("CCTP configuration saved to:", cctpFilename);

        vm.stopBroadcast();

        console.log("SUCCESS: Base chain configuration completed");
    }

    function setupKatanaConfiguration(NetworkMapping memory networks) internal {
        console.log("\n--- Setting up Katana Chain Configuration ---");
        
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
        vm.startBroadcast(deployer);

        // Validate we're on the correct chain
        require(block.chainid == networks.katana.chainId, "Not on Katana chain");

        // Create chain-specific configuration
        string memory katanaConfig = generateChainSpecificConfig(networks.katana, networks.base);
        vm.writeFile("deployments/katana_config.json", katanaConfig);
        console.log("Katana configuration saved");

        vm.stopBroadcast();

        console.log("SUCCESS: Katana chain configuration completed");
    }

    function setupZircuitConfiguration(NetworkMapping memory networks) internal {
        console.log("\n--- Setting up Zircuit Chain Configuration ---");
        
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
        vm.startBroadcast(deployer);

        // Validate we're on the correct chain
        require(block.chainid == networks.zircuit.chainId, "Not on Zircuit chain");

        // Create chain-specific configuration
        string memory zircuitConfig = generateChainSpecificConfig(networks.zircuit, networks.base);
        vm.writeFile("deployments/zircuit_config.json", zircuitConfig);
        console.log("Zircuit configuration saved");

        vm.stopBroadcast();

        console.log("SUCCESS: Zircuit chain configuration completed");
    }

    function generateDomainMappingConfig(NetworkMapping memory networks) 
        internal 
        pure 
        returns (string memory) 
    {
        return string.concat(
            "{\n",
            '  "domainMapping": {\n',
            '    "base": {\n',
            '      "domainId": ', vm.toString(networks.base.domainId), ',\n',
            '      "chainId": ', vm.toString(networks.base.chainId), ',\n',
            '      "name": "', networks.base.name, '",\n',
            '      "type": "primary"\n',
            '    },\n',
            '    "katana": {\n',
            '      "domainId": ', vm.toString(networks.katana.domainId), ',\n',
            '      "chainId": ', vm.toString(networks.katana.chainId), ',\n',
            '      "name": "', networks.katana.name, '",\n',
            '      "type": "child"\n',
            '    },\n',
            '    "zircuit": {\n',
            '      "domainId": ', vm.toString(networks.zircuit.domainId), ',\n',
            '      "chainId": ', vm.toString(networks.zircuit.chainId), ',\n',
            '      "name": "', networks.zircuit.name, '",\n',
            '      "type": "child"\n',
            '    }\n',
            '  }\n',
            '}'
        );
    }

    function generateHyperlaneConfig(NetworkMapping memory networks) 
        internal 
        pure 
        returns (string memory) 
    {
        return string.concat(
            "{\n",
            '  "hyperlane": {\n',
            '    "chains": {\n',
            '      "', vm.toString(networks.base.domainId), '": {\n',
            '        "mailbox": "', vm.toString(networks.base.hyperlaneMailbox), '",\n',
            '        "interchainGasPaymaster": "', vm.toString(networks.base.interchainGasPaymaster), '",\n',
            '        "chainId": ', vm.toString(networks.base.chainId), '\n',
            '      },\n',
            '      "', vm.toString(networks.katana.domainId), '": {\n',
            '        "mailbox": "', vm.toString(networks.katana.hyperlaneMailbox), '",\n',
            '        "chainId": ', vm.toString(networks.katana.chainId), '\n',
            '      },\n',
            '      "', vm.toString(networks.zircuit.domainId), '": {\n',
            '        "mailbox": "', vm.toString(networks.zircuit.hyperlaneMailbox), '",\n',
            '        "chainId": ', vm.toString(networks.zircuit.chainId), '\n',
            '      }\n',
            '    }\n',
            '  }\n',
            '}'
        );
    }

    function generateCCTPConfig(NetworkMapping memory networks) 
        internal 
        pure 
        returns (string memory) 
    {
        return string.concat(
            "{\n",
            '  "cctp": {\n',
            '    "base": {\n',
            '      "domainId": ', vm.toString(networks.base.domainId), ',\n',
            '      "tokenMessenger": "', vm.toString(networks.base.cctpTokenMessenger), '",\n',
            '      "messageTransmitter": "', vm.toString(networks.base.cctpMessageTransmitter), '",\n',
            '      "usdc": "', vm.toString(networks.base.usdc), '"\n',
            '    }\n',
            '  }\n',
            '}'
        );
    }

    function generateChainSpecificConfig(
        DomainConfig memory currentChain, 
        DomainConfig memory baseChain
    ) internal pure returns (string memory) {
        return string.concat(
            "{\n",
            '  "chain": {\n',
            '    "domainId": ', vm.toString(currentChain.domainId), ',\n',
            '    "chainId": ', vm.toString(currentChain.chainId), ',\n',
            '    "name": "', currentChain.name, '",\n',
            '    "hyperlaneMailbox": "', vm.toString(currentChain.hyperlaneMailbox), '"\n',
            '  },\n',
            '  "baseDomain": {\n',
            '    "domainId": ', vm.toString(baseChain.domainId), ',\n',
            '    "chainId": ', vm.toString(baseChain.chainId), '\n',
            '  }\n',
            '}'
        );
    }

    function logDomainConfig(DomainConfig memory config) internal view {
        console.log(string.concat("  ", config.name, ":"));
        console.log("    Domain ID:", config.domainId);
        console.log("    Chain ID:", config.chainId);
        console.log("    Hyperlane Mailbox:", config.hyperlaneMailbox);
        if (config.usdc != address(0)) {
            console.log("    USDC:", config.usdc);
        }
        console.log("    Testnet:", config.isTestnet);
    }
}