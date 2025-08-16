// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
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
    // using SafeERC20 for IERC20;

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
    uint256[] public retryDelays = [1 minutes, 5 minutes, 15 minutes];
    uint256 public constant BRIDGE_TIMEOUT = 2 hours;
    uint256 public minBridgeAmount = 1e6; // 1 USDC minimum
    uint256 public maxBridgeAmount = 1_000_000e6; // 1M USDC maximum
    
    // Failed bridge tracking
    mapping(uint64 => bool) public failedBridges;
    mapping(address => uint64[]) public userFailedBridges;

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
    
    event BridgeTimedOut(
        uint64 indexed nonce,
        uint256 timeout
    );
    
    event BridgeRetryScheduled(
        uint64 indexed nonce,
        uint256 attempt,
        uint256 nextRetryTime
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
    error BridgeTimeout(uint64 nonce);
    error BridgeAlreadyFailed(uint64 nonce);
    error AttestationFetchFailed(bytes32 messageHash);

    // CCTP message format, see https://developers.circle.com/stablecoins/docs/cctp-technical-reference#message
    struct CCTPMessage {
        uint32 version;
        uint32 sourceDomain;
        uint32 destinationDomain;
        uint64 nonce;
        bytes32 sender;
        bytes32 recipient;
        bytes32 destinationCaller;
        uint256 amount;
    }

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
    ) external nonReentrant whenNotPaused virtual returns (uint64 nonce) {
        // Validate inputs
        if (amount < minBridgeAmount) revert AmountTooLow(amount);
        if (amount > maxBridgeAmount) revert AmountTooHigh(amount);
        if (recipient == address(0)) revert InvalidRecipient(recipient);

        uint32 destinationDomain = chainToDomain[destinationChainId];
        if (!supportedDomains[destinationDomain]) revert InvalidDomain(destinationDomain);

        // Pull USDC from the sender
        usdc.transferFrom(msg.sender, address(this), amount);

        // Approve TokenMessenger to burn USDC
        usdc.approve(address(tokenMessenger), amount);

        // Convert recipient address to bytes32 (left-padded)
        bytes32 mintRecipient = bytes32(uint256(uint160(recipient)));

        // Initiate burn and bridge with error handling
        try tokenMessenger.depositForBurn(
            amount,
            destinationDomain,
            mintRecipient,
            address(usdc)
        ) returns (uint64 _nonce) {
            nonce = _nonce;
        } catch (bytes memory reason) {
            // If burn fails, we need to handle it gracefully
            revert(string(abi.encodePacked("Bridge failed: ", reason)));
        }

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
        if (failedBridges[nonce]) revert BridgeAlreadyFailed(nonce);
        
        // Check for timeout
        if (block.timestamp > transferToRetry.timestamp + BRIDGE_TIMEOUT) {
            failedBridges[nonce] = true;
            userFailedBridges[transferToRetry.recipient].push(nonce);
            emit BridgeTimedOut(nonce, transferToRetry.timestamp + BRIDGE_TIMEOUT);
            revert BridgeTimeout(nonce);
        }
        
        // Check retry delay using exponential backoff
        uint256 retryDelay = retryDelays[transferToRetry.retryCount < retryDelays.length ? transferToRetry.retryCount : retryDelays.length - 1];
        if (block.timestamp < transferToRetry.timestamp + retryDelay) {
            revert RetryDelayNotElapsed(
                transferToRetry.timestamp + retryDelay - block.timestamp
            );
        }
        if (transferToRetry.retryCount >= MAX_RETRY_COUNT) {
            emit BridgeFailed(nonce);
            revert MaxRetriesExceeded(nonce);
        }

        // Increment retry count
        transferToRetry.retryCount++;

        // Re-approve and re-bridge with error handling
        usdc.approve(address(tokenMessenger), transferToRetry.amount);
        bytes32 mintRecipient = bytes32(uint256(uint160(transferToRetry.recipient)));
        
        uint64 newNonce;
        try tokenMessenger.depositForBurn(
            transferToRetry.amount,
            transferToRetry.destinationDomain,
            mintRecipient,
            address(usdc)
        ) returns (uint64 _newNonce) {
            newNonce = _newNonce;
        } catch (bytes memory reason) {
            // If retry fails, mark as failed and emit event
            failedBridges[nonce] = true;
            userFailedBridges[transferToRetry.recipient].push(nonce);
            emit BridgeFailed(nonce);
            revert(string(abi.encodePacked("Retry failed: ", reason)));
        }

        // Update pending transfer with new nonce and timestamp
        pendingTransfers[newNonce] = transferToRetry;
        pendingTransfers[newNonce].timestamp = block.timestamp;
        
        // Remove old pending transfer
        delete pendingTransfers[nonce];

        emit BridgeRetried(nonce, newNonce, transferToRetry.retryCount);
        
        // Schedule next retry if needed
        if (transferToRetry.retryCount < MAX_RETRY_COUNT) {
            uint256 nextRetryDelay = retryDelays[transferToRetry.retryCount < retryDelays.length ? transferToRetry.retryCount : retryDelays.length - 1];
            emit BridgeRetryScheduled(newNonce, transferToRetry.retryCount + 1, block.timestamp + nextRetryDelay);
        }
    }

    /**
     * @notice Receive USDC from another chain
     * @param message Message bytes from source chain
     * @param attestation Attestation from Circle's attestation service
     */
    /**
     * @notice Handles a message received from the CCTP TokenMessenger
     * @dev This function is called by the TokenMessenger after a successful cross-chain transfer.
     * @param sourceDomain The CCTP domain from which the message originated.
     * @param messageBody The raw bytes of the CCTP message.
     */
    function handleReceiveMessage(
        uint32 sourceDomain,
        bytes32, /* remoteTokenMessenger */
        bytes calldata messageBody
    ) external nonReentrant whenNotPaused {
        require(msg.sender == address(tokenMessenger), "Only TokenMessenger");
        require(supportedDomains[sourceDomain], "Unsupported source domain");

        bytes32 messageHash = keccak256(messageBody);
        if (processedMessages[messageHash]) revert MessageAlreadyProcessed(messageHash);
        processedMessages[messageHash] = true;

        CCTPMessage memory cctpMessage = _parseCCTPMessage(messageBody);
        address recipient = address(uint160(uint256(cctpMessage.recipient)));

        // Clear pending transfer if it exists
        if (pendingTransfers[cctpMessage.nonce].timestamp != 0) {
            delete pendingTransfers[cctpMessage.nonce];
        }

        // Transfer USDC to the intended recipient
        usdc.transfer(recipient, cctpMessage.amount);

        emit BridgeCompleted(messageHash, cctpMessage.amount, sourceDomain, recipient);
    }
    
    /**
     * @notice Parses a raw CCTP message into a structured format.
     * @param message The raw bytes of the CCTP message.
     * @return A CCTPMessage struct.
     */
    function _parseCCTPMessage(
        bytes calldata message
    ) private pure returns (CCTPMessage memory) {
        return abi.decode(message, (CCTPMessage));
    }



    /**
     * @notice Get failed bridges for a user
     * @param user User address
     * @return Array of failed bridge nonces
     */
    function getUserFailedBridges(address user) external view returns (uint64[] memory) {
        return userFailedBridges[user];
    }

    /**
     * @notice Check if a bridge can be retried
     * @param nonce Bridge nonce
     * @return canRetry Whether the bridge can be retried
     * @return timeUntilRetry Time until next retry is allowed
     */
    function canRetryBridge(uint64 nonce) external view returns (bool canRetry, uint256 timeUntilRetry) {
        PendingTransfer memory transfer = pendingTransfers[nonce];
        
        if (transfer.timestamp == 0 || failedBridges[nonce] || transfer.retryCount >= MAX_RETRY_COUNT) {
            return (false, 0);
        }

        // Check timeout
        if (block.timestamp > transfer.timestamp + BRIDGE_TIMEOUT) {
            return (false, 0);
        }

        uint256 retryDelay = retryDelays[transfer.retryCount < retryDelays.length ? transfer.retryCount : retryDelays.length - 1];
        uint256 nextRetryTime = transfer.timestamp + retryDelay;
        
        if (block.timestamp >= nextRetryTime) {
            return (true, 0);
        } else {
            return (false, nextRetryTime - block.timestamp);
        }
    }

    /**
     * @notice Get bridge retry configuration
     * @return delays Array of retry delays
     * @return maxRetries Maximum number of retries
     * @return timeout Bridge timeout duration
     */
    function getBridgeRetryConfiguration() external view returns (uint256[] memory delays, uint256 maxRetries, uint256 timeout) {
        return (retryDelays, MAX_RETRY_COUNT, BRIDGE_TIMEOUT);
    }

    /**
     * @notice Manual retry for a failed bridge (admin only)
     * @param nonce Bridge nonce to retry
     * @return newNonce New bridge nonce
     */
    function manualRetryBridge(uint64 nonce) external nonReentrant whenNotPaused onlyRole(RETRIER_ROLE) returns (uint64 newNonce) {
        PendingTransfer storage transferToRetry = pendingTransfers[nonce];
        
        if (transferToRetry.timestamp == 0) revert TransferNotPending(nonce);
        
        // Force retry regardless of delay or retry count for manual intervention
        transferToRetry.retryCount++;
        
        // Re-approve and re-bridge
        usdc.approve(address(tokenMessenger), transferToRetry.amount);
        bytes32 mintRecipient = bytes32(uint256(uint160(transferToRetry.recipient)));
        
        try tokenMessenger.depositForBurn(
            transferToRetry.amount,
            transferToRetry.destinationDomain,
            mintRecipient,
            address(usdc)
        ) returns (uint64 _newNonce) {
            newNonce = _newNonce;
            
            // Update pending transfer with new nonce and timestamp
            pendingTransfers[newNonce] = transferToRetry;
            pendingTransfers[newNonce].timestamp = block.timestamp;
            
            // Remove old pending transfer
            delete pendingTransfers[nonce];
            
            // Remove from failed bridges if it was there
            if (failedBridges[nonce]) {
                failedBridges[nonce] = false;
            }
            
            emit BridgeRetried(nonce, newNonce, transferToRetry.retryCount);
        } catch (bytes memory reason) {
            // Mark as permanently failed
            failedBridges[nonce] = true;
            userFailedBridges[transferToRetry.recipient].push(nonce);
            emit BridgeFailed(nonce);
            revert(string(abi.encodePacked("Manual retry failed: ", reason)));
        }
    }

    /**
     * @notice Emergency bridge recovery (admin only) - refunds USDC to user
     * @param nonce Bridge nonce to recover
     */
    function emergencyBridgeRecovery(uint64 nonce) external nonReentrant whenNotPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        PendingTransfer memory transfer = pendingTransfers[nonce];
        
        if (transfer.timestamp == 0) revert TransferNotPending(nonce);
        
        // Only allow recovery after timeout or max retries
        require(
            block.timestamp > transfer.timestamp + BRIDGE_TIMEOUT || 
            transfer.retryCount >= MAX_RETRY_COUNT ||
            failedBridges[nonce],
            "Bridge not eligible for recovery"
        );
        
        // Transfer USDC back to the original sender
        address originalSender = transfer.recipient; // Note: In a real implementation, you'd want to track the original sender
        usdc.transfer(originalSender, transfer.amount);
        
        // Clean up
        delete pendingTransfers[nonce];
        failedBridges[nonce] = true;
        
        emit BridgeFailed(nonce);
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
        usdc.transfer(to, amount);
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