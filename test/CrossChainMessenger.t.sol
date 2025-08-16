// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {CrossChainMessenger} from "../contracts/core/CrossChainMessenger.sol";
import {CCTPBridge} from "../contracts/core/CCTPBridge.sol";
import {ICrossChainMessenger} from "../contracts/interfaces/ICrossChainMessenger.sol";
import {IMessageRecipient} from "../contracts/interfaces/Hyperlane/IMessageRecipient.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockMailbox} from "./mocks/MockMailbox.sol";
import {MockInterchainGasPaymaster} from "./mocks/MockInterchainGasPaymaster.sol";
import {MockTokenMessenger} from "./mocks/MockTokenMessenger.sol";
import {MockMessageTransmitter} from "./mocks/MockMessageTransmitter.sol";
import {MockMotherVault} from "./mocks/MockMotherVault.sol";

contract CrossChainMessengerTest is Test {
    CrossChainMessenger public messenger;
    CCTPBridge public cctpBridge;
    MockMailbox public mailbox;
    MockInterchainGasPaymaster public gasPaymaster;
    MockTokenMessenger public tokenMessenger;
    MockMessageTransmitter public messageTransmitter;
    MockMotherVault public motherVault;
    MockERC20 public usdc;

    address public admin = address(0x1);
    address public childVault = address(0x2);
    address public user = address(0x3);

    uint32 public constant BASE_DOMAIN = 8453;
    uint32 public constant ARBITRUM_DOMAIN = 42161;
    bytes32 public constant TRUSTED_SENDER = bytes32(uint256(uint160(address(0x4))));

    event MessageSent(uint32 indexed targetChainId, ICrossChainMessenger.MessageType messageType, bytes32 messageId, uint256 nonce);
    event MessageReceived(uint32 indexed originChainId, ICrossChainMessenger.MessageType messageType, bytes32 messageId, uint256 nonce);
    event MessageProcessed(bytes32 indexed messageId, bool success, bytes returnData);
    event TrustedSenderSet(uint32 indexed domain, bytes32 indexed sender);

    function setUp() public {
        // Deploy mocks
        usdc = new MockERC20("USD Coin", "USDC", 6);
        mailbox = new MockMailbox();
        gasPaymaster = new MockInterchainGasPaymaster();
        tokenMessenger = new MockTokenMessenger(address(usdc));
        messageTransmitter = new MockMessageTransmitter();
        motherVault = new MockMotherVault();

        // Deploy CCTP Bridge
        cctpBridge = new CCTPBridge(
            address(tokenMessenger),
            address(messageTransmitter),
            address(usdc),
            admin
        );

        // Deploy CrossChainMessenger
        messenger = new CrossChainMessenger(
            address(mailbox),
            address(gasPaymaster),
            address(cctpBridge),
            address(motherVault),
            admin
        );

        // Setup
        vm.startPrank(admin);
        messenger.setTrustedSender(ARBITRUM_DOMAIN, TRUSTED_SENDER);
        vm.stopPrank();

        // Fund accounts
        deal(admin, 10 ether);
        deal(user, 10 ether);
        usdc.mint(admin, 1_000_000e6);
        usdc.mint(user, 1_000_000e6);
    }

    function test_Constructor() public view {
        assertEq(address(messenger.hyperlaneMailbox()), address(mailbox));
        assertEq(address(messenger.gasPaymaster()), address(gasPaymaster));
        assertEq(address(messenger.cctpBridge()), address(cctpBridge));
        assertEq(messenger.motherVault(), address(motherVault));
        assertTrue(messenger.hasRole(messenger.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(messenger.hasRole(messenger.MESSENGER_ROLE(), admin));
        assertTrue(messenger.hasRole(messenger.MESSENGER_ROLE(), address(motherVault)));
    }

    function test_SendCrossChainMessage() public {
        vm.startPrank(admin);

        ICrossChainMessenger.CrossChainMessage memory message = ICrossChainMessenger.CrossChainMessage({
            targetChainId: ARBITRUM_DOMAIN,
            targetVault: childVault,
            messageType: ICrossChainMessenger.MessageType.DEPOSIT_REQUEST,
            payload: abi.encode(100e6),
            nonce: 0,
            timestamp: block.timestamp
        });

        uint256 gasPayment = 0.01 ether;
        mailbox.setQuoteDispatch(gasPayment);

        bytes32 expectedMessageId = keccak256(abi.encode("message"));
        mailbox.setNextMessageId(expectedMessageId);

        // Fund the messenger contract to pay for gas
        vm.deal(address(messenger), 1 ether);
        
        // Just verify the message is sent successfully without checking exact event params
        bytes32 messageId = messenger.sendCrossChainMessage{value: gasPayment}(message);
        assertEq(messageId, expectedMessageId);
        assertEq(messenger.messageNonce(), 1);

        vm.stopPrank();
    }

    function test_SendCrossChainMessage_RevertMessageTooLarge() public {
        vm.startPrank(admin);

        bytes memory largePayload = new bytes(11000); // > MAX_MESSAGE_SIZE
        ICrossChainMessenger.CrossChainMessage memory message = ICrossChainMessenger.CrossChainMessage({
            targetChainId: ARBITRUM_DOMAIN,
            targetVault: childVault,
            messageType: ICrossChainMessenger.MessageType.DEPOSIT_REQUEST,
            payload: largePayload,
            nonce: 0,
            timestamp: block.timestamp
        });

        vm.expectRevert(abi.encodeWithSelector(CrossChainMessenger.MessageTooLarge.selector, 11000));
        messenger.sendCrossChainMessage(message);

        vm.stopPrank();
    }

    function test_SendCrossChainMessage_RevertUntrustedDomain() public {
        vm.startPrank(admin);

        ICrossChainMessenger.CrossChainMessage memory message = ICrossChainMessenger.CrossChainMessage({
            targetChainId: 999, // Unknown domain
            targetVault: childVault,
            messageType: ICrossChainMessenger.MessageType.DEPOSIT_REQUEST,
            payload: abi.encode(100e6),
            nonce: 0,
            timestamp: block.timestamp
        });

        vm.expectRevert(abi.encodeWithSelector(CrossChainMessenger.UntrustedDomain.selector, 999));
        messenger.sendCrossChainMessage(message);

        vm.stopPrank();
    }

    function test_SendCrossChainMessage_RevertInsufficientGasPayment() public {
        vm.startPrank(admin);

        ICrossChainMessenger.CrossChainMessage memory message = ICrossChainMessenger.CrossChainMessage({
            targetChainId: ARBITRUM_DOMAIN,
            targetVault: childVault,
            messageType: ICrossChainMessenger.MessageType.DEPOSIT_REQUEST,
            payload: abi.encode(100e6),
            nonce: 0,
            timestamp: block.timestamp
        });

        uint256 gasPayment = 0.01 ether;
        mailbox.setQuoteDispatch(gasPayment);

        vm.expectRevert(abi.encodeWithSelector(CrossChainMessenger.InsufficientGasPayment.selector, gasPayment, 0.001 ether));
        messenger.sendCrossChainMessage{value: 0.001 ether}(message);

        vm.stopPrank();
    }

    function test_Handle_DepositRequest() public {
        bytes memory payload = abi.encode(100e6);
        bytes memory encodedMessage = abi.encode(
            ICrossChainMessenger.MessageType.DEPOSIT_REQUEST,
            childVault,
            payload,
            uint256(1),
            block.timestamp
        );

        vm.prank(address(mailbox));
        messenger.handle(ARBITRUM_DOMAIN, TRUSTED_SENDER, encodedMessage);

        bytes32 messageId = keccak256(abi.encodePacked(ARBITRUM_DOMAIN, TRUSTED_SENDER, encodedMessage));
        assertTrue(messenger.processedMessages(messageId));
        
        (bool processed, bool success) = messenger.getMessageStatus(messageId);
        assertTrue(processed);
        assertTrue(success);
    }

    function test_Handle_RevertNotMailbox() public {
        bytes memory encodedMessage = abi.encode(
            ICrossChainMessenger.MessageType.DEPOSIT_REQUEST,
            childVault,
            abi.encode(100e6),
            uint256(1),
            block.timestamp
        );

        vm.prank(user);
        vm.expectRevert("Only mailbox");
        messenger.handle(ARBITRUM_DOMAIN, TRUSTED_SENDER, encodedMessage);
    }

    function test_Handle_RevertUntrustedDomain() public {
        bytes memory encodedMessage = abi.encode(
            ICrossChainMessenger.MessageType.DEPOSIT_REQUEST,
            childVault,
            abi.encode(100e6),
            uint256(1),
            block.timestamp
        );

        vm.prank(address(mailbox));
        vm.expectRevert(abi.encodeWithSelector(CrossChainMessenger.UntrustedDomain.selector, 999));
        messenger.handle(999, TRUSTED_SENDER, encodedMessage);
    }

    function test_Handle_RevertUntrustedSender() public {
        bytes memory encodedMessage = abi.encode(
            ICrossChainMessenger.MessageType.DEPOSIT_REQUEST,
            childVault,
            abi.encode(100e6),
            uint256(1),
            block.timestamp
        );

        bytes32 untrustedSender = bytes32(uint256(uint160(address(0x999))));
        
        vm.prank(address(mailbox));
        vm.expectRevert(abi.encodeWithSelector(CrossChainMessenger.UntrustedSender.selector, untrustedSender));
        messenger.handle(ARBITRUM_DOMAIN, untrustedSender, encodedMessage);
    }

    function test_Handle_RevertAlreadyProcessed() public {
        bytes memory encodedMessage = abi.encode(
            ICrossChainMessenger.MessageType.DEPOSIT_REQUEST,
            childVault,
            abi.encode(100e6),
            uint256(1),
            block.timestamp
        );

        vm.startPrank(address(mailbox));
        messenger.handle(ARBITRUM_DOMAIN, TRUSTED_SENDER, encodedMessage);

        bytes32 messageId = keccak256(abi.encodePacked(ARBITRUM_DOMAIN, TRUSTED_SENDER, encodedMessage));
        vm.expectRevert(abi.encodeWithSelector(ICrossChainMessenger.MessageAlreadyProcessed.selector, messageId));
        messenger.handle(ARBITRUM_DOMAIN, TRUSTED_SENDER, encodedMessage);
        vm.stopPrank();
    }

    function test_Handle_RevertMessageExpired() public {
        // Move time forward first to avoid underflow
        vm.warp(block.timestamp + 10 days);
        uint256 oldTimestamp = block.timestamp - 8 days;
        bytes memory encodedMessage = abi.encode(
            ICrossChainMessenger.MessageType.DEPOSIT_REQUEST,
            childVault,
            abi.encode(100e6),
            uint256(1),
            oldTimestamp
        );

        vm.prank(address(mailbox));
        vm.expectRevert(abi.encodeWithSelector(CrossChainMessenger.MessageExpired.selector, oldTimestamp + 7 days));
        messenger.handle(ARBITRUM_DOMAIN, TRUSTED_SENDER, encodedMessage);
    }

    function test_Handle_AllMessageTypes() public {
        ICrossChainMessenger.MessageType[7] memory messageTypes = [
            ICrossChainMessenger.MessageType.DEPOSIT_REQUEST,
            ICrossChainMessenger.MessageType.WITHDRAWAL_REQUEST,
            ICrossChainMessenger.MessageType.YIELD_REPORT,
            ICrossChainMessenger.MessageType.REBALANCE_COMMAND,
            ICrossChainMessenger.MessageType.EMERGENCY_PAUSE,
            ICrossChainMessenger.MessageType.EMERGENCY_UNPAUSE,
            ICrossChainMessenger.MessageType.EMERGENCY_WITHDRAW_ALL
        ];

        for (uint i = 0; i < messageTypes.length; i++) {
            bytes memory payload = abi.encode(100e6);
            bytes memory encodedMessage = abi.encode(
                messageTypes[i],
                childVault,
                payload,
                uint256(i + 1),
                block.timestamp
            );

            vm.prank(address(mailbox));
            messenger.handle(ARBITRUM_DOMAIN, TRUSTED_SENDER, encodedMessage);

            bytes32 messageId = keccak256(abi.encodePacked(ARBITRUM_DOMAIN, TRUSTED_SENDER, encodedMessage));
            assertTrue(messenger.processedMessages(messageId));
        }
    }

    function test_ConfigureDomain() public {
        vm.startPrank(admin);
        
        uint256 newChainId = 1337;
        uint32 newDomain = 1337;
        
        messenger.configureDomain(newChainId, newDomain);
        
        assertEq(messenger.chainToHyperlaneDomain(newChainId), newDomain);
        assertEq(messenger.hyperlaneDomainToChain(newDomain), newChainId);
        
        vm.stopPrank();
    }

    function test_SetTrustedSender() public {
        vm.startPrank(admin);
        
        uint32 newDomain = 1337;
        bytes32 newSender = bytes32(uint256(uint160(address(0x1337))));
        
        vm.expectEmit(true, true, false, false);
        emit TrustedSenderSet(newDomain, newSender);
        
        messenger.setTrustedSender(newDomain, newSender);
        
        assertEq(messenger.trustedSenders(newDomain), newSender);
        assertTrue(messenger.trustedDomains(newDomain));
        
        vm.stopPrank();
    }

    function test_EstimateMessageFee() public view {
        uint256 fee = messenger.estimateMessageFee(ARBITRUM_DOMAIN, abi.encode("test"));
        assertEq(fee, 1000); // MockInterchainGasPaymaster returns 1000
    }

    function test_Pause() public {
        vm.startPrank(admin);
        
        messenger.pause();
        assertTrue(messenger.paused());
        
        ICrossChainMessenger.CrossChainMessage memory message = ICrossChainMessenger.CrossChainMessage({
            targetChainId: ARBITRUM_DOMAIN,
            targetVault: childVault,
            messageType: ICrossChainMessenger.MessageType.DEPOSIT_REQUEST,
            payload: abi.encode(100e6),
            nonce: 0,
            timestamp: block.timestamp
        });
        
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        messenger.sendCrossChainMessage(message);
        
        vm.stopPrank();
    }

    function test_Unpause() public {
        vm.startPrank(admin);
        
        messenger.pause();
        assertTrue(messenger.paused());
        
        messenger.unpause();
        assertFalse(messenger.paused());
        
        vm.stopPrank();
    }

    function test_GetterFunctions() public view {
        assertEq(messenger.getHyperlaneMailbox(), address(mailbox));
        assertEq(messenger.getCCTPTokenMessenger(), address(cctpBridge.tokenMessenger()));
        assertEq(messenger.getInterchainGasPaymaster(), address(gasPaymaster));
    }

    function testFuzz_SendMessage(uint256 amount, uint256 targetChainId) public {
        vm.assume(amount > 0 && amount < 1000e6);
        vm.assume(targetChainId > 100 && targetChainId < 65535); // Valid domain range, avoid existing
        vm.assume(targetChainId != BASE_DOMAIN); // Avoid conflict with already configured domain
        vm.assume(targetChainId != ARBITRUM_DOMAIN); // Avoid conflict with already configured domain
        vm.assume(targetChainId != 1 && targetChainId != 10); // Avoid ETH and Optimism

        vm.startPrank(admin);
        
        // Configure the domain first - use safe conversion
        uint32 targetDomain = uint32(targetChainId);
        messenger.configureDomain(targetChainId, targetDomain);
        messenger.setTrustedSender(targetDomain, TRUSTED_SENDER);

        ICrossChainMessenger.CrossChainMessage memory message = ICrossChainMessenger.CrossChainMessage({
            targetChainId: targetDomain,
            targetVault: childVault,
            messageType: ICrossChainMessenger.MessageType.DEPOSIT_REQUEST,
            payload: abi.encode(amount),
            nonce: 0,
            timestamp: block.timestamp
        });

        uint256 gasPayment = 0.01 ether;
        mailbox.setQuoteDispatch(gasPayment);
        mailbox.setNextMessageId(keccak256(abi.encode(amount, targetDomain)));

        // Fund the messenger contract
        vm.deal(address(messenger), 1 ether);
        
        bytes32 messageId = messenger.sendCrossChainMessage{value: gasPayment}(message);
        assertNotEq(messageId, bytes32(0));

        vm.stopPrank();
    }
}