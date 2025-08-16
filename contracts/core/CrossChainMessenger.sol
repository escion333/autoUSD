// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ICrossChainMessenger} from "../interfaces/ICrossChainMessenger.sol";
import {IMessageRecipient} from "../interfaces/Hyperlane/IMessageRecipient.sol";
import {IMailbox} from "../interfaces/Hyperlane/IMailbox.sol";
import {IInterchainGasPaymaster} from "../interfaces/Hyperlane/IInterchainGasPaymaster.sol";
import {CCTPBridge} from "./CCTPBridge.sol";

/**
 * @title CrossChainMessenger
 * @notice Coordinates cross-chain messaging between CCTP (for USDC) and Hyperlane (for messages)
 * @dev Implements the ICrossChainMessenger interface to provide unified cross-chain operations
 */
contract CrossChainMessenger is 
    ICrossChainMessenger, 
    IMessageRecipient,
    AccessControl, 
    Pausable, 
    ReentrancyGuard 
{
    // Roles
    bytes32 public constant MESSENGER_ROLE = keccak256("MESSENGER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // Core contracts
    IMailbox public immutable hyperlaneMailbox;
    IInterchainGasPaymaster public immutable gasPaymaster;
    CCTPBridge public immutable cctpBridge;
    address public immutable motherVault;

    // Chain configurations
    mapping(uint256 => uint32) public chainToHyperlaneDomain;
    mapping(uint32 => uint256) public hyperlaneDomainToChain;
    mapping(uint32 => bool) public trustedDomains;
    mapping(uint32 => bytes32) public trustedSenders; // domain => sender address

    // Message tracking
    mapping(bytes32 => bool) public processedMessages;
    mapping(bytes32 => MessageStatus) public messageStatuses;
    uint256 public messageNonce;

    struct MessageStatus {
        bool processed;
        bool success;
        uint256 timestamp;
        bytes returnData;
    }

    // Configuration
    uint256 public constant DEFAULT_GAS_LIMIT = 500_000;
    uint256 public constant MAX_MESSAGE_SIZE = 10_000; // bytes
    uint256 public constant MESSAGE_EXPIRY = 7 days;

    // Retry mechanism
    mapping(bytes32 => uint8) public messageRetryCount;
    uint256 public constant MAX_RETRIES = 3;
    uint256 public constant RETRY_DELAY = 1 hours;

    // Events
    event TrustedSenderSet(uint32 indexed domain, bytes32 indexed sender);
    event DomainConfigured(uint256 indexed chainId, uint32 indexed domain);
    event MessageRetried(bytes32 indexed messageId, uint8 retryCount);
    
    // Additional errors
    error MessageTooLarge(uint256 size);
    error MessageExpired(uint256 expiry);
    error UntrustedDomain(uint32 domain);
    error UntrustedSender(bytes32 sender);
    error InsufficientGasPayment(uint256 required, uint256 provided);

    constructor(
        address _hyperlaneMailbox,
        address _gasPaymaster,
        address _cctpBridge,
        address _motherVault,
        address _admin
    ) {
        require(_hyperlaneMailbox != address(0), "Invalid mailbox");
        require(_gasPaymaster != address(0), "Invalid gas paymaster");
        require(_cctpBridge != address(0), "Invalid CCTP bridge");
        require(_motherVault != address(0), "Invalid mother vault");
        require(_admin != address(0), "Invalid admin");

        hyperlaneMailbox = IMailbox(_hyperlaneMailbox);
        gasPaymaster = IInterchainGasPaymaster(_gasPaymaster);
        cctpBridge = CCTPBridge(_cctpBridge);
        motherVault = _motherVault;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(MESSENGER_ROLE, _admin);
        _grantRole(MESSENGER_ROLE, _motherVault);
        _grantRole(PAUSER_ROLE, _admin);

        // Configure common Hyperlane domains
        _configureDomain(8453, 8453); // Base
        _configureDomain(1, 1); // Ethereum
        _configureDomain(10, 10); // Optimism
        _configureDomain(42161, 42161); // Arbitrum
    }

    /**
     * @notice Send a cross-chain message
     * @param message The message to send
     * @return messageId Unique identifier for the message
     */
    function sendCrossChainMessage(
        CrossChainMessage calldata message
    ) external payable override nonReentrant whenNotPaused onlyRole(MESSENGER_ROLE) returns (bytes32 messageId) {
        // Validate message
        if (message.payload.length > MAX_MESSAGE_SIZE) {
            revert MessageTooLarge(message.payload.length);
        }
        if (!trustedDomains[message.targetChainId]) {
            revert UntrustedDomain(message.targetChainId);
        }

        // Get Hyperlane domain
        uint32 hyperlaneDomain = chainToHyperlaneDomain[message.targetChainId];
        require(hyperlaneDomain != 0, "Unknown chain");

        // Encode the full message
        bytes memory encodedMessage = abi.encode(
            message.messageType,
            message.targetVault,
            message.payload,
            message.nonce,
            message.timestamp
        );

        // Convert target address to bytes32
        bytes32 recipientAddress = bytes32(uint256(uint160(message.targetVault)));

        // Quote gas payment
        uint256 gasPayment = gasPaymaster.quoteGasPayment(hyperlaneDomain, DEFAULT_GAS_LIMIT);

        if (msg.value < gasPayment) {
            revert InsufficientGasPayment(gasPayment, msg.value);
        }

        // Dispatch message via Hyperlane
        messageId = hyperlaneMailbox.dispatch(
            hyperlaneDomain,
            recipientAddress,
            encodedMessage
        );

        // Pay for gas
        if (gasPayment > 0) {
            gasPaymaster.payForGas{value: gasPayment}(
                messageId,
                hyperlaneDomain,
                DEFAULT_GAS_LIMIT,
                msg.sender
            );
        }

        // Track message
        messageNonce++;
        
        emit MessageSent(message.targetChainId, message.messageType, messageId, message.nonce);

        // Refund excess gas payment
        if (msg.value > gasPayment) {
            (bool refundSuccess, ) = msg.sender.call{value: msg.value - gasPayment}("");
            require(refundSuccess, "Refund failed");
        }
    }

    /**
     * @notice Handle incoming message from Hyperlane
     * @param _origin Origin domain
     * @param _sender Sender address on origin chain
     * @param _message Message body
     */
    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes calldata _message
    ) external payable override(ICrossChainMessenger, IMessageRecipient) nonReentrant {
        // Only Hyperlane mailbox can call this
        require(msg.sender == address(hyperlaneMailbox), "Only mailbox");

        // Verify trusted sender
        if (!trustedDomains[_origin]) {
            revert UntrustedDomain(_origin);
        }
        if (trustedSenders[_origin] != _sender && trustedSenders[_origin] != bytes32(0)) {
            revert UntrustedSender(_sender);
        }

        // Calculate message ID
        bytes32 messageId = keccak256(abi.encodePacked(_origin, _sender, _message));
        
        // Check if already processed
        if (processedMessages[messageId]) {
            revert MessageAlreadyProcessed(messageId);
        }

        // Mark as processed
        processedMessages[messageId] = true;

        // Decode message
        (
            MessageType messageType,
            address targetVault,
            bytes memory payload,
            uint256 nonce,
            uint256 timestamp
        ) = abi.decode(_message, (MessageType, address, bytes, uint256, uint256));

        // Check message expiry
        if (block.timestamp > timestamp + MESSAGE_EXPIRY) {
            revert MessageExpired(timestamp + MESSAGE_EXPIRY);
        }

        emit MessageReceived(_origin, messageType, messageId, nonce);

        // Process based on message type
        bool success;
        bytes memory returnData;
        
        try this.processMessage(messageType, targetVault, payload) returns (bytes memory data) {
            success = true;
            returnData = data;
        } catch Error(string memory reason) {
            success = false;
            returnData = bytes(reason);
        } catch (bytes memory lowLevelData) {
            success = false;
            returnData = lowLevelData;
        }

        // Update status
        messageStatuses[messageId] = MessageStatus({
            processed: true,
            success: success,
            timestamp: block.timestamp,
            returnData: returnData
        });

        emit MessageProcessed(messageId, success, returnData);
    }

    /**
     * @notice Process a message based on its type
     * @param messageType Type of message
     * @param targetVault Target vault address
     * @param payload Message payload
     */
    function processMessage(
        MessageType messageType,
        address targetVault,
        bytes calldata payload
    ) external returns (bytes memory) {
        require(msg.sender == address(this), "Only self");

        // Route to appropriate handler
        if (messageType == MessageType.DEPOSIT_REQUEST) {
            return _handleDepositRequest(targetVault, payload);
        } else if (messageType == MessageType.WITHDRAWAL_REQUEST) {
            return _handleWithdrawalRequest(targetVault, payload);
        } else if (messageType == MessageType.YIELD_REPORT) {
            return _handleYieldReport(targetVault, payload);
        } else if (messageType == MessageType.REBALANCE_COMMAND) {
            return _handleRebalanceCommand(targetVault, payload);
        } else if (messageType == MessageType.EMERGENCY_PAUSE) {
            return _handleEmergencyPause(targetVault);
        } else if (messageType == MessageType.EMERGENCY_UNPAUSE) {
            return _handleEmergencyUnpause(targetVault);
        } else if (messageType == MessageType.EMERGENCY_WITHDRAW_ALL) {
            return _handleEmergencyWithdrawAll(targetVault, payload);
        } else {
            revert InvalidMessageType(uint8(messageType));
        }
    }

    /**
     * @notice Configure a Hyperlane domain mapping
     * @param chainId Chain ID
     * @param domain Hyperlane domain ID
     */
    function configureDomain(
        uint256 chainId,
        uint32 domain
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _configureDomain(chainId, domain);
    }

    /**
     * @notice Set a trusted sender for a domain
     * @param domain Hyperlane domain
     * @param sender Trusted sender address (bytes32)
     */
    function setTrustedSender(
        uint32 domain,
        bytes32 sender
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        trustedSenders[domain] = sender;
        trustedDomains[domain] = true;
        emit TrustedSenderSet(domain, sender);
    }

    /**
     * @notice Get message status
     * @param messageId Message identifier
     * @return processed Whether processed
     * @return success Whether successful
     */
    function getMessageStatus(
        bytes32 messageId
    ) external view override returns (bool processed, bool success) {
        MessageStatus memory status = messageStatuses[messageId];
        return (status.processed, status.success);
    }

    /**
     * @notice Estimate message fee
     * @param targetChainId Target chain ID
     * @param message Message body
     * @return Estimated fee in wei
     */
    function estimateMessageFee(
        uint32 targetChainId,
        bytes calldata message
    ) external view override returns (uint256) {
        uint32 domain = chainToHyperlaneDomain[targetChainId];
        if (domain == 0) return 0;
        
        return gasPaymaster.quoteGasPayment(domain, DEFAULT_GAS_LIMIT);
    }

    /**
     * @notice Get Hyperlane mailbox address
     */
    function getHyperlaneMailbox() external view override returns (address) {
        return address(hyperlaneMailbox);
    }

    /**
     * @notice Get CCTP TokenMessenger address
     */
    function getCCTPTokenMessenger() external view override returns (address) {
        return address(cctpBridge.tokenMessenger());
    }

    /**
     * @notice Get Interchain Gas Paymaster address
     */
    function getInterchainGasPaymaster() external view override returns (address) {
        return address(gasPaymaster);
    }

    /**
     * @notice Pause operations
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause operations
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // Internal handler functions
    function _handleDepositRequest(address targetVault, bytes calldata payload) private returns (bytes memory) {
        // Forward to mother vault
        (bool success, bytes memory data) = motherVault.call(
            abi.encodeWithSignature("handleDepositFromChild(address,bytes)", targetVault, payload)
        );
        require(success, "Deposit handling failed");
        return data;
    }

    function _handleWithdrawalRequest(address targetVault, bytes calldata payload) private returns (bytes memory) {
        // Forward to mother vault
        (bool success, bytes memory data) = motherVault.call(
            abi.encodeWithSignature("handleWithdrawalToChild(address,bytes)", targetVault, payload)
        );
        require(success, "Withdrawal handling failed");
        return data;
    }

    function _handleYieldReport(address targetVault, bytes calldata payload) private returns (bytes memory) {
        // Forward to mother vault
        (bool success, bytes memory data) = motherVault.call(
            abi.encodeWithSignature("handleYieldReport(address,bytes)", targetVault, payload)
        );
        require(success, "Yield report handling failed");
        return data;
    }

    function _handleRebalanceCommand(address targetVault, bytes calldata payload) private returns (bytes memory) {
        // Forward to mother vault
        (bool success, bytes memory data) = motherVault.call(
            abi.encodeWithSignature("handleRebalanceCommand(address,bytes)", targetVault, payload)
        );
        require(success, "Rebalance command failed");
        return data;
    }

    function _handleEmergencyPause(address targetVault) private returns (bytes memory) {
        // Forward to mother vault
        (bool success, bytes memory data) = motherVault.call(
            abi.encodeWithSignature("handleEmergencyPause(address)", targetVault)
        );
        require(success, "Emergency pause failed");
        return data;
    }

    function _handleEmergencyUnpause(address targetVault) private returns (bytes memory) {
        // Forward to mother vault
        (bool success, bytes memory data) = motherVault.call(
            abi.encodeWithSignature("handleEmergencyUnpause(address)", targetVault)
        );
        require(success, "Emergency unpause failed");
        return data;
    }

    function _handleEmergencyWithdrawAll(address targetVault, bytes calldata payload) private returns (bytes memory) {
        // Forward to mother vault
        (bool success, bytes memory data) = motherVault.call(
            abi.encodeWithSignature("handleEmergencyWithdrawAll(address,bytes)", targetVault, payload)
        );
        require(success, "Emergency withdrawal failed");
        return data;
    }

    function _configureDomain(uint256 chainId, uint32 domain) private {
        chainToHyperlaneDomain[chainId] = domain;
        hyperlaneDomainToChain[domain] = chainId;
        emit DomainConfigured(chainId, domain);
    }
}