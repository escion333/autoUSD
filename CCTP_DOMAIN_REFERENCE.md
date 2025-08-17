# CCTP v2 Domain Reference

## Official CCTP v2 Domain IDs

Circle's Cross-Chain Transfer Protocol (CCTP) v2 uses the following domain IDs:

### Mainnet Domains
- **0**: Ethereum
- **1**: Avalanche
- **2**: OP Mainnet
- **3**: Arbitrum
- **6**: Base
- **7**: Polygon PoS
- **10**: Unichain
- **11**: Linea
- **12**: Codex
- **13**: Sonic
- **14**: World Chain
- **16**: Sei

### Testnet Domains
- **0**: Ethereum Sepolia (same as mainnet)
- **1**: Avalanche Fuji (same as mainnet)
- **2**: OP Sepolia (same as mainnet)
- **3**: Arbitrum Sepolia (same as mainnet)
- **7**: Polygon Amoy (same as Polygon PoS mainnet)
- **10002**: Base Sepolia

## autoUSD Protocol Domain Mappings

### CCTP Domains (Official)
- Base: 6
- Base Sepolia: 10002
- Polygon PoS/Amoy: 7
- Arbitrum: 3

### Custom Domains (Internal Use)
- Katana: 100 (Not part of CCTP, custom domain for Hyperlane messaging)
- Zircuit: 101 (Not part of CCTP, custom domain for Hyperlane messaging)

## Important Notes

1. **CCTP vs Custom Domains**: CCTP domains are used for USDC bridging via Circle's infrastructure. Custom domains (100+) are used for internal cross-chain messaging via Hyperlane.

2. **Domain Configuration**: The CCTPBridge contract automatically configures the correct domain mappings for both mainnet and testnet chains.

3. **Testnet Considerations**: Some testnets use the same domain ID as their mainnet counterparts (e.g., Polygon Amoy uses domain 7 like Polygon PoS), while others have unique testnet domains (e.g., Base Sepolia uses 10002).

## References
- [Circle CCTP Documentation](https://developers.circle.com/cctp/evm-smart-contracts)
- [CCTP v2 Smart Contracts](https://developers.circle.com/cctp/docs/cctp-technical-reference)