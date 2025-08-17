// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { ICrossChainMessenger } from "../interfaces/ICrossChainMessenger.sol";
import { IMessageRecipient } from "../interfaces/Hyperlane/IMessageRecipient.sol";
import { CCTPBridge } from "../core/CCTPBridge.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import { Pausable } from "openzeppelin-contracts/contracts/utils/Pausable.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import { IZuitRouter } from "../interfaces/yield-strategies/IZuitRouter.sol";
import { IZuitPair } from "../interfaces/yield-strategies/IZuitPair.sol";

contract ZircuitChildVault is ReentrancyGuard, Pausable, AccessControl, IMessageRecipient {
    bytes32 public constant MESSENGER_ROLE = keccak256("MESSENGER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    address public usdc;
    uint256 public totalShares;
    uint256 public slippageBps;

    ICrossChainMessenger public crossChainMessenger;
    CCTPBridge public cctpBridge;
    address public motherVault;
    uint32 public motherChainDomain;
    uint256 public lastHarvestNav;

    // Security Enhancements
    uint256 public minLiquidity = 1000e6; // Minimum 1000 USDC liquidity in pool
    uint256 public maxDepositAmount = 100_000e6; // Maximum 100,000 USDC deposit per tx

    struct ApySnapshot {
        uint256 timestamp;
        uint256 nav;
        uint256 shares;
    }

    ApySnapshot[] public apySnapshots;
    uint256 public constant SNAPSHOT_INTERVAL = 1 days;
    uint256 public constant APY_PRECISION = 1e18;

    struct PairInfo {
        address tokenA; // Should always be USDC
        address tokenB;
        address pairAddress;
        address zuitRouter;
        uint256 lastApy;
        bool isActive;
        uint256 lpTokenBalance;
    }

    PairInfo[] public supportedPairs;
    mapping(address => uint256) private pairIndex; // pairAddress => index+1

    event PairAdded(uint256 indexed pairId, address indexed tokenB, address indexed pairAddress);
    event PairRemoved(uint256 indexed pairId);
    event PairStatusUpdated(uint256 indexed pairId, bool isActive);

    event Deposited(uint256 amount, uint256 sharesMinted);
    event Withdrawn(uint256 amount, uint256 sharesBurned);
    event Harvested(uint256 profit);
    event MotherVaultUpdated(address newMotherVault, uint32 newMotherChainDomain);
    event SnapshotTaken(uint256 timestamp, uint256 nav, uint256 shares);
    event ApyReported(uint256 apy);
    event ProfitReported(uint256 profit);
    event SecurityLimitsUpdated(uint256 minLiquidity, uint256 maxDepositAmount);
    event EmergencyWithdrawal(uint256 usdcAmount);

    constructor(address _usdc, address _crossChainMessenger, address _cctpBridge, address _admin) {
        usdc = _usdc;
        crossChainMessenger = ICrossChainMessenger(_crossChainMessenger);
        cctpBridge = CCTPBridge(_cctpBridge);
        slippageBps = 50;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
        _grantRole(MESSENGER_ROLE, _crossChainMessenger);

        uint256 initialNav = 1e6;
        apySnapshots.push(ApySnapshot({ timestamp: block.timestamp, nav: initialNav, shares: 1e6 }));
        totalShares = 1e6;
        lastHarvestNav = initialNav;
    }

    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes calldata _message
    )
        external
        payable
        whenNotPaused
        nonReentrant
    {
        require(msg.sender == address(crossChainMessenger.getHyperlaneMailbox()), "Only Hyperlane Mailbox");
        require(_origin == motherChainDomain, "Only Mother Vault Chain");
        require(_sender == bytes32(uint256(uint160(motherVault))), "Only Mother Vault");

        (ICrossChainMessenger.MessageType messageType, bytes memory data) =
            abi.decode(_message, (ICrossChainMessenger.MessageType, bytes));

        if (messageType == ICrossChainMessenger.MessageType.DEPOSIT_REQUEST) {
            uint256 amount = abi.decode(data, (uint256));
            _handleDeposit(amount);
        } else if (messageType == ICrossChainMessenger.MessageType.YIELD_REPORT) {
            harvest();
        } else if (messageType == ICrossChainMessenger.MessageType.REBALANCE_COMMAND) {
            reportApy();
        } else {
            revert("Invalid message type");
        }
    }

    function _handleDeposit(uint256 amount) internal {
        require(amount <= maxDepositAmount, "Exceeds max deposit amount");

        uint256 bestPairIndex = _getBestPair();
        PairInfo storage bestPair = supportedPairs[bestPairIndex];

        IZuitPair zuitPair = IZuitPair(bestPair.pairAddress);
        (uint112 reserve0, uint112 reserve1,) = zuitPair.getReserves();
        uint256 usdcReserve = zuitPair.token0() == usdc ? reserve0 : reserve1;
        require(usdcReserve >= minLiquidity, "Insufficient liquidity in pool");

        uint256 nav = _calculateNav();
        uint256 sharesToMint;
        if (totalShares == 0) {
            sharesToMint = amount;
        } else {
            sharesToMint = (amount * totalShares) / nav;
        }
        totalShares += sharesToMint;

        uint256 halfAmount = amount / 2;
        // Reset allowance to 0 first for security against approval exploits
        IERC20(usdc).approve(bestPair.zuitRouter, 0);
        IERC20(usdc).approve(bestPair.zuitRouter, halfAmount);

        address[] memory path = new address[](2);
        path[0] = usdc;
        path[1] = bestPair.tokenB;

        IZuitRouter zuitRouter = IZuitRouter(bestPair.zuitRouter);
        uint256[] memory amountsOut = zuitRouter.getAmountsOut(halfAmount, path);
        uint256 minTokenBOut = amountsOut[1] * (10_000 - slippageBps) / 10_000;

        zuitRouter.swapExactTokensForTokens(halfAmount, minTokenBOut, path, address(this), block.timestamp);

        uint256 tokenBBalance = IERC20(bestPair.tokenB).balanceOf(address(this));
        uint256 usdcBalanceForLP = IERC20(usdc).balanceOf(address(this));

        // Reset allowances to 0 first for security against approval exploits
        IERC20(usdc).approve(bestPair.zuitRouter, 0);
        IERC20(usdc).approve(bestPair.zuitRouter, usdcBalanceForLP);
        IERC20(bestPair.tokenB).approve(bestPair.zuitRouter, 0);
        IERC20(bestPair.tokenB).approve(bestPair.zuitRouter, tokenBBalance);

        uint256 minUsdcForLP = usdcBalanceForLP * (10_000 - slippageBps) / 10_000;
        uint256 minTokenBForLP = tokenBBalance * (10_000 - slippageBps) / 10_000;

        (,, uint256 liquidity) = zuitRouter.addLiquidity(
            usdc,
            bestPair.tokenB,
            usdcBalanceForLP,
            tokenBBalance,
            minUsdcForLP,
            minTokenBForLP,
            address(this),
            block.timestamp
        );

        bestPair.lpTokenBalance += liquidity;

        emit Deposited(amount, sharesToMint);
    }

    function withdraw(uint256 amount) external whenNotPaused nonReentrant {
        require(hasRole(MESSENGER_ROLE, msg.sender), "Caller is not the messenger");

        uint256 nav = _calculateNav();
        uint256 sharesToBurn = (amount * totalShares) / nav;
        require(sharesToBurn <= totalShares, "Insufficient shares");
        totalShares -= sharesToBurn;

        uint256 usdcToWithdraw = 0;
        uint256 amountToWithdraw = amount;

        for (uint256 i = 0; i < supportedPairs.length; i++) {
            if (amountToWithdraw == 0) break;

            PairInfo storage pair = supportedPairs[i];
            if (pair.lpTokenBalance > 0) {
                uint256 pairValue = _calculatePairValue(i);
                uint256 withdrawalAmountFromPair = (pairValue <= amountToWithdraw) ? pairValue : amountToWithdraw;

                uint256 lpTotalSupply = IZuitPair(pair.pairAddress).totalSupply();
                uint256 lpAmountToWithdraw = (pair.lpTokenBalance * withdrawalAmountFromPair) / pairValue;

                if (lpAmountToWithdraw > 0) {
                    usdcToWithdraw += _withdrawFromPair(i, lpAmountToWithdraw);
                    amountToWithdraw -= withdrawalAmountFromPair;
                }
            }
        }

        uint256 usdcBalance = IERC20(usdc).balanceOf(address(this));
        if (usdcBalance < usdcToWithdraw + amountToWithdraw) {
            usdcToWithdraw = usdcBalance;
        } else {
            usdcToWithdraw += amountToWithdraw;
        }

        require(IERC20(usdc).balanceOf(address(this)) >= usdcToWithdraw, "Insufficient USDC after withdrawals");

        // Reset allowance to 0 first for security against approval exploits
        IERC20(usdc).approve(address(cctpBridge), 0);
        IERC20(usdc).approve(address(cctpBridge), usdcToWithdraw);
        cctpBridge.bridgeUSDC(usdcToWithdraw, motherChainDomain, motherVault);

        emit Withdrawn(amount, sharesToBurn);
    }

    function _withdrawFromPair(uint256 _pairId, uint256 _lpAmount) internal returns (uint256) {
        PairInfo storage pair = supportedPairs[_pairId];
        // Reset allowance to 0 first for security against approval exploits
        IERC20(pair.pairAddress).approve(pair.zuitRouter, 0);
        IERC20(pair.pairAddress).approve(pair.zuitRouter, _lpAmount);

        IZuitRouter zuitRouter = IZuitRouter(pair.zuitRouter);
        (uint256 usdcFromLp, uint256 tokenBFromLp) =
            zuitRouter.removeLiquidity(pair.tokenA, pair.tokenB, _lpAmount, 0, 0, address(this), block.timestamp);

        pair.lpTokenBalance -= _lpAmount;

        uint256 usdcFromSwap = 0;
        if (tokenBFromLp > 0) {
            // Reset allowance to 0 first for security against approval exploits
            IERC20(pair.tokenB).approve(pair.zuitRouter, 0);
            IERC20(pair.tokenB).approve(pair.zuitRouter, tokenBFromLp);

            address[] memory path = new address[](2);
            path[0] = pair.tokenB;
            path[1] = usdc;

            uint256[] memory amountsOut = zuitRouter.getAmountsOut(tokenBFromLp, path);
            uint256 minUsdcFromSwap = amountsOut[1] * (10_000 - slippageBps) / 10_000;

            uint256[] memory receivedAmounts =
                zuitRouter.swapExactTokensForTokens(tokenBFromLp, minUsdcFromSwap, path, address(this), block.timestamp);
            usdcFromSwap = receivedAmounts[1];
        }

        return usdcFromLp + usdcFromSwap;
    }

    function emergencyWithdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 totalUsdcWithdrawn = 0;
        for (uint256 i = 0; i < supportedPairs.length; i++) {
            PairInfo storage pair = supportedPairs[i];
            if (pair.lpTokenBalance > 0) {
                totalUsdcWithdrawn += _withdrawFromPair(i, pair.lpTokenBalance);
            }
        }
        emit EmergencyWithdrawal(totalUsdcWithdrawn);
    }

    function takeSnapshot() external onlyRole(MESSENGER_ROLE) {
        require(
            block.timestamp >= apySnapshots[apySnapshots.length - 1].timestamp + SNAPSHOT_INTERVAL,
            "Snapshot interval not elapsed"
        );
        uint256 nav = _calculateNav();
        apySnapshots.push(ApySnapshot({ timestamp: block.timestamp, nav: nav, shares: totalShares }));
        emit SnapshotTaken(block.timestamp, nav, totalShares);
    }

    function _calculateNav() public view returns (uint256) {
        uint256 totalNav = IERC20(usdc).balanceOf(address(this));
        for (uint256 i = 0; i < supportedPairs.length; i++) {
            if (supportedPairs[i].lpTokenBalance > 0) {
                totalNav += _calculatePairValue(i);
            }
        }
        return totalNav;
    }

    function _calculatePairValue(uint256 _pairId) internal view returns (uint256) {
        PairInfo storage pair = supportedPairs[_pairId];
        IZuitPair zuitPair = IZuitPair(pair.pairAddress);
        (uint112 reserve0, uint112 reserve1,) = zuitPair.getReserves();
        uint256 lpTotalSupply = zuitPair.totalSupply();

        if (lpTotalSupply == 0) return 0;

        uint256 usdcReserve;
        if (zuitPair.token0() == usdc) {
            usdcReserve = reserve0;
        } else {
            usdcReserve = reserve1;
        }

        return (pair.lpTokenBalance * usdcReserve * 2) / lpTotalSupply;
    }

    function getApy() public view returns (uint256) {
        if (apySnapshots.length < 2) return 0;

        ApySnapshot memory lastSnapshot = apySnapshots[apySnapshots.length - 1];
        ApySnapshot memory firstSnapshot = apySnapshots[0];

        uint256 navPerShareLast = (lastSnapshot.nav * APY_PRECISION) / lastSnapshot.shares;
        uint256 navPerShareFirst = (firstSnapshot.nav * APY_PRECISION) / firstSnapshot.shares;

        uint256 timeElapsed = lastSnapshot.timestamp - firstSnapshot.timestamp;
        if (timeElapsed == 0) return 0;

        uint256 rateOfReturn = (navPerShareLast * APY_PRECISION) / navPerShareFirst;
        uint256 secondsInYear = 31_536_000;
        uint256 yearlyFactor = (secondsInYear * APY_PRECISION) / timeElapsed;
        uint256 apy = ((rateOfReturn - APY_PRECISION) * yearlyFactor * 100) / APY_PRECISION;

        return apy;
    }

    function getVaultState() external view returns (uint256, uint256, uint256) {
        return (_calculateNav(), IERC20(usdc).balanceOf(address(this)), totalShares);
    }

    function harvest() public nonReentrant onlyRole(MESSENGER_ROLE) {
        uint256 nav = _calculateNav();
        uint256 profit = 0;
        if (nav > lastHarvestNav) {
            profit = nav - lastHarvestNav;
            lastHarvestNav = nav;
            emit Harvested(profit);

            bytes memory payload = abi.encode(profit);
            ICrossChainMessenger.CrossChainMessage memory message = ICrossChainMessenger.CrossChainMessage({
                targetChainId: motherChainDomain,
                targetVault: motherVault,
                messageType: ICrossChainMessenger.MessageType.YIELD_REPORT,
                payload: payload,
                nonce: 0,
                timestamp: block.timestamp
            });
            uint256 fee = crossChainMessenger.estimateMessageFee(motherChainDomain);
            crossChainMessenger.sendCrossChainMessage{ value: fee }(message);
            emit ProfitReported(profit);
        } else {
            emit Harvested(0);
        }
    }

    function reportApy() public nonReentrant onlyRole(MESSENGER_ROLE) {
        uint256 apy = getApy();
        bytes memory payload = abi.encode(apy);
        ICrossChainMessenger.CrossChainMessage memory message = ICrossChainMessenger.CrossChainMessage({
            targetChainId: motherChainDomain,
            targetVault: motherVault,
            messageType: ICrossChainMessenger.MessageType.YIELD_REPORT,
            payload: payload,
            nonce: 0,
            timestamp: block.timestamp
        });
        uint256 fee = crossChainMessenger.estimateMessageFee(motherChainDomain);
        crossChainMessenger.sendCrossChainMessage{ value: fee }(message);
        emit ApyReported(apy);
    }

    function setMotherVault(address _motherVault, uint32 _motherChainDomain) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_motherVault != address(0), "Invalid Mother Vault address");
        motherVault = _motherVault;
        motherChainDomain = _motherChainDomain;
        emit MotherVaultUpdated(_motherVault, _motherChainDomain);
    }

    function setSecurityLimits(
        uint256 _minLiquidity,
        uint256 _maxDepositAmount
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        minLiquidity = _minLiquidity;
        maxDepositAmount = _maxDepositAmount;
        emit SecurityLimitsUpdated(_minLiquidity, _maxDepositAmount);
    }

    function setSlippage(uint256 _slippageBps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_slippageBps <= 500, "Slippage cannot exceed 5%");
        slippageBps = _slippageBps;
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function addPair(
        address _tokenB,
        address _pairAddress,
        address _zuitRouter
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(pairIndex[_pairAddress] == 0, "Pair already exists");

        supportedPairs.push(
            PairInfo({
                tokenA: usdc,
                tokenB: _tokenB,
                pairAddress: _pairAddress,
                zuitRouter: _zuitRouter,
                lastApy: 0,
                isActive: true,
                lpTokenBalance: 0
            })
        );

        pairIndex[_pairAddress] = supportedPairs.length;
        emit PairAdded(supportedPairs.length - 1, _tokenB, _pairAddress);
    }

    function removePair(uint256 _pairId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_pairId < supportedPairs.length, "Invalid pair ID");
        PairInfo storage pair = supportedPairs[_pairId];
        require(pair.lpTokenBalance == 0, "Cannot remove pair with active position");

        pairIndex[pair.pairAddress] = 0; // Mark as removed
        pair.isActive = false;

        emit PairRemoved(_pairId);
    }

    function togglePairStatus(uint256 _pairId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_pairId < supportedPairs.length, "Invalid pair ID");
        PairInfo storage pair = supportedPairs[_pairId];
        pair.isActive = !pair.isActive;
        emit PairStatusUpdated(_pairId, pair.isActive);
    }

    function _getBestPair() internal view returns (uint256) {
        uint256 bestPairIndex = type(uint256).max;
        uint256 maxApy = 0;

        for (uint256 i = 0; i < supportedPairs.length; i++) {
            if (supportedPairs[i].isActive) {
                uint256 currentApy = _calculatePairApy(i);
                if (currentApy > maxApy) {
                    maxApy = currentApy;
                    bestPairIndex = i;
                }
            }
        }

        require(bestPairIndex != type(uint256).max, "No active pairs available");
        return bestPairIndex;
    }

    function _calculatePairApy(uint256 _pairId) internal view returns (uint256) {
        PairInfo storage pair = supportedPairs[_pairId];
        IZuitPair zuitPair = IZuitPair(pair.pairAddress);
        (uint112 reserve0, uint112 reserve1,) = zuitPair.getReserves();

        uint256 usdcReserve;
        if (zuitPair.token0() == usdc) {
            usdcReserve = reserve0;
        } else {
            usdcReserve = reserve1;
        }

        // Using the total USDC liquidity in the pool as a proxy for APY.
        // A higher value suggests more fees have been accumulated.
        return usdcReserve * 2;
    }

    function getPairInfo(uint256 _pairId) external view returns (PairInfo memory) {
        require(_pairId < supportedPairs.length, "Invalid pair ID");
        return supportedPairs[_pairId];
    }
}
