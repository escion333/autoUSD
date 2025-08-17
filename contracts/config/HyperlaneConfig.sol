// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title HyperlaneConfig
 * @notice Configuration for Hyperlane V3 infrastructure across supported chains
 * @dev Contains addresses and domain IDs for testnet deployments
 */
library HyperlaneConfig {
    // ============================================================================
    // Domain IDs (Hyperlane uses chain IDs as domain IDs for most chains)
    // ============================================================================
    
    // Base Sepolia
    uint32 public constant BASE_SEPOLIA_DOMAIN = 84532;
    
    // Ethereum Sepolia  
    uint32 public constant ETHEREUM_SEPOLIA_DOMAIN = 11155111;
    
    // Katana Tatara (custom domain - Hyperlane not yet deployed)
    uint32 public constant KATANA_TATARA_DOMAIN = 129399;
    
    // ============================================================================
    // Base Sepolia Addresses (Chain ID: 84532)
    // ============================================================================
    
    // Core contracts
    address public constant BASE_SEPOLIA_MAILBOX = 0x6966b0E55883d49BFB24539356a2f8A673E02039;
    address public constant BASE_SEPOLIA_IGP = 0x28B02B97a850872C4D33C3E024fab6499ad96564;
    address public constant BASE_SEPOLIA_ISM = 0xC7Ee6061c213555033f414Ff1841c63e9fB0aFED;
    
    // Additional infrastructure
    address public constant BASE_SEPOLIA_AGGREGATION_HOOK = 0xccA408a6A9A6dc405C3278647421eb4317466943;
    address public constant BASE_SEPOLIA_DOMAIN_ROUTING_ISM = 0x4ac19e0bafc2aF6B98094F0a1B817dF196551219;
    address public constant BASE_SEPOLIA_VALIDATOR_ANNOUNCE = 0x20c44b1E3BeaDA1e9826CFd48BeEDABeE9871cE9;
    
    // ============================================================================
    // Ethereum Sepolia Addresses (Chain ID: 11155111)
    // ============================================================================
    
    // Core contracts
    address public constant ETHEREUM_SEPOLIA_MAILBOX = 0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766;
    address public constant ETHEREUM_SEPOLIA_IGP = 0x6f2756380FD49228ae25Aa7F2817993cB74Ecc56;
    address public constant ETHEREUM_SEPOLIA_ISM = 0x4998C54633C45AC907F3465d8579ACB80E27AF1A;
    
    // Additional infrastructure
    address public constant ETHEREUM_SEPOLIA_DOMAIN_ROUTING_ISM = 0xfa9a26cCc5417d1C1D03C949b5013Bb5898dA905;
    address public constant ETHEREUM_SEPOLIA_VALIDATOR_ANNOUNCE = 0xE6105C59480a1B7DD3E4f28153aFdbE12F4CfCD9;
    
    // ============================================================================
    // Katana Tatara Addresses (Chain ID: 129399)
    // ============================================================================
    // NOTE: Hyperlane is not yet deployed on Katana Tatara
    // These are placeholder addresses that will need to be updated when deployment happens
    // For now, we'll use mock contracts or deploy our own simplified messaging
    
    address public constant KATANA_TATARA_MAILBOX = address(0); // To be deployed
    address public constant KATANA_TATARA_IGP = address(0); // To be deployed
    address public constant KATANA_TATARA_ISM = address(0); // To be deployed
    
    // ============================================================================
    // Helper Functions
    // ============================================================================
    
    /**
     * @notice Get mailbox address for a given domain
     * @param domain The Hyperlane domain ID
     * @return The mailbox address for the domain
     */
    function getMailbox(uint32 domain) internal pure returns (address) {
        if (domain == BASE_SEPOLIA_DOMAIN) {
            return BASE_SEPOLIA_MAILBOX;
        } else if (domain == ETHEREUM_SEPOLIA_DOMAIN) {
            return ETHEREUM_SEPOLIA_MAILBOX;
        } else if (domain == KATANA_TATARA_DOMAIN) {
            // Katana doesn't have Hyperlane yet, revert with clear message
            revert("HyperlaneConfig: Katana Tatara Hyperlane not deployed");
        } else {
            revert("HyperlaneConfig: Unknown domain");
        }
    }
    
    /**
     * @notice Get IGP address for a given domain
     * @param domain The Hyperlane domain ID
     * @return The IGP address for the domain
     */
    function getIGP(uint32 domain) internal pure returns (address) {
        if (domain == BASE_SEPOLIA_DOMAIN) {
            return BASE_SEPOLIA_IGP;
        } else if (domain == ETHEREUM_SEPOLIA_DOMAIN) {
            return ETHEREUM_SEPOLIA_IGP;
        } else if (domain == KATANA_TATARA_DOMAIN) {
            // Katana doesn't have Hyperlane yet, revert with clear message
            revert("HyperlaneConfig: Katana Tatara Hyperlane not deployed");
        } else {
            revert("HyperlaneConfig: Unknown domain");
        }
    }
    
    /**
     * @notice Check if a domain is supported
     * @param domain The Hyperlane domain ID
     * @return Whether the domain is supported
     */
    function isDomainSupported(uint32 domain) internal pure returns (bool) {
        return domain == BASE_SEPOLIA_DOMAIN || 
               domain == ETHEREUM_SEPOLIA_DOMAIN || 
               domain == KATANA_TATARA_DOMAIN;
    }
    
    /**
     * @notice Get the chain name for a domain
     * @param domain The Hyperlane domain ID
     * @return The chain name
     */
    function getChainName(uint32 domain) internal pure returns (string memory) {
        if (domain == BASE_SEPOLIA_DOMAIN) {
            return "Base Sepolia";
        } else if (domain == ETHEREUM_SEPOLIA_DOMAIN) {
            return "Ethereum Sepolia";
        } else if (domain == KATANA_TATARA_DOMAIN) {
            return "Katana Tatara";
        } else {
            revert("HyperlaneConfig: Unknown domain");
        }
    }
}