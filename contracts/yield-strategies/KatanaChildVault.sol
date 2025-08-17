// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { ICrossChainMessenger } from "../interfaces/ICrossChainMessenger.sol";
import { IMessageRecipient } from "../interfaces/Hyperlane/IMessageRecipient.sol";
import { CCTPBridge } from "../core/CCTPBridge.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import { Pausable } from "openzeppelin-contracts/contracts/utils/Pausable.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import { IKatanaRouter } from "../interfaces/yield-strategies/IKatanaRouter.sol";
import { IKatanaPair } from "../interfaces/yield-strategies/IKatanaPair.sol";
import { IMasterChef } from "../interfaces/yield-strategies/IMasterChef.sol";

contract KatanaChildVault is ReentrancyGuard, Pausable, AccessControl, IMessageRecipient {
    using SafeERC20 for IERC20;

    bytes32 public constant MESSENGER_ROLE = keccak256("MESSENGER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    address public usdc;
    address public weth;
    address public katanaRouter;
    address public katanaPair;
    IMasterChef public masterChef;
    IERC20 public sushiToken;
    uint256 public totalShares;
    uint256 public slippageBps;
    uint256 public sushiConversionThreshold = 100 * 1e6; // $100 in USDC terms
    uint256 public lastSushiHarvest;

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

    event Deposited(uint256 amount, uint256 sharesMinted);
    event Withdrawn(uint256 amount, uint256 sharesBurned);
    event Harvested(uint256 profit);
    event MotherVaultUpdated(address newMotherVault, uint32 newMotherChainDomain);
    event SnapshotTaken(uint256 timestamp, uint256 nav, uint256 shares);
    event ApyReported(uint256 apy);
    event ProfitReported(uint256 profit);
    event SecurityLimitsUpdated(uint256 minLiquidity, uint256 maxDepositAmount);
    event EmergencyWithdrawal(uint256 usdcAmount, uint256 wethAmount);
    event RewardsHarvested(uint256 amount);
    event RewardsConverted(uint256 amountIn, uint256 amountOut);

    constructor(
        address _usdc,
        address _katanaRouter,
        address _katanaPair,
        address _masterChef,
        address _sushiToken,
        address _crossChainMessenger,
        address _cctpBridge,
        address _admin
    ) {
        usdc = _usdc;
        katanaRouter = _katanaRouter;
        katanaPair = _katanaPair;
        masterChef = IMasterChef(_masterChef);
        sushiToken = IERC20(_sushiToken);
        crossChainMessenger = ICrossChainMessenger(_crossChainMessenger);
        cctpBridge = CCTPBridge(_cctpBridge);
        weth = IKatanaRouter(_katanaRouter).WETH();
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
        harvestAndConvertSushi();
        require(amount <= maxDepositAmount, "Exceeds max deposit amount");
        (uint112 reserve0, uint112 reserve1,) = IKatanaPair(katanaPair).getReserves();
        uint256 usdcReserve = IKatanaPair(katanaPair).token0() == usdc ? reserve0 : reserve1;
        require(usdcReserve >= minLiquidity, "Insufficient liquidity in pool");

        // Check that we have enough USDC to process the deposit
        uint256 usdcBalance = IERC20(usdc).balanceOf(address(this));
        require(usdcBalance >= amount, "Insufficient USDC received");

        _addLiquidity(amount);

        uint256 nav = _calculateNav();
        uint256 sharesToMint;
        if (totalShares == 0) {
            sharesToMint = amount;
        } else {
            sharesToMint = (amount * totalShares) / nav;
        }
        totalShares += sharesToMint;
        lastHarvestNav += amount;

        emit Deposited(amount, sharesToMint);
    }

    function withdraw(uint256 amount) external whenNotPaused nonReentrant {
        require(hasRole(MESSENGER_ROLE, msg.sender), "Caller is not the messenger");
        harvestAndConvertSushi();
        uint256 nav = _calculateNav();
        uint256 sharesToBurn = (amount * totalShares) / nav;
        totalShares -= sharesToBurn;
        lastHarvestNav -= amount;

        uint256 liquidityToWithdraw = (amount * IERC20(katanaPair).balanceOf(address(this))) / nav;
        // Reset allowance to 0 first for security against approval exploits
        IERC20(katanaPair).approve(katanaRouter, 0);
        IERC20(katanaPair).approve(katanaRouter, liquidityToWithdraw);

        uint256 minUsdcOut;
        uint256 minWethOut;
        (uint256 reserve0, uint256 reserve1,) = IKatanaPair(katanaPair).getReserves();
        uint256 lpTotalSupply = IKatanaPair(katanaPair).totalSupply();
        if (IKatanaPair(katanaPair).token0() == usdc) {
            minUsdcOut = (liquidityToWithdraw * reserve0 / lpTotalSupply) * (10_000 - slippageBps) / 10_000;
            minWethOut = (liquidityToWithdraw * reserve1 / lpTotalSupply) * (10_000 - slippageBps) / 10_000;
        } else {
            minUsdcOut = (liquidityToWithdraw * reserve1 / lpTotalSupply) * (10_000 - slippageBps) / 10_000;
            minWethOut = (liquidityToWithdraw * reserve0 / lpTotalSupply) * (10_000 - slippageBps) / 10_000;
        }

        IKatanaRouter(katanaRouter).removeLiquidity(
            usdc, weth, liquidityToWithdraw, minUsdcOut, minWethOut, address(this), block.timestamp
        );

        uint256 usdcBalanceBeforeSwap = IERC20(usdc).balanceOf(address(this));
        uint256 wethReceived = IERC20(weth).balanceOf(address(this));
        // Reset allowance to 0 first for security against approval exploits
        IERC20(weth).approve(katanaRouter, 0);
        IERC20(weth).approve(katanaRouter, wethReceived);
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = usdc;

        uint256[] memory amountsOut = IKatanaRouter(katanaRouter).getAmountsOut(wethReceived, path);
        uint256 minUsdcFromSwap = amountsOut[1] * (10_000 - slippageBps) / 10_000;

        IKatanaRouter(katanaRouter).swapExactTokensForTokens(
            wethReceived, minUsdcFromSwap, path, address(this), block.timestamp
        );

        uint256 usdcBalanceAfterSwap = IERC20(usdc).balanceOf(address(this));
        uint256 totalUsdcToWithdraw = usdcBalanceAfterSwap - usdcBalanceBeforeSwap;

        // Reset allowance to 0 first for security against approval exploits
        IERC20(usdc).approve(address(cctpBridge), 0);
        IERC20(usdc).approve(address(cctpBridge), totalUsdcToWithdraw);
        cctpBridge.bridgeUSDC(totalUsdcToWithdraw, motherChainDomain, motherVault);

        emit Withdrawn(amount, sharesToBurn);
    }

    function emergencyWithdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 lpBalance = IERC20(katanaPair).balanceOf(address(this));
        // Reset allowance to 0 first for security against approval exploits
        IERC20(katanaPair).approve(katanaRouter, 0);
        IERC20(katanaPair).approve(katanaRouter, lpBalance);

        (uint256 usdcAmount, uint256 wethAmount) =
            IKatanaRouter(katanaRouter).removeLiquidity(usdc, weth, lpBalance, 0, 0, address(this), block.timestamp);

        emit EmergencyWithdrawal(usdcAmount, wethAmount);
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
        (uint112 reserve0, uint112 reserve1,) = IKatanaPair(katanaPair).getReserves();
        uint256 lpTotalSupply = IKatanaPair(katanaPair).totalSupply();
        uint256 lpBalance = IERC20(katanaPair).balanceOf(address(this));
        uint256 valueOfLpInUsdc;
        if (IKatanaPair(katanaPair).token0() == usdc) {
            valueOfLpInUsdc = (lpBalance * reserve0 * 2) / lpTotalSupply;
        } else {
            valueOfLpInUsdc = (lpBalance * reserve1 * 2) / lpTotalSupply;
        }
        return valueOfLpInUsdc;
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

    function getVaultState() external view returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        return (
            _calculateNav(),
            IERC20(usdc).balanceOf(address(this)),
            IERC20(weth).balanceOf(address(this)),
            IERC20(katanaPair).balanceOf(address(this)),
            totalShares,
            sushiToken.balanceOf(address(this))
        );
    }

    function harvest() public nonReentrant onlyRole(MESSENGER_ROLE) {
        harvestAndConvertSushi();
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

    function harvestSushiRewards() internal {
        // Assuming pid 0 for the relevant LP pair
        uint256 pendingSushi = masterChef.pendingSushi(0, address(this));
        if (pendingSushi > 0) {
            masterChef.harvest(0, address(this));
            lastSushiHarvest = block.timestamp;
            emit RewardsHarvested(pendingSushi);
        }
    }

    function convertSushiToUsdc() internal returns (uint256 usdcReceived) {
        uint256 sushiBalance = sushiToken.balanceOf(address(this));
        if (sushiBalance == 0) {
            return 0;
        }

        address[] memory path = new address[](2);
        path[0] = address(sushiToken);
        path[1] = usdc;

        // Reset allowance to 0 first for security against approval exploits
        sushiToken.approve(katanaRouter, 0);
        sushiToken.approve(katanaRouter, sushiBalance);

        uint256[] memory amountsOut = IKatanaRouter(katanaRouter).getAmountsOut(sushiBalance, path);
        uint256 minUsdcOut = amountsOut[1] * (10_000 - slippageBps) / 10_000;

        IKatanaRouter(katanaRouter).swapExactTokensForTokens(
            sushiBalance, minUsdcOut, path, address(this), block.timestamp
        );
        usdcReceived = IERC20(usdc).balanceOf(address(this)); // Check balance after swap
        emit RewardsConverted(sushiBalance, usdcReceived);
        return usdcReceived;
    }

    function getSushiRewardsValue() public view returns (uint256 usdValue) {
        uint256 sushiBalance = sushiToken.balanceOf(address(this));
        if (sushiBalance == 0) {
            uint256 pendingSushi = masterChef.pendingSushi(0, address(this));
            if (pendingSushi == 0) return 0;
            sushiBalance = pendingSushi;
        }

        address[] memory path = new address[](2);
        path[0] = address(sushiToken);
        path[1] = usdc;

        uint256[] memory amounts = IKatanaRouter(katanaRouter).getAmountsOut(sushiBalance, path);
        return amounts[1];
    }

    function shouldHarvestSushi() public view returns (bool) {
        return getSushiRewardsValue() >= sushiConversionThreshold;
    }

    function harvestAndConvertSushi() internal {
        if (shouldHarvestSushi()) {
            harvestSushiRewards();
            uint256 usdcFromRewards = convertSushiToUsdc();
            if (usdcFromRewards > 0) {
                _addLiquidity(usdcFromRewards);
            }
        }
    }

    function _addLiquidity(uint256 amount) internal {
        uint256 halfAmount = amount / 2;
        // Reset allowance to 0 first for security against approval exploits
        IERC20(usdc).approve(katanaRouter, 0);
        IERC20(usdc).approve(katanaRouter, halfAmount);

        address[] memory path = new address[](2);
        path[0] = usdc;
        path[1] = weth;

        uint256[] memory amountsOut = IKatanaRouter(katanaRouter).getAmountsOut(halfAmount, path);
        uint256 minWethOut = amountsOut[1] * (10_000 - slippageBps) / 10_000;

        IKatanaRouter(katanaRouter).swapExactTokensForTokens(
            halfAmount, minWethOut, path, address(this), block.timestamp
        );

        uint256 wethBalance = IERC20(weth).balanceOf(address(this));
        uint256 usdcBalanceForLP = IERC20(usdc).balanceOf(address(this));

        // Reset allowances to 0 first for security against approval exploits
        IERC20(usdc).approve(katanaRouter, 0);
        IERC20(usdc).approve(katanaRouter, usdcBalanceForLP);
        IERC20(weth).approve(katanaRouter, 0);
        IERC20(weth).approve(katanaRouter, wethBalance);

        uint256 minUsdcForLP = usdcBalanceForLP * (10_000 - slippageBps) / 10_000;
        uint256 minWethForLP = wethBalance * (10_000 - slippageBps) / 10_000;

        IKatanaRouter(katanaRouter).addLiquidity(
            usdc, weth, usdcBalanceForLP, wethBalance, minUsdcForLP, minWethForLP, address(this), block.timestamp
        );
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

    function setSushiConversionThreshold(uint256 _threshold) external onlyRole(DEFAULT_ADMIN_ROLE) {
        sushiConversionThreshold = _threshold;
    }

    function setSlippage(uint256 _slippageBps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_slippageBps <= 500, "Slippage cannot exceed 5%");
        slippageBps = _slippageBps;
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}
