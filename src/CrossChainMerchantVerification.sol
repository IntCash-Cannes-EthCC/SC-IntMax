// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {SelfVerificationRoot} from "@selfxyz/contracts/abstract/SelfVerificationRoot.sol";
import {ISelfVerificationRoot} from "@selfxyz/contracts/interfaces/ISelfVerificationRoot.sol";
import {IIdentityVerificationHubV2} from "@selfxyz/contracts/interfaces/IIdentityVerificationHubV2.sol";
import {SelfStructs} from "@selfxyz/contracts/libraries/SelfStructs.sol";
import {AttestationId} from "@selfxyz/contracts/constants/AttestationId.sol";


import {console2} from "forge-std/console2.sol";

/**
 * @title CrossChainMerchantVerification
 * @dev A contract that performs Self verification and sends results cross-chain via Chainlink CCIP
 * @notice This contract verifies user identity on one chain and sends verification results to another chain
 */
contract CrossChainMerchantVerification is SelfVerificationRoot, OwnerIsCreator {
    // Custom errors
    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees);
    error InvalidReceiver(address receiver);

    // Events
    event VerificationCompleted(
        uint256 indexed userIdentifier,
        string[] name,
        string nationality,
        string dateOfBirth
    );

    event CrossChainMessageSent(
        bytes32 indexed messageId,
        uint64 indexed destinationChainSelector,
        address receiver,
        uint256 userIdentifier,
        uint256 fees
    );

    // Chainlink CCIP components
    IRouterClient private s_router;
    LinkTokenInterface private s_linkToken;

    // Self verification configuration
    bytes32 public configId;

    // Cross-chain configuration
    mapping(uint64 => address) public destinationReceivers; // chainSelector => receiver address
    mapping(uint64 => bool) public allowedDestinationChains;

    // Verification data structure for cross-chain message
    struct VerificationData {
        uint256 userIdentifier;
        string[] name;
        string nationality;
        bytes intmaxAddress;
        address evmAddress;
        uint256 timestamp;
    }

    constructor(
        address _identityVerificationHubV2,
        uint256 _scope,
        address _router,
        address _link
    ) 
        SelfVerificationRoot(_identityVerificationHubV2, _scope)
        OwnerIsCreator()
    {
        s_router = IRouterClient(_router);
        s_linkToken = LinkTokenInterface(_link);
    }

    /**
     * @dev Set the configuration ID for Self verification
     * @param _configId The configuration ID to use for verification
     */
    function setConfigId(bytes32 _configId) external onlyOwner {
        configId = _configId;
    }

    /**
     * @notice Updates the scope used for verification.
     * @dev Only callable by the contract owner.
     * @param newScope The new scope to set.
     */
    function setScope(uint256 newScope) external onlyOwner {
        _setScope(newScope);
    }

    /**
     * @dev Add or update a destination chain and receiver
     * @param chainSelector The chain selector for the destination chain
     * @param receiver The receiver contract address on the destination chain
     */
    function setDestinationReceiver(
        uint64 chainSelector,
        address receiver
    ) external onlyOwner {
        require(receiver != address(0), "Invalid receiver address");
        destinationReceivers[chainSelector] = receiver;
        allowedDestinationChains[chainSelector] = true;
    }

    /**
     * @dev Remove a destination chain
     * @param chainSelector The chain selector to remove
     */
    function removeDestinationChain(uint64 chainSelector) external onlyOwner {
        delete destinationReceivers[chainSelector];
        allowedDestinationChains[chainSelector] = false;
    }

    /**
     * @dev Required override to provide configId for verification
     */
    function getConfigId(
        bytes32 /*destinationChainId*/,
        bytes32 /*userIdentifier*/, 
        bytes memory /*userDefinedData*/
    ) public view override returns (bytes32) {
        return configId;
    }

    /**
     * @dev Override to handle successful verification and trigger cross-chain message
     */
    function customVerificationHook(
        ISelfVerificationRoot.GenericDiscloseOutputV2 memory output,
        bytes memory userData //contaisn the intmax Address
    ) internal virtual override {
        // Emit local verification event
        emit VerificationCompleted(
            output.userIdentifier,
            output.name,
            output.nationality,
            output.dateOfBirth
        );

        // TODO: Add additional validation logic here
        // Example: Check if user meets specific criteria for cross-chain message
        require(bytes(output.nationality).length > 0, "Nationality required");
        require(bytes(output.name[0]).length > 0, "Name required");

        (bytes memory intmaxAddress, address evmAddress, uint64 destinationChainSelector) = abi.decode(userData, (bytes, address, uint64));
        
        // Send verification result cross-chain
        _sendVerificationCrossChain(output, destinationChainSelector, intmaxAddress, evmAddress);
    }

    /**
     * @dev Send verification results to another chain via Chainlink CCIP
     * @param output The verification output from Self
     * @param destinationChainSelector The destination chain selector
     */
    function _sendVerificationCrossChain(
        ISelfVerificationRoot.GenericDiscloseOutputV2 memory output,
        uint64 destinationChainSelector,
        bytes memory intmaxAddress,
        address evmAddress
    ) internal {
        // Prepare verification data for cross-chain transmission
        VerificationData memory verificationData = VerificationData({
            userIdentifier: output.userIdentifier,
            name: output.name,
            nationality: output.nationality,
            intmaxAddress: intmaxAddress,
            evmAddress: evmAddress,
            timestamp: block.timestamp
        });

        // Send using common function
        _sendCCIPMessage(destinationChainSelector, verificationData);
    }

    /**
     * @dev Manual function to send verification data cross-chain (for testing or manual triggers)
     * @param userIdentifier The user identifier
     * @param name The verified name array
     * @param nationality The verified nationality
     * @param intmaxAddress The IntMax address
     * @param evmAddress The EVM address
     * @param destinationChainSelector The destination chain selector
     */
    function manualSendVerification(
        uint256 userIdentifier,
        string[] memory name,
        string calldata nationality,
        bytes memory intmaxAddress,
        address evmAddress,
        uint64 destinationChainSelector
    ) external onlyOwner {
        console2.log("entering the field");
        require(bytes(name[0]).length > 0, "Name required");
        require(bytes(nationality).length > 0, "Nationality required");

        // Create verification data
        VerificationData memory verificationData = VerificationData({
            userIdentifier: userIdentifier,
            name: name,
            nationality: nationality,
            intmaxAddress: intmaxAddress,
            evmAddress: evmAddress,
            timestamp: block.timestamp
        });

        console2.log("I'm here");

        // Send using common function
        _sendCCIPMessage(destinationChainSelector, verificationData);
    }

    /**
     * @dev Internal function to handle CCIP message creation and sending
     * @param destinationChainSelector The destination chain selector
     * @param verificationData The verification data to send
     */
    function _sendCCIPMessage(
        uint64 destinationChainSelector,
        VerificationData memory verificationData
    ) internal {

        address receiver = destinationReceivers[destinationChainSelector];
        if (receiver == address(0)) {
            revert InvalidReceiver(receiver);
        }

        // Create CCIP message
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: abi.encode(verificationData),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({
                    gasLimit: 300_000,
                    allowOutOfOrderExecution: true
                })
            ),
            feeToken: address(s_linkToken)
        });

        // Calculate and check fees
        uint256 fees = s_router.getFee(destinationChainSelector, evm2AnyMessage);

        if (fees > s_linkToken.balanceOf(address(this))) {
            revert NotEnoughBalance(s_linkToken.balanceOf(address(this)), fees);
        }

        // Approve and send
        s_linkToken.approve(address(s_router), fees);
        bytes32 messageId = s_router.ccipSend(destinationChainSelector, evm2AnyMessage);

        // Emit event
        emit CrossChainMessageSent(
            messageId,
            destinationChainSelector,
            receiver,
            verificationData.userIdentifier,
            fees
        );
    }

    /**
     * @dev Withdraw LINK tokens from the contract
     * @param to The address to withdraw to
     */
    function withdrawLink(address to) external onlyOwner {
        uint256 balance = s_linkToken.balanceOf(address(this));
        require(balance > 0, "No LINK balance");
        s_linkToken.transfer(to, balance);
    }

    /**
     * @dev Get the fee for sending a message to a destination chain
     * @param destinationChainSelector The destination chain selector
     * @param verificationData The verification data to send
     * @return fees The fee amount in LINK tokens
     */
    function getFeeEstimate(
        uint64 destinationChainSelector,
        VerificationData memory verificationData
    ) external view returns (uint256 fees) {
        address receiver = destinationReceivers[destinationChainSelector];
        require(receiver != address(0), "Invalid receiver");

        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: abi.encode(verificationData),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({
                    gasLimit: 300_000,
                    allowOutOfOrderExecution: true
                })
            ),
            feeToken: address(s_linkToken)
        });

        return s_router.getFee(destinationChainSelector, evm2AnyMessage);
    }
}