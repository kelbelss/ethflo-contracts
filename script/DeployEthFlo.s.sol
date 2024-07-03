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
            new EthFlo(0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0, 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951);
        // 0xaf0f6E8b0DC5C913bBF4d14C22B4e78dB875A937

        vm.stopBroadcast();

        console.log("Contract address: ", address(ethFlo));
    }
}
