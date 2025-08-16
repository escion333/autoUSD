// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ICrossChainMessenger} from "../interfaces/ICrossChainMessenger.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "openzeppelin-contracts/contracts/utils/Pausable.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import {IKatanaRouter} from "../interfaces/yield-strategies/IKatanaRouter.sol";
import {IKatanaPair} from "../interfaces/yield-strategies/IKatanaPair.sol";

contract KatanaChildVault is
    ReentrancyGuard,
    Pausable,
    AccessControl
{
    using SafeERC20 for IERC20;

    bytes32 public constant MESSENGER_ROLE = keccak256("MESSENGER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    address public usdc;
    address public weth;
    address public katanaRouter;
    address public katanaPair;
    uint256 public totalValue; // Total value locked in the vault in USDC terms
    uint256 public slippageBps; // Slippage tolerance in basis points (e.g., 50 for 0.5%)

    ICrossChainMessenger public crossChainMessenger;

    event Deposited(uint256 amount, uint256 liquidity);
    event Withdrawn(uint256 amount, uint256 liquidity);
    event Harvested(uint256 profit);

    constructor(
        address _usdc,
        address _katanaRouter,
        address _katanaPair,
        address _crossChainMessenger,
        address _admin
    ) {
        usdc = _usdc;
        katanaRouter = _katanaRouter;
        katanaPair = _katanaPair;
        crossChainMessenger = ICrossChainMessenger(_crossChainMessenger);
        weth = IKatanaRouter(_katanaRouter).WETH();
        slippageBps = 50; // Default to 0.5%

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
        _grantRole(MESSENGER_ROLE, _crossChainMessenger);
    }

    function deposit(uint256 amount)
        external
        whenNotPaused
        nonReentrant
    {
        // For now, only the messenger can deposit
        require(
            hasRole(MESSENGER_ROLE, msg.sender),
            "Caller is not the messenger"
        );


        uint256 halfAmount = amount / 2;
        IERC20(usdc).safeApprove(katanaRouter, 0);
        IERC20(usdc).safeApprove(katanaRouter, halfAmount);

        // --- SWAP ---
        address[] memory path = new address[](2);
        path[0] = usdc;
        path[1] = weth;

        // Calculate minimum WETH to receive with slippage protection
        uint[] memory amountsOut = IKatanaRouter(katanaRouter).getAmountsOut(halfAmount, path);
        uint256 minWethOut = amountsOut[1] * (10000 - slippageBps) / 10000;

        IKatanaRouter(katanaRouter).swapExactTokensForTokens(
            halfAmount,
            minWethOut,
            path,
            address(this),
            block.timestamp
        );

        // --- ADD LIQUIDITY ---
        uint256 wethBalance = IERC20(weth).balanceOf(address(this));
        IERC20(usdc).safeApprove(katanaRouter, 0);
        IERC20(usdc).safeApprove(katanaRouter, halfAmount);
        IERC20(weth).safeApprove(katanaRouter, 0);
        IERC20(weth).safeApprove(katanaRouter, wethBalance);

        // Calculate minimum liquidity to receive with slippage protection
        uint256 usdcBalanceForLP = IERC20(usdc).balanceOf(address(this));
        uint256 minUsdcForLP = usdcBalanceForLP * (10000 - slippageBps) / 10000;
        uint256 minWethForLP = wethBalance * (10000 - slippageBps) / 10000;

        (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        ) = IKatanaRouter(katanaRouter).addLiquidity(
                usdc,
                weth,
                halfAmount,
                wethBalance,
                minUsdcForLP,
                minWethForLP,
                address(this),
                block.timestamp
            );

        totalValue += amount; // Approximation, more complex logic can be used for precision
        emit Deposited(amount, liquidity);
    }

    function withdraw(uint256 amount)
        external
        whenNotPaused
        nonReentrant
    {
        require(
            hasRole(MESSENGER_ROLE, msg.sender),
            "Caller is not the messenger"
        );

        // --- REMOVE LIQUIDITY ---
        // For simplicity, we withdraw a proportional amount of liquidity
        uint256 liquidityToWithdraw = (amount *
            IERC20(katanaPair).balanceOf(address(this))) / totalValue;

        IERC20(katanaPair).safeApprove(katanaRouter, 0);
        IERC20(katanaPair).safeApprove(katanaRouter, liquidityToWithdraw);

        // Calculate minimum amounts to receive with slippage protection
        uint256 minUsdcOut = 0; // Will be calculated later based on pair reserves
        uint256 minWethOut = 0;
        // A more robust calculation would involve querying reserves and totalSupply from the pair
        // For now, setting a baseline to prevent full slippage, but this can be improved.
        (uint reserve0, uint reserve1, ) = IKatanaPair(katanaPair).getReserves();
        uint lpTotalSupply = IKatanaPair(katanaPair).totalSupply();
        if (IKatanaPair(katanaPair).token0() == usdc) {
            minUsdcOut = (liquidityToWithdraw * reserve0 / lpTotalSupply) * (10000 - slippageBps) / 10000;
            minWethOut = (liquidityToWithdraw * reserve1 / lpTotalSupply) * (10000 - slippageBps) / 10000;
        } else {
            minUsdcOut = (liquidityToWithdraw * reserve1 / lpTotalSupply) * (10000 - slippageBps) / 10000;
            minWethOut = (liquidityToWithdraw * reserve0 / lpTotalSupply) * (10000 - slippageBps) / 10000;
        }


        (uint256 usdcReceived, uint256 wethReceived) = IKatanaRouter(
            katanaRouter
        ).removeLiquidity(
            usdc,
            weth,
            liquidityToWithdraw,
            minUsdcOut,
            minWethOut,
            address(this),
            block.timestamp
        );

        // --- SWAP WETH TO USDC ---
        uint256 usdcBalanceBeforeSwap = IERC20(usdc).balanceOf(address(this));
        IERC20(weth).safeApprove(katanaRouter, 0);
        IERC20(weth).safeApprove(katanaRouter, wethReceived);
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = usdc;

        uint[] memory amountsOut = IKatanaRouter(katanaRouter).getAmountsOut(wethReceived, path);
        uint256 minUsdcFromSwap = amountsOut[1] * (10000 - slippageBps) / 10000;

        IKatanaRouter(katanaRouter).swapExactTokensForTokens(
            wethReceived,
            minUsdcFromSwap,
            path,
            address(this),
            block.timestamp
        );

        // Precisely calculate the total USDC to withdraw
        uint256 usdcBalanceAfterSwap = IERC20(usdc).balanceOf(address(this));
        uint256 totalUsdcToWithdraw = usdcBalanceAfterSwap - usdcBalanceBeforeSwap + usdcReceived;

        // Send funds back to the messenger (placeholder for CCTP)
        IERC20(usdc).safeTransfer(msg.sender, totalUsdcToWithdraw);

        totalValue -= amount;
        emit Withdrawn(amount, liquidityToWithdraw);
    }

    function getVaultState()
        external
        view
        returns (
            uint256 _totalValue,
            uint256 _usdcBalance,
            uint256 _wethBalance,
            uint256 _lpBalance
        )
    {
        _totalValue = totalValue;
        _usdcBalance = IERC20(usdc).balanceOf(address(this));
        _wethBalance = IERC20(weth).balanceOf(address(this));
        _lpBalance = IERC20(katanaPair).balanceOf(address(this));
    }

    function harvest() external nonReentrant {
        // For now, only the messenger can harvest
        require(
            hasRole(MESSENGER_ROLE, msg.sender),
            "Caller is not the messenger"
        );

        // In a real scenario, this would involve more complex logic to realize profits
        // from yield farming, such as claiming rewards and swapping them to USDC.
        // For this simplified version, we'll calculate the current value of our LP tokens
        // and consider any increase as profit.

        (uint112 reserve0, uint112 reserve1, ) = IKatanaPair(katanaPair)
            .getReserves();
        uint256 lpTotalSupply = IKatanaPair(katanaPair).totalSupply();
        uint256 lpBalance = IERC20(katanaPair).balanceOf(address(this));

        // Calculate the value of the LP tokens in terms of USDC
        uint256 valueOfLpInUsdc;
        if (IKatanaPair(katanaPair).token0() == usdc) {
            valueOfLpInUsdc = (lpBalance * reserve0 * 2) / lpTotalSupply;
        } else {
            valueOfLpInUsdc = (lpBalance * reserve1 * 2) / lpTotalSupply;
        }

        if (valueOfLpInUsdc > totalValue) {
            uint256 profit = valueOfLpInUsdc - totalValue;
            totalValue = valueOfLpInUsdc; // Update total value to reflect profit
            emit Harvested(profit);
            // In a real implementation, we would send the profit back to the MotherVault
            // For example: crossChainMessenger.send(motherVaultDomain, motherVaultAddress, profit);
        } else {
            // No profit to harvest
            emit Harvested(0);
        }
    }

    function getApy() external view returns (uint256) {
        // APY calculation is complex and requires historical data.
        // This is a placeholder and would need a more robust implementation.
        return 500; // Represents 5.00%
    }

    function setSlippage(uint256 _slippageBps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_slippageBps <= 500, "Slippage cannot exceed 5%"); // Cap slippage at 5%
        slippageBps = _slippageBps;
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}
