// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IMailbox } from "../../contracts/interfaces/Hyperlane/IMailbox.sol";
import { IInterchainGasPaymaster } from "../../contracts/interfaces/Hyperlane/IInterchainGasPaymaster.sol";
import { IMessageRecipient } from "../../contracts/interfaces/Hyperlane/IMessageRecipient.sol";

/**
 * @title HyperlaneTestMessage
 * @notice Simple contract to test Hyperlane messaging between testnets
 * @dev Deploy this on both Base Sepolia and Ethereum Sepolia to test messaging
 */
contract HyperlaneTestMessage is IMessageRecipient {
    IMailbox public immutable mailbox;
    IInterchainGasPaymaster public immutable igp;
    address public immutable owner;
    
    // Domain configuration
    uint32 public localDomain;
    mapping(uint32 => address) public remoteDomains;
    
    // Gas configuration
    uint256 public defaultGasLimit = 100000;
    mapping(uint32 => uint256) public domainGasLimits; // domain => gas limit
    
    // Message storage
    struct ReceivedMessage {
        uint32 origin;
        bytes32 sender;
        string message;
        uint256 timestamp;
    }
    
    ReceivedMessage[] public receivedMessages;
    mapping(bytes32 => bool) public processedMessages;
    
    // Gas limits
    uint256 public constant MIN_GAS_LIMIT = 50000;
    uint256 public constant MAX_GAS_LIMIT = 2000000;
    
    // Events
    event MessageSent(uint32 indexed destination, string message, bytes32 messageId);
    event MessageReceived(uint32 indexed origin, bytes32 sender, string message);
    event GasLimitSet(uint32 indexed domain, uint256 gasLimit);
    event DefaultGasLimitSet(uint256 gasLimit);
    
    modifier onlyMailbox() {
        require(msg.sender == address(mailbox), "Only mailbox");
        _;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    constructor(address _mailbox, address _igp) {
        require(_mailbox != address(0), "Invalid mailbox");
        require(_igp != address(0), "Invalid IGP");
        
        mailbox = IMailbox(_mailbox);
        igp = IInterchainGasPaymaster(_igp);
        localDomain = mailbox.localDomain();
        owner = msg.sender;
    }
    
    /**
     * @notice Send a test message to another domain
     * @param _destination The destination domain ID
     * @param _message The message to send
     */
    function sendMessage(uint32 _destination, string calldata _message) external payable {
        require(remoteDomains[_destination] != address(0), "Unknown destination");
        
        // Encode the message
        bytes memory encodedMessage = abi.encode(_message);
        
        // Convert recipient address to bytes32
        bytes32 recipient = bytes32(uint256(uint160(remoteDomains[_destination])));
        
        // Get gas limit for destination
        uint256 gasLimit = getGasLimit(_destination);
        
        // Quote gas payment for IGP
        uint256 igpPayment = igp.quoteGasPayment(_destination, gasLimit);
        
        // Quote dispatch payment (may be 0 or may include hook fees)
        uint256 dispatchPayment = mailbox.quoteDispatch(_destination, recipient, encodedMessage);
        
        // Total payment required
        uint256 totalPayment = igpPayment + dispatchPayment;
        require(msg.value >= totalPayment, "Insufficient payment");
        
        // Calculate refund before any external calls
        uint256 refundAmount = msg.value - totalPayment;
        
        // Dispatch the message with any required payment
        bytes32 messageId = mailbox.dispatch{value: dispatchPayment}(_destination, recipient, encodedMessage);
        
        // Pay for gas
        igp.payForGas{value: igpPayment}(
            messageId,
            _destination,
            gasLimit,
            msg.sender
        );
        
        emit MessageSent(_destination, _message, messageId);
        
        // Refund excess payment (checks-effects-interactions pattern)
        if (refundAmount > 0) {
            (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
            require(success, "Refund failed");
        }
    }
    
    /**
     * @notice Handle an incoming message from Hyperlane
     * @param _origin The origin domain
     * @param _sender The sender address on origin chain
     * @param _body The message body
     */
    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes calldata _body
    ) external payable override onlyMailbox {
        // Generate message ID for deduplication
        bytes32 messageId = keccak256(abi.encodePacked(_origin, _sender, _body, block.timestamp));
        
        // Check if already processed
        if (processedMessages[messageId]) {
            return; // Already processed, skip
        }
        
        // Mark as processed
        processedMessages[messageId] = true;
        
        // Decode the message
        string memory message = abi.decode(_body, (string));
        
        // Store the message
        receivedMessages.push(ReceivedMessage({
            origin: _origin,
            sender: _sender,
            message: message,
            timestamp: block.timestamp
        }));
        
        emit MessageReceived(_origin, _sender, message);
    }
    
    /**
     * @notice Set a remote domain address
     * @param _domain The remote domain ID
     * @param _address The contract address on that domain
     */
    function setRemoteDomain(uint32 _domain, address _address) external onlyOwner {
        require(_address != address(0), "Invalid address");
        remoteDomains[_domain] = _address;
    }
    
    /**
     * @notice Set gas limit for a specific domain
     * @param _domain The domain ID
     * @param _gasLimit The gas limit to use for messages to this domain
     */
    function setDomainGasLimit(uint32 _domain, uint256 _gasLimit) external onlyOwner {
        require(_gasLimit >= MIN_GAS_LIMIT && _gasLimit <= MAX_GAS_LIMIT, "Gas limit out of bounds");
        domainGasLimits[_domain] = _gasLimit;
        emit GasLimitSet(_domain, _gasLimit);
    }
    
    /**
     * @notice Set the default gas limit
     * @param _gasLimit The new default gas limit
     */
    function setDefaultGasLimit(uint256 _gasLimit) external onlyOwner {
        require(_gasLimit >= MIN_GAS_LIMIT && _gasLimit <= MAX_GAS_LIMIT, "Gas limit out of bounds");
        defaultGasLimit = _gasLimit;
        emit DefaultGasLimitSet(_gasLimit);
    }
    
    /**
     * @notice Get gas limit for a domain
     * @param _domain The domain ID
     * @return The gas limit to use
     */
    function getGasLimit(uint32 _domain) public view returns (uint256) {
        uint256 limit = domainGasLimits[_domain];
        return limit > 0 ? limit : defaultGasLimit;
    }
    
    /**
     * @notice Get the number of received messages
     */
    function getReceivedMessageCount() external view returns (uint256) {
        return receivedMessages.length;
    }
    
    /**
     * @notice Quote the total payment for sending a message
     * @param _destination The destination domain
     * @param _message The message to send
     * @return dispatchPayment The payment required for dispatch
     * @return igpPayment The payment required for IGP
     * @return totalPayment The total payment required
     */
    function quoteTotalPayment(
        uint32 _destination, 
        string calldata _message
    ) external view returns (uint256 dispatchPayment, uint256 igpPayment, uint256 totalPayment) {
        require(remoteDomains[_destination] != address(0), "Unknown destination");
        
        bytes memory encodedMessage = abi.encode(_message);
        bytes32 recipient = bytes32(uint256(uint160(remoteDomains[_destination])));
        uint256 gasLimit = getGasLimit(_destination);
        
        dispatchPayment = mailbox.quoteDispatch(_destination, recipient, encodedMessage);
        igpPayment = igp.quoteGasPayment(_destination, gasLimit);
        totalPayment = dispatchPayment + igpPayment;
    }
}