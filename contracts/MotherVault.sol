// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IMotherVault} from "./interfaces/IMotherVault.sol";
import {ICrossChainMessenger} from "./interfaces/ICrossChainMessenger.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {CCTPBridge} from "./core/CCTPBridge.sol";
import {CrossChainMessenger} from "./core/CrossChainMessenger.sol";

contract MotherVault is IMotherVault, ERC20, ReentrancyGuard, Pausable, AccessControl {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant REBALANCER_ROLE = keccak256("REBALANCER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    uint256 public constant FEE_DIVISOR = 10_000;
    uint256 public constant USDC_INIT_DEPOSIT = 100 * 1e6;
    address public constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    uint256 public constant BUFFER_PERCENTAGE = 500; // 5% in basis points
    
    IERC20 public immutable override USDC;
    uint8 private immutable _usdcDecimals;
    
    uint256 public override depositCap;
    uint256 public override managementFeeBps;
    uint256 public override rebalanceCooldown;
    uint256 public override minAPYDifferential;
    uint256 public override lastRebalanceTime;
    address public override feeSink;
    bool public bufferManagementEnabled = true;
    
    // Rate limiting for rebalancing
    uint256 public constant MAX_REBALANCE_FREQUENCY = 4; // Max rebalances per day
    uint256 public constant RATE_LIMIT_WINDOW = 1 days;
    uint256[] public rebalanceHistory;
    
    uint256 private _totalIdle;
    uint256 private _totalDeployed;
    uint256 private _lastFeeCollection;
    
    mapping(uint32 => ChildVault) private _childVaults;
    uint32[] private _activeChainIds;
    
    mapping(bytes32 => bool) private _processedMessages;
    
    ICrossChainMessenger public crossChainMessenger;
    CCTPBridge public cctpBridge;
    
    // Additional events not in interface
    event RebalanceInitiated(uint32 indexed worstChain, uint32 indexed bestChain, uint256 amount);
    
    modifier onlyActiveChild(uint32 domainId) {
        if (!_childVaults[domainId].isActive) revert ChildVaultNotActive(domainId);
        _;
    }
    
    constructor(
        address _usdc,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        require(_usdc != address(0), "Invalid USDC address");
        
        USDC = IERC20(_usdc);
        _usdcDecimals = IERC20Metadata(_usdc).decimals();
        
        depositCap = 100 * 10 ** _usdcDecimals;
        managementFeeBps = 50;
        rebalanceCooldown = 24 hours;
        minAPYDifferential = 500;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);
        _grantRole(REBALANCER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        
        feeSink = msg.sender;
        _lastFeeCollection = block.timestamp;
    }
    
    function initialize(address _crossChainMessenger, address _cctpBridge) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(address(crossChainMessenger) == address(0), "Already initialized");
        require(_crossChainMessenger != address(0), "Invalid messenger");
        require(_cctpBridge != address(0), "Invalid bridge");
        
        crossChainMessenger = ICrossChainMessenger(_crossChainMessenger);
        cctpBridge = CCTPBridge(_cctpBridge);
        
        USDC.safeTransferFrom(msg.sender, address(this), USDC_INIT_DEPOSIT);
        _mint(DEAD_ADDRESS, USDC_INIT_DEPOSIT);
        
        _totalIdle = USDC_INIT_DEPOSIT;
    }
    
    function asset() public view override returns (address) {
        return address(USDC);
    }
    
    function totalAssets() public view override returns (uint256) {
        return _totalIdle + _totalDeployed;
    }
    
    function totalDeployedAssets() public view override returns (uint256) {
        return _totalDeployed;
    }
    
    /**
     * @dev Returns the required buffer amount (5% of total assets)
     */
    function getRequiredBuffer() public view returns (uint256) {
        if (!bufferManagementEnabled) return 0;
        return (totalAssets() * BUFFER_PERCENTAGE) / FEE_DIVISOR;
    }
    
    /**
     * @dev Returns the current buffer amount (idle USDC balance)
     */
    function getCurrentBuffer() public view returns (uint256) {
        return _totalIdle;
    }
    
    /**
     * @dev Checks if the current buffer is sufficient
     */
    function isBufferSufficient() public view returns (bool) {
        if (!bufferManagementEnabled) return true;
        return getCurrentBuffer() >= getRequiredBuffer();
    }
    
    /**
     * @dev Returns the amount available for deployment (excess above buffer)
     */
    function getDeployableAmount() public view returns (uint256) {
        if (!bufferManagementEnabled) return _totalIdle;
        
        uint256 requiredBuffer = getRequiredBuffer();
        uint256 currentBuffer = getCurrentBuffer();
        
        if (currentBuffer <= requiredBuffer) return 0;
        return currentBuffer - requiredBuffer;
    }
    
    function convertToShares(uint256 assets) public view override returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }
    
    function convertToAssets(uint256 shares) public view override returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Floor);
    }
    
    function maxDeposit(address) public view override returns (uint256) {
        if (paused()) return 0;
        
        uint256 currentTotal = totalAssets();
        if (currentTotal >= depositCap) return 0;
        
        return depositCap - currentTotal;
    }
    
    function maxMint(address receiver) public view override returns (uint256) {
        uint256 maxAssets = maxDeposit(receiver);
        if (maxAssets == 0) return 0;
        
        return _convertToShares(maxAssets, Math.Rounding.Floor);
    }
    
    function maxWithdraw(address owner) public view override returns (uint256) {
        if (paused()) return 0;
        
        uint256 ownerShares = balanceOf(owner);
        if (ownerShares == 0) return 0;
        
        uint256 availableAssets = _getAvailableForWithdrawal();
        uint256 ownerAssets = _convertToAssets(ownerShares, Math.Rounding.Floor);
        
        return availableAssets > ownerAssets ? ownerAssets : availableAssets;
    }
    
    function maxRedeem(address owner) public view override returns (uint256) {
        if (paused()) return 0;
        
        uint256 ownerShares = balanceOf(owner);
        if (ownerShares == 0) return 0;
        
        uint256 availableAssets = _getAvailableForWithdrawal();
        uint256 maxSharesForAvailable = _convertToShares(availableAssets, Math.Rounding.Floor);
        
        return ownerShares > maxSharesForAvailable ? maxSharesForAvailable : ownerShares;
    }
    
    function previewDeposit(uint256 assets) public view override returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }
    
    function previewMint(uint256 shares) public view override returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Ceil);
    }
    
    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Ceil);
    }
    
    function previewRedeem(uint256 shares) public view override returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Floor);
    }
    
    function deposit(uint256 assets, address receiver) 
        public 
        override 
        nonReentrant 
        whenNotPaused 
        returns (uint256 shares) 
    {
        require(assets > 0, "Zero assets");
        
        uint256 maxAssets = maxDeposit(receiver);
        if (assets > maxAssets) {
            revert DepositExceedsCap(assets, maxAssets);
        }
        
        shares = previewDeposit(assets);
        require(shares > 0, "Zero shares");
        
        USDC.safeTransferFrom(msg.sender, address(this), assets);
        
        _mint(receiver, shares);
        _totalIdle += assets;
        
        emit Deposit(msg.sender, receiver, assets, shares);
        
        return shares;
    }
    
    function mint(uint256 shares, address receiver) 
        public 
        override 
        nonReentrant 
        whenNotPaused 
        returns (uint256 assets) 
    {
        require(shares > 0, "Zero shares");
        
        assets = previewMint(shares);
        
        uint256 maxAssets = maxDeposit(receiver);
        if (assets > maxAssets) {
            revert DepositExceedsCap(assets, maxAssets);
        }
        
        USDC.safeTransferFrom(msg.sender, address(this), assets);
        
        _mint(receiver, shares);
        _totalIdle += assets;
        
        emit Deposit(msg.sender, receiver, assets, shares);
        
        return assets;
    }
    
    function withdraw(uint256 assets, address receiver, address owner) 
        public 
        override 
        nonReentrant 
        whenNotPaused 
        returns (uint256 shares) 
    {
        require(assets > 0, "Zero assets");
        require(assets <= maxWithdraw(owner), "Exceeds max");
        
        shares = previewWithdraw(assets);
        
        // Effects: State changes are made before the external call to prevent reentrancy.
        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }
        
        _burn(owner, shares);
        _totalIdle -= assets;
        
        // Interactions: External call to transfer USDC
        USDC.safeTransfer(receiver, assets);
        
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        
        return shares;
    }
    
    function redeem(uint256 shares, address receiver, address owner) 
        public 
        override 
        nonReentrant 
        whenNotPaused 
        returns (uint256 assets) 
    {
        require(shares > 0, "Zero shares");
        require(shares <= maxRedeem(owner), "Exceeds max");
        
        assets = previewRedeem(shares);
        
        // Effects: State changes are made before the external call to prevent reentrancy.
        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }
        
        _burn(owner, shares);
        _totalIdle -= assets;
        
        // Interactions: External call to transfer USDC
        USDC.safeTransfer(receiver, assets);
        
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        
        return assets;
    }
    
    function addChildVault(uint32 domainId, address vaultAddress) 
        external 
        override 
        onlyRole(MANAGER_ROLE) 
    {
        require(vaultAddress != address(0), "Invalid vault address");
        require(!_childVaults[domainId].isActive, "Vault already exists");
        
        _childVaults[domainId] = ChildVault({
            domainId: domainId,
            vaultAddress: vaultAddress,
            lastReportTime: block.timestamp,
            deployedAmount: 0,
            reportedAPY: 0,
            isActive: true
        });
        
        _activeChainIds.push(domainId);
        
        emit ChildVaultAdded(domainId, vaultAddress);
    }
    
    function removeChildVault(uint32 domainId) 
        external 
        override 
        onlyRole(MANAGER_ROLE)
        onlyActiveChild(domainId)
    {
        require(_childVaults[domainId].deployedAmount == 0, "Vault has funds");
        
        _childVaults[domainId].isActive = false;
        
        for (uint256 i = 0; i < _activeChainIds.length; i++) {
            if (_activeChainIds[i] == domainId) {
                _activeChainIds[i] = _activeChainIds[_activeChainIds.length - 1];
                _activeChainIds.pop();
                break;
            }
        }
        
        emit ChildVaultRemoved(domainId, _childVaults[domainId].vaultAddress);
    }
    
    function strategicDeploy(StrategicDeployParams calldata params) 
        external 
        override 
        onlyRole(REBALANCER_ROLE)
        whenNotPaused
    {
        require(block.timestamp >= lastRebalanceTime + rebalanceCooldown, "Cooldown active");
        require(params.amount > 0, "Zero amount");
        
        if (bufferManagementEnabled) {
            uint256 deployableAmount = getDeployableAmount();
            require(params.amount <= deployableAmount, "Amount exceeds deployable (buffer requirement)");
        }
        
        _enforceRateLimit();
        
        require(_childVaults[params.targetChainId].isActive, "Target not active");
        
        uint256 averageAPY = _getAverageAPY();
        uint256 targetAPY = _childVaults[params.targetChainId].reportedAPY;
        
        uint256 diff = targetAPY > averageAPY ? targetAPY - averageAPY : 0;
            
        if (diff < params.minAPYDifferential) {
            revert InsufficientAPYDifferential(diff, params.minAPYDifferential);
        }
        
        lastRebalanceTime = block.timestamp;
        
        rebalanceHistory.push(block.timestamp);
        
        _deployToChild(params.targetChainId, params.amount);
        
        emit StrategicDeployInitiated(params.targetChainId, params.amount);
    }

    function rebalance() external onlyRole(REBALANCER_ROLE) whenNotPaused {
        require(block.timestamp >= lastRebalanceTime + rebalanceCooldown, "Cooldown active");
        _enforceRateLimit();

        // Check buffer status before rebalancing
        if (bufferManagementEnabled && !isBufferSufficient()) {
            revert("Buffer insufficient for rebalancing");
        }

        (uint32 bestChain, uint32 worstChain) = _findBestAndWorstPerformingVaults();

        require(bestChain != 0 && worstChain != 0 && bestChain != worstChain, "No rebalance needed");

        ChildVault storage bestVault = _childVaults[bestChain];
        ChildVault storage worstVault = _childVaults[worstChain];

        uint256 apyDiff = bestVault.reportedAPY - worstVault.reportedAPY;
        require(apyDiff >= minAPYDifferential, "Insufficient APY differential");

        uint256 rebalanceAmount = _calculateRebalanceAmount(worstVault.deployedAmount, bestVault.deployedAmount);
        
        if (rebalanceAmount > 0) {
            lastRebalanceTime = block.timestamp;
            rebalanceHistory.push(block.timestamp);
            _withdrawFromChild(worstChain, rebalanceAmount);
            // The deployment to the best vault will be handled upon receipt of the withdrawn funds
            emit RebalanceInitiated(worstChain, bestChain, rebalanceAmount);
        }
    }
    
    /**
     * @dev Initiates a rebalance operation by withdrawing from source and deploying to target
     * This function is called by the Rebalancer contract
     */
    function initiateRebalance(uint32 sourceChainId, uint32 targetChainId, uint256 amount) 
        external 
        onlyRole(REBALANCER_ROLE) 
        whenNotPaused 
    {
        require(_childVaults[sourceChainId].isActive, "Source vault not active");
        require(_childVaults[targetChainId].isActive, "Target vault not active");
        require(amount > 0, "Zero amount");
        
        // Ensure we have sufficient deployed funds in source vault
        require(_childVaults[sourceChainId].deployedAmount >= amount, "Insufficient deployed funds in source");
        
        // Initiate withdrawal from source vault
        _withdrawFromChild(sourceChainId, amount);
        
        emit RebalanceInitiated(sourceChainId, targetChainId, amount);
        
        // Note: The deployment to target vault will happen automatically 
        // when the withdrawn funds are received via handleCCTPReceive
    }
    
    function deployToChildVault(uint32 domainId, uint256 amount) 
        external 
        onlyRole(MANAGER_ROLE) 
        onlyActiveChild(domainId)
    {
        require(amount <= _totalIdle, "Insufficient idle funds");
        
        if (bufferManagementEnabled) {
            uint256 deployableAmount = getDeployableAmount();
            require(amount <= deployableAmount, "Amount exceeds deployable (buffer requirement)");
        }
        
        _deployToChild(domainId, amount);
    }
    
    function _deployToChild(uint32 domainId, uint256 amount) private {
        _totalIdle -= amount;
        
        // Approve CCTP bridge to spend USDC for this transaction
        // Resetting allowance to 0 first is a safety measure against some exploits
        USDC.approve(address(cctpBridge), 0);
        USDC.approve(address(cctpBridge), amount);
        
        cctpBridge.bridgeUSDC(amount, domainId, _childVaults[domainId].vaultAddress);
        
        _totalDeployed += amount;
        _childVaults[domainId].deployedAmount += amount;
        
        ICrossChainMessenger.CrossChainMessage memory crossChainMsg = ICrossChainMessenger.CrossChainMessage({
            messageType: ICrossChainMessenger.MessageType.DEPOSIT_REQUEST,
            targetChainId: domainId,
            targetVault: _childVaults[domainId].vaultAddress,
            payload: abi.encode(amount),
            nonce: block.timestamp,
            timestamp: block.timestamp
        });
        
        uint256 fee = crossChainMessenger.estimateMessageFee(domainId);
        bytes32 messageId = crossChainMessenger.sendCrossChainMessage{value: fee}(crossChainMsg);
        
        emit FundsDeployedToChild(domainId, amount, messageId);
    }

    function _withdrawFromChild(uint32 domainId, uint256 amount) private {
        ICrossChainMessenger.CrossChainMessage memory crossChainMsg = ICrossChainMessenger.CrossChainMessage({
            messageType: ICrossChainMessenger.MessageType.WITHDRAWAL_REQUEST,
            targetChainId: domainId,
            targetVault: _childVaults[domainId].vaultAddress,
            payload: abi.encode(amount),
            nonce: block.timestamp,
            timestamp: block.timestamp
        });
        
        uint256 fee = crossChainMessenger.estimateMessageFee(domainId);
        bytes32 messageId = crossChainMessenger.sendCrossChainMessage{value: fee}(crossChainMsg);
        
        emit WithdrawalRequestSent(domainId, amount, messageId);
    }
    
    /**
     * @dev Requests buffer refill by proportionally withdrawing from all child vaults
     * This function is called when buffer is below the required threshold
     */
    function requestBufferRefill() external onlyRole(MANAGER_ROLE) {
        require(bufferManagementEnabled, "Buffer management disabled");
        require(!isBufferSufficient(), "Buffer is sufficient");
        
        uint256 bufferDeficit = getRequiredBuffer() - getCurrentBuffer();
        require(bufferDeficit > 0, "No buffer deficit");
        
        uint256 totalDeployed = _totalDeployed;
        require(totalDeployed > 0, "No deployed funds to recall");
        
        // Proportionally withdraw from all active child vaults
        for (uint256 i = 0; i < _activeChainIds.length; i++) {
            uint32 chainId = _activeChainIds[i];
            ChildVault storage vault = _childVaults[chainId];
            
            if (vault.deployedAmount > 0) {
                // Calculate proportional amount to withdraw from this vault
                uint256 withdrawAmount = (bufferDeficit * vault.deployedAmount) / totalDeployed;
                
                // Don't withdraw more than what's deployed in this vault
                if (withdrawAmount > vault.deployedAmount) {
                    withdrawAmount = vault.deployedAmount;
                }
                
                if (withdrawAmount > 0) {
                    _withdrawFromChild(chainId, withdrawAmount);
                    emit BufferRefillRequested(chainId, withdrawAmount);
                }
            }
        }
    }
    
    function handleIncomingMessage(uint32 origin, bytes32 sender, bytes calldata message) 
        external 
        override 
    {
        require(msg.sender == address(crossChainMessenger), "Only messenger");
        require(_childVaults[origin].isActive, "Unknown origin");
        
        // Authenticate the original sender from the source chain
        bytes32 expectedSender = bytes32(uint256(uint160(_childVaults[origin].vaultAddress)));
        require(sender == expectedSender, "Untrusted sender for origin");
        
        // Process yield reports and other messages from child vaults
        (uint8 messageType, bytes memory payload) = abi.decode(message, (uint8, bytes));
        
        if (messageType == 2) { // YIELD_REPORT
            (uint256 apy, uint256 totalValue) = abi.decode(payload, (uint256, uint256));
            _childVaults[origin].reportedAPY = apy;
            _childVaults[origin].lastReportTime = block.timestamp;
            emit YieldReported(origin, apy, totalValue);
        }
    }
    
    function handleCCTPReceive(uint256 amount, uint32 sourceDomain, bytes32 /*sender*/) 
        external 
        override 
    {
        require(msg.sender == address(crossChainMessenger), "Only messenger");
        require(_childVaults[sourceDomain].isActive, "Unknown source");
        
        // Update accounting for received USDC from child vault
        _totalIdle += amount;
        _childVaults[sourceDomain].deployedAmount -= amount;
        _totalDeployed -= amount;
        
        emit FundsReceivedFromChild(sourceDomain, amount);
    }
    
    function reportYield(uint32 domainId, uint256 apy, uint256 totalValue) 
        external 
        override
        onlyActiveChild(domainId)
    {
        _childVaults[domainId].reportedAPY = apy;
        _childVaults[domainId].lastReportTime = block.timestamp;
        
        emit YieldReported(domainId, apy, totalValue);
    }
    
    function emergencyPause() external override onlyRole(PAUSER_ROLE) {
        _pause();
        emit EmergencyPauseActivated(msg.sender);
    }
    
    function emergencyUnpause() external override onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    function emergencyWithdrawAll() external override onlyRole(DEFAULT_ADMIN_ROLE) whenPaused {
        uint256 idleBalance = _totalIdle;
        _totalIdle = 0;
        USDC.safeTransfer(feeSink, idleBalance);
        emit EmergencyWithdrawal(feeSink, idleBalance);
    }
    
    function setDepositCap(uint256 newCap) external override onlyRole(MANAGER_ROLE) {
        uint256 oldCap = depositCap;
        depositCap = newCap;
        emit DepositCapUpdated(oldCap, newCap);
    }
    
    function setManagementFee(uint256 feeBps) external override onlyRole(MANAGER_ROLE) {
        require(feeBps <= 1000, "Fee too high");
        managementFeeBps = feeBps;
    }
    
    function setRebalanceCooldown(uint256 cooldownPeriod) external override onlyRole(MANAGER_ROLE) {
        rebalanceCooldown = cooldownPeriod;
    }
    
    function setMinAPYDifferential(uint256 minDifferentialBps) external override onlyRole(MANAGER_ROLE) {
        minAPYDifferential = minDifferentialBps;
    }
    
    function setBufferManagement(bool enabled) external onlyRole(MANAGER_ROLE) {
        bool oldState = bufferManagementEnabled;
        bufferManagementEnabled = enabled;
        
        if (oldState != enabled) {
            emit BufferManagementToggled(enabled);
            emit BufferStatusChanged(getRequiredBuffer(), getCurrentBuffer(), isBufferSufficient());
        }
    }
    
    function collectManagementFees() external override returns (uint256 feeAmount) {
        uint256 timeSinceLastCollection = block.timestamp - _lastFeeCollection;
        uint256 totalManagedAssets = totalAssets();
        
        // Fee is calculated as an annual percentage rate (APR).
        // fee = assets * (feeBps / 10000) * (time / seconds_in_year)
        uint256 SECONDS_PER_YEAR = 365 days;
        feeAmount = (totalManagedAssets * managementFeeBps * timeSinceLastCollection) / (FEE_DIVISOR * SECONDS_PER_YEAR);
        
        if (feeAmount > 0 && feeAmount <= _totalIdle) {
            _totalIdle -= feeAmount;
            USDC.safeTransfer(feeSink, feeAmount);
            _lastFeeCollection = block.timestamp;
            
            emit ManagementFeeCollected(feeAmount, feeSink);
        }
        
        return feeAmount;
    }
    
    function getChildVault(uint32 domainId) external view override returns (ChildVault memory) {
        return _childVaults[domainId];
    }
    
    function getAllChildVaults() external view override returns (uint32[] memory domainIds, ChildVault[] memory vaults) {
        domainIds = _activeChainIds;
        vaults = new ChildVault[](domainIds.length);
        
        for (uint256 i = 0; i < domainIds.length; i++) {
            vaults[i] = _childVaults[domainIds[i]];
        }
    }
    
    function isPaused() external view override returns (bool) {
        return paused();
    }
    
    function decimals() public view override(ERC20, IERC20Metadata) returns (uint8) {
        return _usdcDecimals;
    }
    
    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view returns (uint256) {
        uint256 supply = totalSupply();
        return (assets == 0 || supply == 0) 
            ? assets 
            : assets.mulDiv(supply, totalAssets(), rounding);
    }
    
    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view returns (uint256) {
        uint256 supply = totalSupply();
        return (supply == 0) 
            ? shares 
            : shares.mulDiv(totalAssets(), supply, rounding);
    }
    
    function _enforceRateLimit() private {
        uint256 currentTime = block.timestamp;
        uint256 pruneCount = 0;
        
        for (uint256 i = 0; i < rebalanceHistory.length; i++) {
            if (currentTime - rebalanceHistory[i] > RATE_LIMIT_WINDOW) {
                pruneCount++;
            } else {
                break;
            }
        }
        
        if (pruneCount > 0) {
            uint256 newLength = rebalanceHistory.length - pruneCount;
            for (uint256 i = 0; i < newLength; i++) {
                rebalanceHistory[i] = rebalanceHistory[i + pruneCount];
            }
            
            for (uint256 i = 0; i < pruneCount; i++) {
                rebalanceHistory.pop();
            }
        }
        
        require(rebalanceHistory.length < MAX_REBALANCE_FREQUENCY, "Rate limit exceeded");
    }
    
    function _getAverageAPY() private view returns (uint256) {
        uint256 totalWeightedAPY = 0;
        uint256 totalDeployed = _totalDeployed;
        
        if (totalDeployed == 0) return 0;
        
        for (uint256 i = 0; i < _activeChainIds.length; i++) {
            ChildVault storage vault = _childVaults[_activeChainIds[i]];
            totalWeightedAPY += vault.reportedAPY * vault.deployedAmount;
        }
        
        return totalWeightedAPY / totalDeployed;
    }
    
    function getRebalanceCount() external view returns (uint256) {
        uint256 recentRebalances = 0;
        uint256 currentTime = block.timestamp;
        
        for (uint256 i = rebalanceHistory.length; i > 0; i--) {
            if (currentTime - rebalanceHistory[i - 1] <= RATE_LIMIT_WINDOW) {
                recentRebalances++;
            } else {
                break;
            }
        }
        
        return recentRebalances;
    }

    function _findBestAndWorstPerformingVaults() private view returns (uint32 bestChain, uint32 worstChain) {
        uint256 maxApy = 0;
        uint256 minApy = type(uint256).max;
        
        for (uint i = 0; i < _activeChainIds.length; i++) {
            uint32 chainId = _activeChainIds[i];
            ChildVault storage vault = _childVaults[chainId];
            if (vault.reportedAPY > maxApy) {
                maxApy = vault.reportedAPY;
                bestChain = chainId;
            }
            if (vault.reportedAPY < minApy) {
                minApy = vault.reportedAPY;
                worstChain = chainId;
            }
        }
    }

    function _calculateRebalanceAmount(uint256 worstVaultBalance, uint256 bestVaultBalance) private pure returns (uint256) {
        uint256 total = worstVaultBalance + bestVaultBalance;
        uint256 idealAmount = total / 2;
        
        if (worstVaultBalance > idealAmount) {
            return worstVaultBalance - idealAmount;
        }
        
        return 0;
    }
    
    /**
     * @dev Returns the amount of assets available for withdrawal considering buffer requirements
     */
    function _getAvailableForWithdrawal() private view returns (uint256) {
        if (!bufferManagementEnabled) return _totalIdle;
        
        uint256 requiredBuffer = getRequiredBuffer();
        uint256 currentBuffer = getCurrentBuffer();
        
        // If we're below buffer, no withdrawals allowed
        if (currentBuffer <= requiredBuffer) return 0;
        
        // Only allow withdrawal of excess above buffer
        return currentBuffer - requiredBuffer;
    }
}