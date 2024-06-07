// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {EthFlo} from "../src/EthFlo.sol";

contract EthFloTest is Test {
    EthFlo ethFlo;

    address public CREATOR = makeAddr("creator");
    // uint256 constant DEADLINE = 6 days;
    // uint256 constant GOAL = 15;

    function setUp() public {
        ethFlo = new EthFlo();
    }

    function test_createFundraiser_success() public {
        vm.startPrank(CREATOR);
        uint256 id = ethFlo.createFundraiser({_creatorAddr: CREATOR, _deadline: 6 days, _goal: 50});

        // TODO check variables were set correctly

        (address _creator, uint256 _deadline, uint256 _goal) = ethFlo.fundraisers(id);

        assertEq(_creator, CREATOR, "Creator not set correctly");
        assertEq(_deadline, 5 days, "Deadline not set correctly");
        // TODO complete
    }

    function test_event_createFundraiser_success() public {
        vm.expectEmit(true, false, false, true);
        emit EthFlo.CreateFundraiser(address(CREATOR), 6 days, 50);
        ethFlo.createFundraiser(address(CREATOR), 6 days, 50);
    }

    function test_createFundraiser_fail_DeadlineError() public {
        vm.startPrank(CREATOR);
        vm.expectRevert(EthFlo.EthFlo_DeadlineError.selector);
        ethFlo.createFundraiser(CREATOR, 4 days, 50);
    }

    function test_createFundraiser_fail_GoalError() public {
        vm.startPrank(CREATOR);
        vm.expectRevert(EthFlo.EthFlo_GoalError.selector);
        ethFlo.createFundraiser(CREATOR, 6 days, 9);
    }
}
