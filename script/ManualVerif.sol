// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {CrossChainMerchantVerification} from "src/CrossChainMerchantVerification.sol";
import {IWeth} from "src/IWeth.sol";

contract ManualVerification is Script {
    uint64 destinationChainSelector = 16015286601757825753;
    address router = 0xb00E95b773528E2Ea724DB06B75113F239D15Dca;

    uint256 userIdentifier = 123456;
    string[] name = new string[](1);
    address evmAddress = address(0xABC);
    string nationality = "FR";
    bytes intmaxAddress = 'address';

    address CROSS = 0x59A85C1Ef49FA7DDCbDf11d90B250A1daA3e63d1;


    function run() public {
        name[0] = "patalo";
        intmaxAddress= abi.encode("address");

        vm.startBroadcast();

        // CrossChainMerchantVerification cross = new CrossChainMerchantVerification(address(0x1), 123, router, 0x99604d0e2EfE7ABFb58BdE565b5330Bb46Ab3Dca);
        CrossChainMerchantVerification cross = CrossChainMerchantVerification(CROSS);

        cross.setDestinationReceiver(16015286601757825753, 0x98f65D5D44d261031E4B5b65e53efAce2b96a4DC);

        console.log("sepolia dest is allowed? ", cross.allowedDestinationChains(16015286601757825753));

        IWeth wCelo = IWeth(0x32E08557B14FaD8908025619797221281D439071);

        wCelo.transfer(address(cross), 5 ether);

        cross.manualSendVerification(userIdentifier, name, nationality, intmaxAddress, evmAddress, destinationChainSelector);
    }
}