// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {Crowdfund} from "../src/Crowdfund.sol";

contract CrowdfundTest is Test {
    Crowdfund crowdfund;

    address public CREATOR = makeAddr("creator");
    string constant NAME = "TesterFundraiser";
    uint256 constant DEADLINE = 0; // figure out times
    uint256 constant GOAL = 1 ether;

    function setUp() public {
        crowdfund = new Crowdfund();
    }

    function testCreateFundraiser() public {
        vm.startPrank(CREATOR);
        crowdfund.createFundraiser(CREATOR, NAME, DEADLINE, GOAL);
    }
}
