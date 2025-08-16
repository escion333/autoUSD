// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ITokenMessenger} from "../interfaces/CCTP/ITokenMessenger.sol";
import {IMessageTransmitter} from "../interfaces/CCTP/IMessageTransmitter.sol";
import {IMessageReceiver} from "../interfaces/CCTP/IMessageReceiver.sol";

/**
 * @title CCTPBridge
 * @notice Handles USDC bridging via Circle's Cross-Chain Transfer Protocol
 * @dev Manages burn/mint operations and attestation verification for cross-chain USDC transfers
 */
contract CCTPBridge is IMessageReceiver, AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Roles

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant RETRIER_ROLE = keccak256("RETRIER_ROLE");

    // CCTP contracts
    ITokenMessenger public immutable tokenMessenger;
    IMessageTransmitter public immutable messageTransmitter;
    IERC20 public immutable usdc;

    // Domain mappings (chainId => CCTP domain)
    mapping(uint256 => uint32) public chainToDomain;
    mapping(uint32 => uint256) public domainToChain;

    // Supported destinations
    mapping(uint32 => bool) public supportedDomains;

    // Pending transfers tracking
    struct PendingTransfer {
        uint256 amount;
        uint32 destinationDomain;
        address recipient;
        uint256 timestamp;
        uint8 retryCount;
    }
    mapping(uint64 => PendingTransfer) public pendingTransfers;

    mapping(bytes32 => bool) public processedMessages;

    // Configuration
    uint256 public constant MAX_RETRY_COUNT = 3;
    uint256 public constant RETRY_DELAY = 1 hours;
    uint256 public minBridgeAmount = 1e6; // 1 USDC minimum
    uint256 public maxBridgeAmount = 1_000_000e6; // 1M USDC maximum

    // Events
    event BridgeInitiated(
        uint64 indexed nonce,
        uint256 amount,
        uint32 destinationDomain,
        address indexed recipient,
        address indexed sender
    );

    event BridgeRetried(
        uint64 indexed oldNonce,
        uint64 indexed newNonce,
        uint8 retryCount
    );

    event BridgeCompleted(
        bytes32 indexed messageHash,
        uint256 amount,
        uint32 sourceDomain,
        address indexed recipient
    );

    event BridgeFailed(
        uint64 indexed nonce
    );


    event DomainConfigured(
        uint256 chainId,
        uint32 domain,
        bool supported
    );

    event BridgeLimitsUpdated(
        uint256 minAmount,
        uint256 maxAmount
    );

    // Errors
    error InvalidDomain(uint32 domain);
    error AmountTooLow(uint256 amount);
    error AmountTooHigh(uint256 amount);
    error RetryDelayNotElapsed(uint256 remainingTime);
    error MaxRetriesExceeded(uint64 nonce);
    error TransferNotPending(uint64 nonce);
    error MessageAlreadyProcessed(bytes32 messageHash);
    error InvalidRecipient(address recipient);
    error InsufficientBalance(uint256 balance, uint256 required);

    constructor(
        address _tokenMessenger,
        address _messageTransmitter,
        address _usdc,
        address _admin
    ) {
        require(_tokenMessenger != address(0), "Invalid TokenMessenger");
        require(_messageTransmitter != address(0), "Invalid MessageTransmitter");
        require(_usdc != address(0), "Invalid USDC");
        require(_admin != address(0), "Invalid admin");

        tokenMessenger = ITokenMessenger(_tokenMessenger);
        messageTransmitter = IMessageTransmitter(_messageTransmitter);
        usdc = IERC20(_usdc);

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
        _grantRole(RETRIER_ROLE, _admin);

        // Initialize common domain mappings
        _configureDomain(8453, 6); // Base => CCTP domain 6
        _configureDomain(1, 0); // Ethereum => CCTP domain 0
        _configureDomain(10, 2); // Optimism => CCTP domain 2
        _configureDomain(42161, 3); // Arbitrum => CCTP domain 3
    }

    /**
     * @notice Bridge USDC to another chain
     * @param amount Amount of USDC to bridge
     * @param destinationChainId Target chain ID
     * @param recipient Recipient address on destination chain
     * @return nonce Unique identifier for this transfer
     */
    function bridgeUSDC(
        uint256 amount,
        uint256 destinationChainId,
        address recipient
    ) external nonReentrant whenNotPaused returns (uint64 nonce) {
        // Validate inputs
        if (amount < minBridgeAmount) revert AmountTooLow(amount);
        if (amount > maxBridgeAmount) revert AmountTooHigh(amount);
        if (recipient == address(0)) revert InvalidRecipient(recipient);

        uint32 destinationDomain = chainToDomain[destinationChainId];
        if (!supportedDomains[destinationDomain]) revert InvalidDomain(destinationDomain);

        // Pull USDC from the sender
        usdc.safeTransferFrom(msg.sender, address(this), amount);

        // Approve TokenMessenger to burn USDC
        usdc.safeIncreaseAllowance(address(tokenMessenger), amount);

        // Convert recipient address to bytes32 (left-padded)
        bytes32 mintRecipient = bytes32(uint256(uint160(recipient)));

        // Initiate burn and bridge
        nonce = tokenMessenger.depositForBurn(
            amount,
            destinationDomain,
            mintRecipient,
            address(usdc)
        );

        // Track pending transfer
        pendingTransfers[nonce] = PendingTransfer({
            amount: amount,
            destinationDomain: destinationDomain,
            recipient: recipient,
            timestamp: block.timestamp,
            retryCount: 0
        });

        emit BridgeInitiated(nonce, amount, destinationDomain, recipient, msg.sender);
    }

    /**
     * @notice Retry a pending bridge transfer
     * @param nonce Nonce of the transfer to retry
     */
    function retryBridge(
        uint64 nonce
    ) external nonReentrant whenNotPaused onlyRole(RETRIER_ROLE) {
        PendingTransfer storage transferToRetry = pendingTransfers[nonce];

        if (transferToRetry.timestamp == 0) revert TransferNotPending(nonce);
        if (block.timestamp < transferToRetry.timestamp + RETRY_DELAY) {
            revert RetryDelayNotElapsed(
                transferToRetry.timestamp + RETRY_DELAY - block.timestamp
            );
        }
        if (transferToRetry.retryCount >= MAX_RETRY_COUNT) {
            revert MaxRetriesExceeded(nonce);
        }

        // Increment retry count
        transferToRetry.retryCount++;

        // Re-approve and re-bridge
        usdc.safeIncreaseAllowance(address(tokenMessenger), transferToRetry.amount);
        bytes32 mintRecipient = bytes32(uint256(uint160(transferToRetry.recipient)));
        
        uint64 newNonce = tokenMessenger.depositForBurn(
            transferToRetry.amount,
            transferToRetry.destinationDomain,
            mintRecipient,
            address(usdc)
        );

        // Update pending transfer with new nonce and timestamp
        pendingTransfers[newNonce] = transferToRetry;
        pendingTransfers[newNonce].timestamp = block.timestamp;
        
        // Remove old pending transfer
        delete pendingTransfers[nonce];

        emit BridgeRetried(nonce, newNonce, transferToRetry.retryCount);
    }

    /**
     * @notice Receive USDC from another chain
     * @param message Message bytes from source chain
     * @param attestation Attestation from Circle's attestation service
     */
    function receiveUSDC(
        bytes calldata message,
        bytes calldata attestation
    ) external nonReentrant whenNotPaused {
        bytes32 messageHash = keccak256(message);
        if (processedMessages[messageHash]) revert MessageAlreadyProcessed(messageHash);

        (bool success, ) = address(messageTransmitter).call(
            abi.encodeWithSignature("receiveMessage(bytes,bytes)", message, attestation)
        );
        require(success, "Message processing failed");
        
        processedMessages[messageHash] = true;
    }

    function handleReceiveMessage(
        uint32 sourceDomain,
        bytes32, /* remoteTokenMessenger */
        bytes calldata message
    ) external nonReentrant whenNotPaused {
        require(msg.sender == address(tokenMessenger), "Only TokenMessenger");

        bytes32 messageHash = keccak256(message);
        if (processedMessages[messageHash]) revert MessageAlreadyProcessed(messageHash);
        processedMessages[messageHash] = true;

        (address recipient, uint256 amount, bytes32 sender) = _parseCCTPMessage(message);

        // Clear pending transfer if it exists
        uint64 nonce = _extractNonceFromMessage(message);
        if (pendingTransfers[nonce].timestamp != 0) {
            delete pendingTransfers[nonce];
        }

        // Transfer USDC to the intended recipient
        usdc.safeTransfer(recipient, amount);

        emit BridgeCompleted(messageHash, amount, sourceDomain, recipient);
    }
    
    function _parseCCTPMessage(
        bytes calldata message
    ) private pure returns (address recipient, uint256 amount, bytes32 sender) {
        recipient = abi.decode(message[76:108], (address));
        amount = abi.decode(message[108:140], (uint256));
        sender = abi.decode(message[44:76], (bytes32));
    }

    function _extractNonceFromMessage(bytes calldata message) private pure returns (uint64) {
        return abi.decode(message[8:16], (uint64));
    }



    /**
     * @notice Configure a domain mapping
     * @param chainId Chain ID
     * @param domain CCTP domain ID
     */
    function configureDomain(
        uint256 chainId,
        uint32 domain
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _configureDomain(chainId, domain);
    }

    /**
     * @notice Set domain support status
     * @param domain CCTP domain ID
     * @param supported Whether the domain is supported
     */
    function setSupportedDomain(
        uint32 domain,
        bool supported
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        supportedDomains[domain] = supported;
        emit DomainConfigured(domainToChain[domain], domain, supported);
    }

    /**
     * @notice Update bridge amount limits
     * @param _minAmount Minimum bridge amount
     * @param _maxAmount Maximum bridge amount
     */
    function setBridgeLimits(
        uint256 _minAmount,
        uint256 _maxAmount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_minAmount <= _maxAmount, "Invalid limits");
        minBridgeAmount = _minAmount;
        maxBridgeAmount = _maxAmount;
        emit BridgeLimitsUpdated(_minAmount, _maxAmount);
    }

    /**
     * @notice Pause bridge operations
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause bridge operations
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @notice Emergency withdraw USDC
     * @param to Recipient address
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(
        address to,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        usdc.safeTransfer(to, amount);
    }

    /**
     * @notice Get CCTP domain for a chain ID
     * @param chainId Chain ID
     * @return CCTP domain ID
     */
    function getDomain(uint256 chainId) external view returns (uint32) {
        return chainToDomain[chainId];
    }

    /**
     * @notice Check if a domain is supported
     * @param domain CCTP domain ID
     * @return Whether the domain is supported
     */
    function isDomainSupported(uint32 domain) external view returns (bool) {
        return supportedDomains[domain];
    }

    /**
     * @notice Internal function to configure domain mapping
     */
    function _configureDomain(uint256 chainId, uint32 domain) private {
        chainToDomain[chainId] = domain;
        domainToChain[domain] = chainId;
        supportedDomains[domain] = true;
        emit DomainConfigured(chainId, domain, true);
    }
}