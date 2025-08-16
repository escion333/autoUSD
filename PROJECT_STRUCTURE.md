# Project Structure - autoUSD

## Directory Organization

```
autoUSD/
│
├── contracts/              # Smart contracts (NORA writes these)
│   ├── core/              # Core protocol contracts
│   │   ├── CCTPBridge.sol
│   │   └── CrossChainMessenger.sol
│   ├── interfaces/        # Contract interfaces
│   │   ├── IChildVault.sol
│   │   ├── ICrossChainMessenger.sol
│   │   ├── IMotherVault.sol
│   │   └── IRebalancer.sol
│   └── MotherVault.sol    # Main vault contract
│
├── test/                   # Test files (Initial agent writes these)
│   ├── mocks/             # Mock contracts for testing
│   │   ├── MockERC20.sol
│   │   ├── MockMailbox.sol
│   │   ├── MockMessageTransmitter.sol
│   │   ├── MockTokenMessenger.sol
│   │   └── MockMotherVault.sol
│   ├── CCTPBridge.t.sol
│   ├── CrossChainMessenger.t.sol
│   └── MotherVault.t.sol
│
├── script/                 # Deployment scripts (empty, for future use)
│
├── lib/                    # External dependencies
│   └── openzeppelin-contracts/
│
├── docs/                   # Internal documentation (gitignored)
│   ├── internal-specs/
│   │   ├── prd.md
│   │   ├── task-planner.md
│   │   └── tokemak-analysis.md
│   └── ai-resources/
│
├── frontend/               # Frontend application (future)
│
├── logs/                   # Test and build logs (gitignored)
│   ├── test-output.log
│   ├── test-output-corrected.log
│   ├── mutation-test.log
│   └── exitcode.txt
│
├── reports/                # Analysis and coverage reports (gitignored)
│   ├── coverage-summary.txt
│   ├── scope_manifest.json
│   └── VERIFICATION_REPORT.md
│
├── out/                    # Compiled contracts (auto-generated)
├── cache/                  # Build cache (auto-generated)
│
├── .env.example            # Environment variables template
├── .gitignore             # Git ignore rules
├── .gitmodules            # Git submodules config
├── CLAUDE.md              # AI context file (gitignored)
├── README.md              # Project documentation
├── foundry.toml           # Foundry configuration
└── package.json           # Node.js dependencies
```

## Key Directories

### `/contracts` - Smart Contracts
- **Owner**: NORA agent
- **Purpose**: All Solidity smart contracts
- **Note**: Only NORA writes files here

### `/test` - Test Suite
- **Owner**: Initial agent
- **Purpose**: Test files and mock contracts
- **Note**: Comprehensive test coverage

### `/docs` - Documentation
- **Status**: Gitignored (internal use only)
- **Purpose**: Internal specifications and planning
- **Contains**: PRD, task planner, analysis docs

### `/logs` - Log Files
- **Status**: Gitignored
- **Purpose**: Test outputs and build logs
- **Note**: Automatically generated, not tracked in git

### `/reports` - Reports
- **Status**: Gitignored
- **Purpose**: Coverage reports and analysis
- **Note**: Generated artifacts from testing

## File Ownership

### NORA Agent Writes:
- All `.sol` files in `/contracts/`
- No other files

### Initial Agent Writes:
- All `.sol` files in `/test/`
- All `.md` documentation files
- All configuration files
- All scripts and deployment files

## Clean Structure Benefits
1. Clear separation between contracts and tests
2. Organized logs and reports (not cluttering root)
3. Gitignored internal documentation
4. No duplicate directories
5. Clear ownership boundaries for AI agents