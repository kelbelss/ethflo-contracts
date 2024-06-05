// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {EthFlo} from "../src/EthFlo.sol";

contract EthFloTest is Test {
    EthFlo ethFlo;

    address public CREATOR = makeAddr("creator");
    string constant NAME = "TesterFundraiser";
    uint256 constant DEADLINE = 0; // figure out times
    uint256 constant GOAL = 1 ether;

    function setUp() public {
        ethFlo = new EthFlo();
    }

    function testCreateFundraiser() public {
        vm.startPrank(CREATOR);
        ethFlo.createFundraiser(CREATOR, NAME, DEADLINE, GOAL);
    }
}
