// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Crowdfund} from "../src/Crowdfund.sol";

contract CrowdfundTest is Test {
    Crowdfund crowdfund;

    address public CREATOR = makeAddr("creator");
    uint256 constant GOAL = 1 ether;
    uint256 constant DURATION = 0; // figure out times

    function testCreateFundraiser() public {}
}
