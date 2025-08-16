// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {KatanaChildVault} from "../contracts/yield-strategies/KatanaChildVault.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockCrossChainMessenger} from "./mocks/MockCrossChainMessenger.sol";
import {MockCCTPBridge} from "./mocks/MockCCTPBridge.sol";
import {MockTokenMessenger} from "./mocks/MockTokenMessenger.sol";
import {MockMessageTransmitter} from "./mocks/MockMessageTransmitter.sol";
import {IKatanaRouter} from "../contracts/interfaces/yield-strategies/IKatanaRouter.sol";
import {IKatanaPair} from "../contracts/interfaces/yield-strategies/IKatanaPair.sol";
import {ICrossChainMessenger} from "../contracts/interfaces/ICrossChainMessenger.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockKatanaPair is IKatanaPair, MockERC20 {
    address public token0;
    address public token1;
    uint112 public reserve0;
    uint112 public reserve1;

    constructor(string memory name, string memory symbol) MockERC20(name, symbol, 18) {}

    function setToken0(address _token0) external {
        token0 = _token0;
    }
    
    function setToken1(address _token1) external {
        token1 = _token1;
    }

    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        return (reserve0, reserve1, uint32(block.timestamp));
    }

    function setReserves(uint112 _reserve0, uint112 _reserve1) external {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
    }

    function totalSupply() public view override(IKatanaPair, ERC20) returns (uint256) {
        return super.totalSupply();
    }
}

contract MockKatanaRouter is IKatanaRouter {
    address public immutable WETH;

    constructor(address _weth) {
        WETH = _weth;
    }

    function addLiquidity(address, address, uint256, uint256, uint256, uint256, address, uint256) external pure returns (uint256, uint256, uint256) {
        return (0, 0, 100 ether);
    }

    function removeLiquidity(address, address, uint256, uint256, uint256, address, uint256) external pure returns (uint256, uint256) {
        return (50 ether, 50 ether);
    }

    function swapExactTokensForTokens(uint256 amountIn, uint256, address[] calldata, address, uint256) external pure returns (uint[] memory) {
        uint[] memory amounts = new uint[](2);
        amounts[0] = amountIn;
        amounts[1] = amountIn / 2;
        return amounts;
    }



    function getAmountsOut(uint256 amountIn, address[] calldata /*path*/)
        external
        pure
        override
        returns (uint256[] memory amounts)
    {
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountIn / 2; // Mock 2:1 price
    }
}

contract KatanaChildVaultTest is Test {
    KatanaChildVault public vault;
    MockERC20 public usdc;
    MockERC20 public weth;
    MockKatanaRouter public router;
    MockKatanaPair public mockPair;
    MockCrossChainMessenger public messenger;
    MockCCTPBridge public cctpBridge;
    MockTokenMessenger public tokenMessenger;
    MockMessageTransmitter public messageTransmitter;

    address admin = address(this);
    uint32 constant MOTHER_CHAIN_DOMAIN = 1;
    address constant MOTHER_VAULT_ADDRESS = address(0x100);
    bytes32 constant MOTHER_VAULT_SENDER = bytes32(uint256(uint160(MOTHER_VAULT_ADDRESS)));

    event Deposited(uint256 amount, uint256 sharesMinted);
    event Withdrawn(uint256 amount, uint256 sharesBurned);

    function setUp() public {
        usdc = new MockERC20("USD Coin", "USDC", 6);
        weth = new MockERC20("Wrapped Ether", "WETH", 18);
        router = new MockKatanaRouter(address(weth));
        mockPair = new MockKatanaPair("Katana LP", "KLP");
        messenger = new MockCrossChainMessenger();
        tokenMessenger = new MockTokenMessenger(address(usdc));
        messageTransmitter = new MockMessageTransmitter();
        cctpBridge = new MockCCTPBridge(
            address(usdc),
            address(tokenMessenger),
            address(messageTransmitter),
            address(messenger)
        );

        mockPair.setToken0(address(usdc));
        mockPair.setToken1(address(weth));
        mockPair.setReserves(1000e6, 500e18); // 1000 USDC, 500 WETH

        vault = new KatanaChildVault(
            address(usdc),
            address(router),
            address(mockPair),
            address(messenger),
            address(cctpBridge),
            admin
        );
        vault.setMotherVault(MOTHER_VAULT_ADDRESS, MOTHER_CHAIN_DOMAIN);
        
        usdc.mint(address(vault), 1000e6);
        mockPair.mint(address(vault), 100e18); // Seed vault with LP tokens
    }

    function test_handleDeposit() public {
        uint256 depositAmount = 100e6;
        
        // First, send USDC to the vault (simulating CCTP bridge transfer)
        usdc.mint(address(vault), depositAmount);

        bytes memory data = abi.encode(depositAmount);
        bytes memory message = abi.encode(ICrossChainMessenger.MessageType.DEPOSIT_REQUEST, data);
        
        uint256 nav = vault._calculateNav();
        uint256 totalShares = vault.totalShares();
        uint256 sharesToMint = (depositAmount * totalShares) / nav;

        vm.prank(messenger.getHyperlaneMailbox());
        vm.expectEmit();
        emit Deposited(depositAmount, sharesToMint);
        vault.handle(MOTHER_CHAIN_DOMAIN, MOTHER_VAULT_SENDER, message);
        
        assertEq(vault.totalShares(), totalShares + sharesToMint);
    }

    function test_withdraw() public {
        // Seed the vault with a deposit first
        test_handleDeposit();

        uint256 withdrawAmount = 50e6;
        uint256 nav = vault._calculateNav();
        uint256 totalShares = vault.totalShares();
        uint256 sharesToBurn = (withdrawAmount * totalShares) / nav;

        vm.prank(address(messenger));
        vm.expectEmit();
        emit Withdrawn(withdrawAmount, sharesToBurn);
        vault.withdraw(withdrawAmount);
    }
}
