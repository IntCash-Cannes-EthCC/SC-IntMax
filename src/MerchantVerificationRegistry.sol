// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/contracts/applications/CCIPReceiver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {CrossChainMerchantVerification} from "src/CrossChainMerchantVerification.sol";

/**
 * @title MerchantVerificationRegistry
 * @dev Registry contract that receives cross-chain verification data and maintains
 * mappings from both intmax addresses and EVM addresses to verification information
 */
contract MerchantVerificationRegistry is CCIPReceiver, Ownable {
    
    // Verification information struct
    struct VerificationData {
        uint256 userIdentifier;
        string[] name;
        string nationality;
        bytes intmaxAddress;
        address evmAddress;
    }

    // Mappings for verification registry
    mapping(bytes32 => VerificationData) public intmaxToVerification;
    mapping(address => VerificationData) public evmToVerification;
    
    // Mapping to track verified intmax addresses
    mapping(bytes32 => bool) public isIntmaxVerified;
    
    // Mapping to track verified EVM addresses
    mapping(address => bool) public isEvmVerified;

    // Mapping to track authorized senders from different chains
    mapping(uint64 => mapping(address => bool)) public authorizedSenders;

    // Events
    event VerificationReceived(
        bytes32 indexed messageId,
        uint64 indexed sourceChainSelector,
        address indexed sender,
        uint256 userIdentifier,
        bytes intmaxAddress,
        address evmAddress
    );

    event VerificationUpdated(
        bytes indexed intmaxAddress,
        address indexed evmAddress,
        uint256 userIdentifier
    );

    event AuthorizedSenderAdded(
        uint64 indexed chainSelector,
        address indexed sender
    );

    event AuthorizedSenderRemoved(
        uint64 indexed chainSelector,
        address indexed sender
    );

    // Custom errors
    error UnauthorizedSender(uint64 chainSelector, address sender);
    error InvalidVerificationData();
    error VerificationAlreadyExists(bytes intmaxAddress);

    /**
     * @dev Constructor initializes the contract with the router address
     * @param router The address of the CCIP router contract
     */
    constructor(address router) CCIPReceiver(router) Ownable(msg.sender) {}

    /**
     * @dev Internal function to handle received CCIP messages
     * @param any2EvmMessage The received message from another chain
     */
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        // Decode the sender address
        address sender = abi.decode(any2EvmMessage.sender, (address));

        // Decode the verification data
        VerificationData memory verificationData = abi.decode(
            any2EvmMessage.data,
            (VerificationData)
        );

        // Validate the verification data
        if ((verificationData.intmaxAddress.length == 0) || verificationData.evmAddress == address(0)) {
            revert InvalidVerificationData();
        }

        // Create complete verification information with metadata
        VerificationData memory completeVerification = VerificationData({
            userIdentifier: verificationData.userIdentifier,
            name: verificationData.name,
            nationality: verificationData.nationality,
            intmaxAddress: verificationData.intmaxAddress,
            evmAddress: verificationData.evmAddress
        });

        // Store verification information in both mappings
        intmaxToVerification[intmaxAddressToHash(verificationData.intmaxAddress)] = completeVerification;
        evmToVerification[verificationData.evmAddress] = completeVerification;

        // Mark addresses as verified
        isIntmaxVerified[intmaxAddressToHash(verificationData.intmaxAddress)] = true;
        isEvmVerified[verificationData.evmAddress] = true;

        // Emit events
        emit VerificationReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector,
            sender,
            verificationData.userIdentifier,
            verificationData.intmaxAddress,
            verificationData.evmAddress
        );

        emit VerificationUpdated(
            verificationData.intmaxAddress,
            verificationData.evmAddress,
            verificationData.userIdentifier
        );
    }

    function intmaxAddressToHash(bytes memory intmaxAddress) public pure returns (bytes32) {
        return keccak256(abi.encode(intmaxAddress));
    }

    /**
     * @dev Add an authorized sender for a specific chain
     * @param chainSelector The chain selector of the source chain
     * @param sender The address of the authorized sender
     */
    function addAuthorizedSender(
        uint64 chainSelector,
        address sender
    ) external onlyOwner {
        authorizedSenders[chainSelector][sender] = true;
        emit AuthorizedSenderAdded(chainSelector, sender);
    }

    /**
     * @dev Remove an authorized sender for a specific chain
     * @param chainSelector The chain selector of the source chain
     * @param sender The address of the sender to remove
     */
    function removeAuthorizedSender(
        uint64 chainSelector,
        address sender
    ) external onlyOwner {
        authorizedSenders[chainSelector][sender] = false;
        emit AuthorizedSenderRemoved(chainSelector, sender);
    }

    /**
     * @dev Get verification information by intmax address
     * @param intmaxAddress The intmax address to query
     * @return The verification information
     */
    function getVerificationByIntmax(
        bytes calldata intmaxAddress
    ) external view returns (VerificationData memory) {
        return intmaxToVerification[intmaxAddressToHash(intmaxAddress)];
    }

    /**
     * @dev Get verification information by EVM address
     * @param evmAddress The EVM address to query
     * @return The verification information
     */
    function getVerificationByEvm(
        address evmAddress
    ) external view returns (VerificationData memory) {
        return evmToVerification[evmAddress];
    }

    /**
     * @dev Check if an intmax address is verified
     * @param intmaxAddress The intmax address to check
     * @return True if verified, false otherwise
     */
    function isIntmaxAddressVerified(
        bytes calldata intmaxAddress
    ) external view returns (bool) {
        return isIntmaxVerified[intmaxAddressToHash(intmaxAddress)];
    }

    /**
     * @dev Check if an EVM address is verified
     * @param evmAddress The EVM address to check
     * @return True if verified, false otherwise
     */
    function isEvmAddressVerified(
        address evmAddress
    ) external view returns (bool) {
        return isEvmVerified[evmAddress];
    }

    /**
     * @dev Get the linked EVM address for an intmax address
     * @param intmaxAddress The intmax address
     * @return The linked EVM address
     */
    function getLinkedEvmAddress(
        bytes calldata intmaxAddress
    ) external view returns (address) {
        return intmaxToVerification[intmaxAddressToHash(intmaxAddress)].evmAddress;
    }

    /**
     * @dev Get the linked intmax address for an EVM address
     * @param evmAddress The EVM address
     * @return The linked intmax address
     */
    function getLinkedIntmaxAddress(
        address evmAddress
    ) external view returns (bytes memory) {
        return evmToVerification[evmAddress].intmaxAddress;
    }

    /**
     * @dev Check if a sender is authorized for a specific chain
     * @param chainSelector The chain selector
     * @param sender The sender address
     * @return True if authorized, false otherwise
     */
    function isAuthorizedSender(
        uint64 chainSelector,
        address sender
    ) external view returns (bool) {
        return authorizedSenders[chainSelector][sender];
    }

    /**
     * @dev Get user information by either intmax or EVM address
     * @param intmaxAddress The intmax address (use 0 if querying by EVM)
     * @param evmAddress The EVM address (use address(0) if querying by intmax)
     * @return userIdentifier The user identifier
     * @return name The user's name array
     * @return nationality The user's nationality
     * @return linkedIntmaxAddress The linked intmax address
     * @return linkedEvmAddress The linked EVM address
     */
    function getUserInfo(
        bytes calldata intmaxAddress,
        address evmAddress
    ) external view returns (
        uint256 userIdentifier,
        string[] memory name,
        string memory nationality,
        bytes memory linkedIntmaxAddress,
        address linkedEvmAddress
    ) {
        VerificationData memory info;

        if (evmAddress != address(0)) {
            info = evmToVerification[evmAddress];
        }
        else {
            info = intmaxToVerification[intmaxAddressToHash(intmaxAddress)];
        } 

        return (
            info.userIdentifier,
            info.name,
            info.nationality,
            info.intmaxAddress,
            info.evmAddress
            );
    }

    /**
     * @dev Emergency function to manually update verification status (owner only)
     * @param intmaxAddress The intmax address
     * @param evmAddress The EVM address
     * @param verified The verification status
     */
    function updateVerificationStatus(
        bytes calldata intmaxAddress,
        address evmAddress,
        bool verified
    ) external onlyOwner {
        isIntmaxVerified[intmaxAddressToHash(intmaxAddress)] = verified;
        
        if (evmAddress != address(0)) {
            isEvmVerified[evmAddress] = verified;
        }
    }
}