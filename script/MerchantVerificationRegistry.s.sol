// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MerchantVerificationRegistry} from "src/MerchantVerificationRegistry.sol";

contract DeployMerchantVerificationRegistry is Script {
    // Network configurations
    struct NetworkConfig {
        address router;
        string name;
    }

    // Authorized sender configurations
    struct AuthorizedSenderConfig {
        uint64 chainSelector;
        address sender;
        string chainName;
    }

    // Network configurations mapping
    mapping(uint256 => NetworkConfig) public networkConfigs;
    
    // Authorized senders configuration
    AuthorizedSenderConfig public authorizedSender;

    address private celoSender = 0x59A85C1Ef49FA7DDCbDf11d90B250A1daA3e63d1;

    MerchantVerificationRegistry public registry;

    function setUp() public {
        // Setup network configurations
        _setupNetworkConfigs();
        
        // Setup authorized senders
        _setupAuthorizedSenders(celoSender);
    }

    function run() public {
        setUp();
        
        step1();

        // Log deployment details
        _logDeploymentDetails();
    }

    function step1() public {
        uint256 chainId = block.chainid;
        
        console.log("Deploying MerchantVerificationRegistry on chain ID:", chainId);

        // Get network configuration
        NetworkConfig memory config = networkConfigs[chainId];
        require(config.router != address(0), "Unsupported network");

        vm.startBroadcast();

        // Deploy the registry contract
        registry = new MerchantVerificationRegistry(config.router);
        // registry = MerchantVerificationRegistry(0xaa50ACdF785E28beBf760999a256b05300bC82A7);

        registry.addAuthorizedSender(authorizedSender.chainSelector, authorizedSender.sender);
        
        console.log("MerchantVerificationRegistry deployed to:", address(registry));

        vm.stopBroadcast();
        console.log("reverting");
    }

    function _setupNetworkConfigs() internal {
        // Ethereum Sepolia
        networkConfigs[11155111] = NetworkConfig({
            router: 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59, // Chainlink CCIP Router Sepolia
            name: "Ethereum Sepolia"
        });
    }

    function _setupAuthorizedSenders(address sender) internal {
        if (sender == address(0x0)){
            revert("empty sender");
        }
        // These are the chain selectors and sender addresses that can send verification data
        // You'll need to update these with the actual deployed addresses of your CrossChainMerchantVerification contracts

        // From Celo Alfajores
        authorizedSender = AuthorizedSenderConfig({
            chainSelector: 3552045678561919002, // Celo Alfajores chain selector
            sender: sender, // Sender address passed as an argument
            chainName: "Celo Alfajores"
        });
    }

    function _logDeploymentDetails() internal view {
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Registry Contract Address:", address(registry));
        console.log("Chain ID:", block.chainid);
        console.log("Network:", networkConfigs[block.chainid].name);
        console.log("CCIP Router:", networkConfigs[block.chainid].router);
        console.log("Registry Owner:", registry.owner());

        console.log("\n=== AUTHORIZED SENDERS ===");
        AuthorizedSenderConfig memory config = authorizedSender;
        console.log(string.concat(config.chainName, " Chain Selector:"), config.chainSelector);
        console.log(string.concat(config.chainName, " Sender:"), config.sender);
            
        if (config.sender != address(0) && config.chainSelector != getChainSelector(block.chainid)) {
            bool isAuthorized = registry.isAuthorizedSender(config.chainSelector, config.sender);
            console.log(string.concat(config.chainName, " Authorized:"), isAuthorized);
        }

        console.log("\n=== NEXT STEPS ===");
        console.log("1. Deploy CrossChainMerchantVerification contracts on source chains");
        console.log("2. Update authorized sender addresses in this script");
        console.log("3. Re-run this script with updated addresses OR manually call addAuthorizedSender()");
        console.log("4. Update receiver addresses in CrossChainMerchantVerification deployment script");
        console.log("5. Test cross-chain verification flow");
    }

    // Helper function to get chain selector for a given chain ID
    function getChainSelector(uint256 chainId) internal pure returns (uint64) {
        if (chainId == 11155111) return 16015286601757825753; // Ethereum Sepolia
        if (chainId == 80001) return 12532609583862916517; // Polygon Mumbai
        if (chainId == 43113) return 14767482510784806043; // Avalanche Fuji
        if (chainId == 421614) return 3478487238524512106; // Arbitrum Sepolia
        if (chainId == 11155420) return 5224473277236331295; // Optimism Sepolia
        if (chainId == 84532) return 10344971235874465080; // Base Sepolia
        return 0;
    }

    // Helper function to add authorized sender after deployment
    function addAuthorizedSender(
        uint64 chainSelector,
        address sender,
        string memory chainName
    ) external {
        require(address(registry) != address(0), "Registry not deployed");
        
        vm.startBroadcast();
        
        registry.addAuthorizedSender(chainSelector, sender);
        console.log("Added authorized sender for", chainName, ":", sender);
        
        vm.stopBroadcast();
    }

    // Helper function to remove authorized sender
    function removeAuthorizedSender(
        uint64 chainSelector,
        address sender,
        string memory chainName
    ) external {
        require(address(registry) != address(0), "Registry not deployed");
        
        vm.startBroadcast();
        
        registry.removeAuthorizedSender(chainSelector, sender);
        console.log("Removed authorized sender for", chainName, ":", sender);
        
        vm.stopBroadcast();
    }

    // Helper function to get verification info by intmax address
    function getVerificationByIntmax(
        bytes calldata intmaxAddress
    ) external view returns (
        uint256 userIdentifier,
        string[] memory name,
        string memory nationality,
        bytes memory linkedIntmaxAddress,
        address linkedEvmAddress
    ) {
        require(address(registry) != address(0), "Registry not deployed");
        
        MerchantVerificationRegistry.VerificationData memory info = 
            registry.getVerificationByIntmax(intmaxAddress);
        
        return (
            info.userIdentifier,
            info.name,
            info.nationality,
            info.intmaxAddress,
            info.evmAddress
        );
    }

    // Helper function to get verification info by EVM address
    function getVerificationByEvm(
        address evmAddress
    ) external view returns (
        uint256 userIdentifier,
        string[] memory name,
        string memory nationality,
        bytes memory linkedIntmaxAddress,
        address linkedEvmAddress
    ) {
        require(address(registry) != address(0), "Registry not deployed");
        
        MerchantVerificationRegistry.VerificationData memory info = 
            registry.getVerificationByEvm(evmAddress);
        
        return (
            info.userIdentifier,
            info.name,
            info.nationality,
            info.intmaxAddress,
            info.evmAddress
        );
    }

    // Helper function to check if addresses are verified
    function checkVerificationStatus(
        bytes calldata intmaxAddress,
        address evmAddress
    ) external view returns (bool intmaxVerified, bool evmVerified) {
        require(address(registry) != address(0), "Registry not deployed");
        
        intmaxVerified = registry.isIntmaxAddressVerified(intmaxAddress);
        evmVerified = registry.isEvmAddressVerified(evmAddress);
        
        console.log("Intmax address verified:", intmaxVerified);
        console.log("EVM address verified:", evmVerified);
        
        return (intmaxVerified, evmVerified);
    }
}