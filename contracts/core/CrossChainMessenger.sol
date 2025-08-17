// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { ICrossChainMessenger } from "../interfaces/ICrossChainMessenger.sol";
import { IMessageRecipient } from "../interfaces/Hyperlane/IMessageRecipient.sol";
import { IMailbox } from "../interfaces/Hyperlane/IMailbox.sol";
import { IInterchainGasPaymaster } from "../interfaces/Hyperlane/IInterchainGasPaymaster.sol";
import { IMotherVault } from "../interfaces/IMotherVault.sol";
import { CCTPBridge } from "./CCTPBridge.sol";

/**
 * @title CrossChainMessenger
 * @notice Coordinates cross-chain messaging between CCTP (for USDC) and Hyperlane (for messages)
 * @dev Implements the ICrossChainMessenger interface to provide unified cross-chain operations
 * 
 * Message Flow Architecture:
 * - Base Sepolia (Mother Vault) ↔ Ethereum Sepolia (CCTP bridge) ↔ Katana Tatara (Child Vault)
 * - CCTP handles USDC transfers between Base Sepolia and Ethereum Sepolia
 * - Hyperlane handles all cross-chain messages between all chains
 * - Supports direct messaging between any configured testnet chains
 */
contract CrossChainMessenger is ICrossChainMessenger, IMessageRecipient, AccessControl, Pausable, ReentrancyGuard {
    // Roles
    bytes32 public constant MESSENGER_ROLE = keccak256("MESSENGER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant RETRIER_ROLE = keccak256("RETRIER_ROLE");

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
    mapping(bytes32 => FailedMessage) public failedMessages;
    mapping(address => bytes32[]) public userFailedMessages;
    
    // Nonce tracking for replay protection
    mapping(uint32 => mapping(bytes32 => uint256)) public domainSenderNonces; // domain => sender => nonce
    mapping(uint32 => uint256) public domainLastProcessedTimestamp; // domain => last processed timestamp

    struct MessageStatus {
        bool processed;
        bool success;
        uint256 timestamp;
        bytes returnData;
    }

    struct FailedMessage {
        bytes32 messageId;
        uint256 attempts;
        uint256 lastAttempt;
        bytes messageData;
        CrossChainMessage originalMessage;
        uint256 gasPayment;
        address sender;
        bool resolved;
    }

    // Configuration
    uint256 public constant DEFAULT_GAS_LIMIT = 500_000;
    uint256 public constant MAX_MESSAGE_SIZE = 10_000; // bytes
    uint256 public constant MESSAGE_EXPIRY = 7 days;
    uint256 public constant MAX_RETRIES = 3;
    uint256[] public retryDelays = [1 minutes, 5 minutes, 15 minutes];
    uint256 public constant RETRY_TIMEOUT = 1 hours;

    // Events
    event TrustedSenderSet(uint32 indexed domain, bytes32 indexed sender);
    event DomainConfigured(uint32 indexed chainId, uint32 domain);
    event MessageRetryScheduled(bytes32 indexed messageId, uint256 attempt, uint256 nextRetryTime);
    event MessageRetryAttempted(bytes32 indexed messageId, uint256 attempt, bool success);
    event MessageRetryFailed(bytes32 indexed messageId, uint256 totalAttempts);
    event MessageManuallyRetried(bytes32 indexed messageId, bytes32 newMessageId);

    // Additional errors
    error MessageTooLarge(uint256 size);
    error MessageExpired(uint256 expiry);
    error UntrustedDomain(uint32 domain);
    error UntrustedSender(bytes32 sender);
    error InsufficientGasPayment(uint256 required, uint256 provided);
    error MessageNotFailed(bytes32 messageId);
    error RetryDelayNotElapsed(uint256 remainingTime);
    error MaxRetriesExceeded(bytes32 messageId);
    error MessageAlreadyResolved(bytes32 messageId);

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
        _grantRole(RETRIER_ROLE, _admin);

        // Configure testnet Hyperlane domains
        _configureDomain(84532, 84532); // Base Sepolia
        _configureDomain(11155111, 11155111); // Ethereum Sepolia
        _configureDomain(129399, 747474); // Katana Tatara
    }

    /**
     * @notice Send a cross-chain message
     * @param message The message to send
     * @return messageId Unique identifier for the message
     */
    function sendCrossChainMessage(CrossChainMessage calldata message)
        external
        payable
        override
        nonReentrant
        whenNotPaused
        onlyRole(MESSENGER_ROLE)
        returns (bytes32 messageId)
    {
        // Create a memory copy for internal processing
        CrossChainMessage memory messageCopy = message;
        return _sendCrossChainMessageWithRetry(messageCopy, msg.value, msg.sender);
    }

    /**
     * @notice Internal function to send cross-chain message with retry capability
     * @param message The message to send
     * @param gasPayment Gas payment amount
     * @param sender Original sender address
     * @return messageId Unique identifier for the message
     */
    function _sendCrossChainMessageWithRetry(
        CrossChainMessage memory message,
        uint256 gasPayment,
        address sender
    )
        internal
        returns (bytes32 messageId)
    {
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
        bytes memory encodedMessage =
            abi.encode(message.messageType, message.targetVault, message.payload, message.nonce, message.timestamp);

        // Convert target address to bytes32
        bytes32 recipientAddress = bytes32(uint256(uint160(message.targetVault)));

        // Quote and check gas payment
        uint256 requiredGasPayment = gasPaymaster.quoteGasPayment(hyperlaneDomain, DEFAULT_GAS_LIMIT);
        if (gasPayment != requiredGasPayment) {
            revert InsufficientGasPayment(requiredGasPayment, gasPayment);
        }

        try hyperlaneMailbox.dispatch(hyperlaneDomain, recipientAddress, encodedMessage) returns (bytes32 _messageId) {
            messageId = _messageId;

            // Pay for gas
            try gasPaymaster.payForGas{ value: gasPayment }(messageId, hyperlaneDomain, DEFAULT_GAS_LIMIT, sender) {
                emit MessageSent(message.targetChainId, message.messageType, messageId, message.nonce);
            } catch (bytes memory reason) {
                // If gas payment fails, schedule for retry
                _scheduleMessageRetry(messageId, message, encodedMessage, gasPayment, sender, reason);
            }
        } catch (bytes memory reason) {
            // Generate a pseudo message ID for failed dispatch
            messageId = keccak256(abi.encodePacked(block.timestamp, sender, encodedMessage));
            _scheduleMessageRetry(messageId, message, encodedMessage, gasPayment, sender, reason);
        }
    }

    /**
     * @notice Schedule a failed message for retry
     * @param messageId Message identifier
     * @param message Original message
     * @param encodedMessage Encoded message data
     * @param gasPayment Gas payment amount
     * @param sender Original sender
     * @param failureReason Reason for failure
     */
    function _scheduleMessageRetry(
        bytes32 messageId,
        CrossChainMessage memory message,
        bytes memory encodedMessage,
        uint256 gasPayment,
        address sender,
        bytes memory failureReason
    )
        internal
    {
        failedMessages[messageId] = FailedMessage({
            messageId: messageId,
            attempts: 0,
            lastAttempt: block.timestamp,
            messageData: encodedMessage,
            originalMessage: message,
            gasPayment: gasPayment,
            sender: sender,
            resolved: false
        });

        userFailedMessages[sender].push(messageId);

        messageStatuses[messageId] =
            MessageStatus({ processed: false, success: false, timestamp: block.timestamp, returnData: failureReason });

        emit MessageRetryScheduled(messageId, 0, block.timestamp + retryDelays[0]);
    }

    /**
     * @notice Automatically retry a failed message
     * @param messageId Message identifier to retry
     */
    function retryFailedMessage(bytes32 messageId) external nonReentrant whenNotPaused {
        FailedMessage storage failed = failedMessages[messageId];

        if (failed.messageId == bytes32(0)) revert MessageNotFailed(messageId);
        if (failed.resolved) revert MessageAlreadyResolved(messageId);
        if (failed.attempts >= MAX_RETRIES) revert MaxRetriesExceeded(messageId);

        // Check retry delay
        uint256 retryDelay = retryDelays[failed.attempts];
        if (block.timestamp < failed.lastAttempt + retryDelay) {
            revert RetryDelayNotElapsed(failed.lastAttempt + retryDelay - block.timestamp);
        }

        failed.attempts++;
        failed.lastAttempt = block.timestamp;

        // Attempt to resend
        uint32 hyperlaneDomain = chainToHyperlaneDomain[failed.originalMessage.targetChainId];
        bytes32 recipientAddress = bytes32(uint256(uint160(failed.originalMessage.targetVault)));

        bool success = false;
        try hyperlaneMailbox.dispatch(hyperlaneDomain, recipientAddress, failed.messageData) returns (
            bytes32 newMessageId
        ) {
            // Update message ID
            failed.messageId = newMessageId;

            try gasPaymaster.payForGas{ value: failed.gasPayment }(
                newMessageId, hyperlaneDomain, DEFAULT_GAS_LIMIT, failed.sender
            ) {
                success = true;
                failed.resolved = true;

                messageStatuses[messageId].success = true;
                messageStatuses[messageId].processed = true;
                messageStatuses[messageId].timestamp = block.timestamp;

                emit MessageSent(
                    failed.originalMessage.targetChainId,
                    failed.originalMessage.messageType,
                    newMessageId,
                    failed.originalMessage.nonce
                );
            } catch {
                // Gas payment failed, will retry later
            }
        } catch {
            // Dispatch failed, will retry later
        }

        emit MessageRetryAttempted(messageId, failed.attempts, success);

        if (!success && failed.attempts >= MAX_RETRIES) {
            emit MessageRetryFailed(messageId, failed.attempts);
        } else if (!success) {
            uint256 nextRetryTime = block.timestamp
                + retryDelays[failed.attempts < retryDelays.length ? failed.attempts : retryDelays.length - 1];
            emit MessageRetryScheduled(messageId, failed.attempts, nextRetryTime);
        }
    }

    /**
     * @notice Manually retry a failed message (admin only)
     * @param messageId Message identifier to retry
     */
    function manualRetryMessage(bytes32 messageId)
        external
        payable
        nonReentrant
        whenNotPaused
        onlyRole(RETRIER_ROLE)
        returns (bytes32 newMessageId)
    {
        FailedMessage storage failed = failedMessages[messageId];

        if (failed.messageId == bytes32(0)) revert MessageNotFailed(messageId);
        if (failed.resolved) revert MessageAlreadyResolved(messageId);

        // Mark as resolved regardless of outcome
        failed.resolved = true;

        // Create a memory copy of the original message for calldata
        CrossChainMessage memory messageCopy = failed.originalMessage;

        // Attempt manual retry with potentially updated gas payment
        newMessageId = _sendCrossChainMessageWithRetry(messageCopy, msg.value, failed.sender);

        messageStatuses[messageId].success = true;
        messageStatuses[messageId].processed = true;
        messageStatuses[messageId].timestamp = block.timestamp;

        emit MessageManuallyRetried(messageId, newMessageId);
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
    )
        external
        payable
        override (ICrossChainMessenger, IMessageRecipient)
        nonReentrant
    {
        require(msg.sender == address(hyperlaneMailbox), "Only mailbox");

        // Verify trusted sender and domain
        if (!trustedDomains[_origin]) {
            revert UntrustedDomain(_origin);
        }
        if (trustedSenders[_origin] != _sender) revert UntrustedSender(_sender);

        // Calculate message ID with enhanced domain separation to prevent replay attacks
        // Include chain ID, block number, and timestamp for unique identification
        bytes32 messageId = keccak256(abi.encodePacked(
            block.chainid,
            _origin,
            _sender,
            _message,
            block.timestamp,
            block.number,
            address(this)
        ));

        // Decode message to verify recipient before further processing
        (MessageType messageType, address targetVault, bytes memory payload, uint256 nonce, uint256 messageTimestamp) =
            abi.decode(_message, (MessageType, address, bytes, uint256, uint256));

        // Authenticate that this message is intended for this MotherVault
        require(targetVault == motherVault, "Recipient mismatch");

        // Check if already processed
        if (processedMessages[messageId]) {
            revert MessageAlreadyProcessed(messageId);
        }
        
        // SECURITY FIX: Validate timestamp FIRST before any state updates
        // Prevent future timestamps and ensure message is not stale
        require(messageTimestamp <= block.timestamp, "Message timestamp in future");
        require(messageTimestamp + MESSAGE_EXPIRY > block.timestamp, "Message expired");
        
        // Validate timestamp ordering (messages must be processed in order)
        require(messageTimestamp > domainLastProcessedTimestamp[_origin], "Timestamp out of order");

        // Validate nonce for replay protection
        // Fix: For the first message, nonce should be 1, subsequent messages should increment
        uint256 currentNonce = domainSenderNonces[_origin][_sender];
        uint256 expectedNonce = currentNonce + 1;
        require(nonce == expectedNonce, "Invalid nonce sequence");

        // All validations passed - now safe to update state
        processedMessages[messageId] = true;
        domainSenderNonces[_origin][_sender] = nonce;
        domainLastProcessedTimestamp[_origin] = messageTimestamp;

        emit MessageReceived(_origin, messageType, messageId, nonce);

        // Route the decoded message parts to the MotherVault for processing
        bool success;
        bytes memory returnData;

        try IMotherVault(motherVault).handleIncomingMessage(_origin, _sender, abi.encode(messageType, payload)) {
            success = true;
            // No return data expected, so this block is empty
        } catch Error(string memory reason) {
            success = false;
            returnData = bytes(reason);
        } catch (bytes memory lowLevelData) {
            success = false;
            returnData = lowLevelData;
        }

        // Update status
        messageStatuses[messageId] =
            MessageStatus({ processed: true, success: success, timestamp: block.timestamp, returnData: returnData });

        emit MessageProcessed(messageId, success, returnData);
    }

    /**
     * @notice Get failed message details
     * @param messageId Message identifier
     * @return FailedMessage struct with details
     */
    function getFailedMessage(bytes32 messageId) external view returns (FailedMessage memory) {
        return failedMessages[messageId];
    }

    /**
     * @notice Get all failed messages for a user
     * @param user User address
     * @return Array of message IDs
     */
    function getUserFailedMessages(address user) external view returns (bytes32[] memory) {
        return userFailedMessages[user];
    }

    /**
     * @notice Check if a message can be retried
     * @param messageId Message identifier
     * @return canRetry Whether the message can be retried
     * @return timeUntilRetry Time until next retry is allowed
     */
    function canRetryMessage(bytes32 messageId) external view returns (bool canRetry, uint256 timeUntilRetry) {
        FailedMessage memory failed = failedMessages[messageId];

        if (failed.messageId == bytes32(0) || failed.resolved || failed.attempts >= MAX_RETRIES) {
            return (false, 0);
        }

        uint256 retryDelay = retryDelays[failed.attempts];
        uint256 nextRetryTime = failed.lastAttempt + retryDelay;

        if (block.timestamp >= nextRetryTime) {
            return (true, 0);
        } else {
            return (false, nextRetryTime - block.timestamp);
        }
    }

    /**
     * @notice Get retry configuration
     * @return delays Array of retry delays
     * @return maxRetries Maximum number of retries
     */
    function getRetryConfiguration() external view returns (uint256[] memory delays, uint256 maxRetries) {
        return (retryDelays, MAX_RETRIES);
    }

    /**
     * @notice Configure a Hyperlane domain mapping
     * @param chainId Chain ID
     * @param domain Hyperlane domain ID
     */
    function configureDomain(uint256 chainId, uint32 domain) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _configureDomain(chainId, domain);
    }

    /**
     * @notice Set a trusted sender for a domain
     * @param domain Hyperlane domain
     * @param sender Trusted sender address (bytes32)
     */
    function setTrustedSender(uint32 domain, bytes32 sender) external onlyRole(DEFAULT_ADMIN_ROLE) {
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
    function getMessageStatus(bytes32 messageId) external view override returns (bool processed, bool success) {
        MessageStatus memory status = messageStatuses[messageId];
        return (status.processed, status.success);
    }

    /**
     * @notice Estimate message fee
     * @param targetChainId Target chain ID
     * @return Estimated fee in wei
     */
    function estimateMessageFee(uint32 targetChainId) external view override returns (uint256) {
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

    function _configureDomain(uint256 chainId, uint32 domain) private {
        chainToHyperlaneDomain[chainId] = domain;
        hyperlaneDomainToChain[domain] = chainId;
        emit DomainConfigured(uint32(chainId), domain);
    }
}
