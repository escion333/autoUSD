# autoUSD Protocol Deployment Guide

This guide covers the complete deployment process for the autoUSD protocol, including security considerations, environment setup, and post-deployment verification.

## 🔐 Security Requirements

### Before Any Deployment

1. **Security Review Completed**: All contracts must be reviewed by security experts
2. **External Audit**: For mainnet deployments, external audit is mandatory
3. **Test Coverage**: Minimum 95% coverage for mainnet, 80% for testnet
4. **Multisig Treasury**: Mainnet deployments must use multisig for treasury

### Key Management

- **Testnet**: Use dedicated testnet keys, never reuse mainnet keys
- **Mainnet**: Use hardware wallets or secure key management systems
- **Separation**: Different keys for different environments
- **Backup**: Secure backup of all deployment artifacts

## 🌐 Supported Networks

### Mainnet
- **Base Mainnet** (Chain ID: 8453)
- **Katana** (Chain ID: TBD)  
- **Zircuit** (Chain ID: TBD)

### Testnet
- **Base Sepolia** (Chain ID: 84532)
- **Katana Testnet** (Chain ID: TBD)
- **Zircuit Testnet** (Chain ID: TBD)

## 📋 Pre-Deployment Checklist

### Environment Setup

1. **Install Dependencies**
   ```bash
   npm install
   forge install
   ```

2. **Configure Environment**
   ```bash
   cp .env.example .env
   # Fill in all required values
   ```

3. **Validate Configuration**
   ```bash
   npm run validate:env
   ```

### Required Environment Variables

See `.env.example` for the complete list. Key variables include:

- `PRIVATE_KEY` / `MAINNET_DEPLOYER_PRIVATE_KEY`
- `TREASURY_ADDRESS` (must be multisig for mainnet)
- Network-specific addresses (USDC, Hyperlane, CCTP)
- Protocol parameters (deposit cap, fees, thresholds)
- API keys for contract verification

### Infrastructure Verification

1. **Hyperlane Mailboxes**: Verify addresses on all target chains
2. **CCTP Infrastructure**: Confirm Circle CCTP availability
3. **USDC Addresses**: Verify official USDC contracts
4. **Gas Funding**: Ensure sufficient ETH for deployment

## 🚀 Deployment Process

### Step 1: Environment Validation

```bash
# Validate all environment variables and infrastructure
npm run validate:env
```

This script checks:
- All required environment variables are set
- Infrastructure contracts exist and have code
- Domain IDs are unique and valid
- Protocol parameters are within acceptable ranges
- Deployer has sufficient balance

### Step 2: Deploy Core Contracts (Base Chain)

#### Testnet Deployment
```bash
# Deploy to Base Sepolia
npm run deploy:testnet
```

#### Mainnet Deployment
```bash
# Deploy to Base Mainnet (requires additional safeguards)
npm run deploy:mainnet
```

The deployment script will:
- Deploy all core contracts (MotherVault, CCTPBridge, etc.)
- Configure initial parameters
- Set up permissions and access control
- Save deployment addresses to `deployments/` directory

### Step 3: Verify Core Deployment

```bash
# Verify all contracts are properly deployed and configured
npm run verify:deployment
```

This verification includes:
- Contract deployment confirmation
- Configuration parameter validation
- Permission verification
- Integration testing

### Step 4: Deploy Child Vaults

#### Katana Child Vault
```bash
# Switch to Katana network and deploy
npm run deploy:child-katana
```

#### Zircuit Child Vault  
```bash
# Switch to Zircuit network and deploy
npm run deploy:child-zircuit
```

### Step 5: Configure Cross-Chain Relationships

```bash
# Configure cross-chain messaging and vault relationships
npm run configure:cross-chain
```

This script:
- Sets up trusted remotes in CrossChainMessenger
- Registers child vaults with MotherVault
- Configures domain mappings
- Establishes cross-chain communication

### Step 6: Setup Domain Mapping

```bash
# Generate and deploy domain mapping configuration
npm run setup:domain-mapping
```

Creates configuration files for:
- Hyperlane domain mappings
- CCTP domain configurations
- Network relationship definitions

## 🔍 Post-Deployment Verification

### Automated Verification

1. **Contract Verification**: All contracts verified on block explorers
2. **Configuration Check**: Parameters match expected values
3. **Permission Audit**: Access controls properly configured
4. **Integration Test**: Cross-chain functionality working

### Manual Verification

1. **Treasury Setup**: Confirm multisig configuration
2. **Emergency Controls**: Test pause functionality
3. **Fee Collection**: Verify fee recipient addresses
4. **Cross-Chain Messaging**: Test message passing

### Monitoring Setup

1. **Health Monitors**: Deploy monitoring infrastructure
2. **Alert Systems**: Configure failure notifications
3. **Dashboard Setup**: Operational monitoring tools
4. **Emergency Contacts**: Incident response team

## 🤖 CI/CD Deployment

### GitHub Actions Workflows

The project includes automated deployment workflows:

#### Testnet Deployment
- Triggered manually via GitHub Actions
- Requires test coverage validation
- Includes security checks
- Automatic verification and monitoring

#### Mainnet Deployment
- Requires explicit confirmation and approval
- Mandatory security review verification
- Multi-step validation process
- Comprehensive post-deployment verification

### Workflow Security

- **Environment Protection**: Mainnet deployments require approval
- **Secret Management**: All sensitive data in GitHub Secrets
- **Audit Trail**: Complete deployment history
- **Rollback Capability**: Emergency rollback procedures

## 📊 Environment Configuration

### Repository Variables

Configure these in GitHub repository settings:

**Testnet Variables:**
- `USDC_ADDRESS_TESTNET`
- `HYPERLANE_MAILBOX_TESTNET`
- `CCTP_TOKEN_MESSENGER_TESTNET`
- etc.

**Mainnet Variables:**
- `TREASURY_ADDRESS_MAINNET`
- `USDC_ADDRESS_MAINNET`
- `HYPERLANE_MAILBOX_MAINNET`
- etc.

### Repository Secrets

**Required Secrets:**
- `DEPLOYER_PRIVATE_KEY` (testnet)
- `MAINNET_DEPLOYER_PRIVATE_KEY` (mainnet)
- `BASESCAN_API_KEY`
- `ETHERSCAN_API_KEY`
- `BASE_RPC_URL`
- `BASE_SEPOLIA_RPC_URL`

## 🚨 Emergency Procedures

### Pause Protocol

In case of emergency:

```bash
# Pause all protocol operations
forge script script/emergency/PauseProtocol.s.sol --rpc-url $RPC_URL --broadcast
```

### Upgrade Contracts

For urgent fixes:

```bash
# Deploy and execute upgrades
forge script script/upgrades/UpgradeProtocol.s.sol --rpc-url $RPC_URL --broadcast
```

### Recovery Procedures

1. **Assess Situation**: Determine scope and impact
2. **Pause if Necessary**: Stop all operations if required
3. **Investigate**: Understand root cause
4. **Plan Recovery**: Develop fix and recovery plan
5. **Execute**: Deploy fixes and resume operations
6. **Post-Mortem**: Document lessons learned

## 📞 Support and Contact

### Development Team
- **Primary**: [development-team@autousd.io]
- **Emergency**: [emergency@autousd.io]
- **Security**: [security@autousd.io]

### External Resources
- **Hyperlane Documentation**: https://docs.hyperlane.xyz/
- **Circle CCTP Documentation**: https://developers.circle.com/stablecoins/docs
- **Base Network Documentation**: https://docs.base.org/

## 📚 Additional Resources

- [Architecture Documentation](../docs/architecture/)
- [Security Best Practices](../docs/security/)
- [Testing Guide](../docs/testing/)
- [API Documentation](../docs/api/)

---

**⚠️ Important**: Always test deployments on testnets first. Never deploy to mainnet without thorough testing and security review.