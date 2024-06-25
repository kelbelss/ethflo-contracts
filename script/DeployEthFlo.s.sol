// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {EthFlo} from "../src/EthFlo.sol";

contract DeployEthFloScript is Script {
    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("DEV_PRIVATE_KEY");
        address deployerAddress = vm.addr(privateKey);

        console.log("Account", deployerAddress);

        vm.startBroadcast(privateKey);
        EthFlo ethFlo =
            new EthFlo(0xdAC17F958D2ee523a2206206994597C13D831ec7, 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);

        vm.stopBroadcast();

        console.log("Contract address: ", address(ethFlo));
    }
}
