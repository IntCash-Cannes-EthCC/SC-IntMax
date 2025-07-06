// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {CrossChainMerchantVerification} from "src/CrossChainMerchantVerification.sol";
import {IWeth} from "src/IWeth.sol";

contract UpdateVerificationStatus is Script {
    uint64 destinationChainSelector = 16015286601757825753;
    address router = 0xb00E95b773528E2Ea724DB06B75113F239D15Dca;

    uint256 userIdentifier = 123456;
    string[] name = new string[](1);
    address evmAddress = address(0xABC);
    string nationality = "FR";
    bytes intmaxAddress;

    address CROSS = 0x3c7c16B216D8C4Fc786aD38d8615200D9B34168c;


    function run() public {
        name[0] = "patalo";
        intmaxAddress = '42';

        vm.startBroadcast();

        // CrossChainMerchantVerification cross = new CrossChainMerchantVerification(address(0x1), 123, router, 0x99604d0e2EfE7ABFb58BdE565b5330Bb46Ab3Dca);
        CrossChainMerchantVerification cross = CrossChainMerchantVerification(0xb92B18Bd8c215a1A641cEe37Eb1d3D1159B78A01);

        cross.setDestinationReceiver(16015286601757825753, 0xaa50ACdF785E28beBf760999a256b05300bC82A7);

        console.log("sepolia dest is allowed? ", cross.allowedDestinationChains(16015286601757825753));

        IWeth wCelo = IWeth(0x99604d0e2EfE7ABFb58BdE565b5330Bb46Ab3Dca);

        wCelo.deposit{value: 2 ether}();

        wCelo.transfer(address(cross), 2 ether);

        cross.manualSendVerification(userIdentifier, name, nationality, intmaxAddress, evmAddress, destinationChainSelector);
    }
}