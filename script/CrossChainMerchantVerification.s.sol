// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {CrossChainMerchantVerification} from "src/CrossChainMerchantVerification.sol";

contract DeployCrossChainMerchantVerification is Script {
    // Network configurations
    struct NetworkConfig {
        address identityVerificationHubV2;
        address router;
        address link;
        uint256 scope;
    }

    // Destination chain configurations
    struct DestinationConfig {
        uint64 chainSelector;
        address receiver;
        string name;
    }

    // Network configurations mapping
    mapping(uint256 => NetworkConfig) public networkConfigs;
    
    // Destination chains configuration
    DestinationConfig[] public destinationConfigs;

    // Contract configuration
    bytes32 public constant CONFIG_ID = 0x05e0c849fd08a01f247c8f268731bdcd1f129626e23e6d94d932213b066bc8f7;

    CrossChainMerchantVerification public crossChainVerification;

    address private testnetVerifier = 0xe57F4773bd9c9d8b6Cd70431117d353298B9f5BF;
    address private testnetMockVerifier = 0x68c931C9a534D37aa78094877F46fE46a49F1A51;

    function run() public {
        // step1();
        step2(0x59A85C1Ef49FA7DDCbDf11d90B250A1daA3e63d1, 0x98f65D5D44d261031E4B5b65e53efAce2b96a4DC);
    }

    function step1() public {
        // Setup network configurations
        _setupNetworkConfigs(testnetVerifier);
        uint256 chainId = block.chainid;
        
        console.log("Deploying on chain ID:", chainId);
        console.log("Deployer address:", msg.sender);

        // Get network configuration
        NetworkConfig memory config = networkConfigs[chainId];
        require(config.router != address(0), "Unsupported network");

        vm.startBroadcast();

        // Deploy the contract
        crossChainVerification = new CrossChainMerchantVerification(
            config.identityVerificationHubV2,
            config.scope,
            config.router,
            config.link
        );

        console.log("CrossChainMerchantVerification deployed to:", address(crossChainVerification));

        vm.stopBroadcast();

        // Log deployment details
        _logDeploymentDetails();
    }


    function step2(address crosschainVerifier, address destinationRegistry) public {   
        crossChainVerification = CrossChainMerchantVerification(crosschainVerifier);
        // Setup destination chains
        _setupDestinationConfigs(destinationRegistry);
        
        vm.startBroadcast();

        // Setup the contract
        _setupContract();

        vm.stopBroadcast();

        console.log("\n=== DESTINATION CHAINS ===");
        for (uint256 i = 0; i < destinationConfigs.length; i++) {
            DestinationConfig memory dest = destinationConfigs[i];
            console.log(string.concat(dest.name, " Chain Selector:"), dest.chainSelector);
            console.log(string.concat(dest.name, " Receiver:"), dest.receiver);
        }

        console.log("\n=== NEXT STEPS ===");
        console.log("1. Fund the contract with LINK tokens for cross-chain messaging");
        console.log("2. Update receiver addresses in the script and redeploy if needed");
        console.log("3. Set up proper Identity Verification Hub V2 addresses");
        console.log("4. Test the deployment with manual verification");
    }


    function _setupNetworkConfigs(address selfVerifierHub) internal {
        // Celo Alfajores
        networkConfigs[44787] = NetworkConfig({
            identityVerificationHubV2: selfVerifierHub, // Replace with actual address
            router: 0xb00E95b773528E2Ea724DB06B75113F239D15Dca, // Chainlink CCIP Router Sepolia
            link: 0x32E08557B14FaD8908025619797221281D439071, 
            scope: 2402919856948960743300941728239605214998686625463561505210619947001268110277
        });
    }

    function _setupDestinationConfigs(address receiver) internal {
        //TODO: Celo Alfajores to Ethereum Sepolia
        destinationConfigs.push(DestinationConfig({
            chainSelector: 16015286601757825753, // Base Sepolia chain selector
            receiver: receiver, // Replace with actual receiver address
            name: "Ethereum Sepolia"
        }));
    }

    function _setupContract() internal {
        console.log("Setting up contract configuration...");

        // Set the configuration ID
        crossChainVerification.setConfigId(CONFIG_ID);
        console.log("Set config ID:", vm.toString(CONFIG_ID));

        crossChainVerification.setScope(networkConfigs[block.chainid].scope);

        // Set up destination chains
        for (uint256 i = 0; i < destinationConfigs.length; i++) {
            DestinationConfig memory dest = destinationConfigs[i];
            
            // Skip if receiver is not set (address(0))
            if (dest.receiver == address(0)) {
                console.log("Skipping destination chain (no receiver set):", dest.name);
                continue;
            }

            crossChainVerification.setDestinationReceiver(
                dest.chainSelector,
                dest.receiver
            );
            console.log("Set destination receiver for", dest.name, ":", dest.receiver);
        }

        console.log("Contract setup completed!");
    }

    function _logDeploymentDetails() internal view {
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Contract Address:", address(crossChainVerification));
        console.log("Chain ID:", block.chainid);
        console.log("Config ID:", vm.toString(CONFIG_ID));
        
        console.log("\n=== NETWORK CONFIGURATION ===");
        NetworkConfig memory config = networkConfigs[block.chainid];
        console.log("Identity Verification Hub V2:", config.identityVerificationHubV2);
        console.log("CCIP Router:", config.router);
        console.log("LINK Token:", config.link);
        console.log("Scope:", config.scope);
    }

    // Helper function to get fee estimate
    function getFeeEstimate(
        uint64 destinationChainSelector,
        uint256 userIdentifier,
        string[] memory name,
        string memory nationality,
        bytes memory intmaxAddress,
        address evmAddress
    ) external view returns (uint256) {
        CrossChainMerchantVerification.VerificationData memory verificationData = 
            CrossChainMerchantVerification.VerificationData({
                userIdentifier: userIdentifier,
                name: name,
                nationality: nationality,
                intmaxAddress: intmaxAddress,
                evmAddress: evmAddress,
                timestamp: block.timestamp
            });

        return crossChainVerification.getFeeEstimate(destinationChainSelector, verificationData);
    }
}