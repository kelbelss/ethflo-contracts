// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {StdUtils} from "lib/forge-std/src/StdUtils.sol";
import {EthFlo} from "../src/EthFlo.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract EthFloTest is Test {
    using SafeERC20 for IERC20;

    EthFlo ethFlo;

    address public CREATOR = makeAddr("creator");
    address public DONOR = makeAddr("donor");

    IERC20 public USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);

    function setUp() public {
        uint256 forkId = vm.createFork(vm.envString("MAINNET_RPC_URL"), 20000000);
        vm.selectFork(forkId);

        ethFlo = new EthFlo(address(USDT));

        deal(address(USDT), DONOR, 100e6);
    }

    function _createFunctionForTests(address creator, uint256 deadline, uint256 goal) internal {
        vm.startPrank(CREATOR);
        ethFlo.createFundraiser({_creatorAddr: creator, _deadline: deadline, _goal: goal});
        vm.stopPrank();
    }

    // createFundraiser TESTS

    function test_createFundraiser_success() public {
        vm.startPrank(CREATOR);
        uint256 id = ethFlo.createFundraiser({_creatorAddr: CREATOR, _deadline: block.timestamp + 6 days, _goal: 50e6});

        // check variables were set correctly

        (address _creator, uint256 _deadline, uint256 _goal) = ethFlo.fundraisers(id);

        assertEq(_creator, CREATOR, "Creator not set correctly");
        assertEq(_deadline, block.timestamp + 6 days, "Deadline not set correctly");
        assertEq(_goal, 50e6, "Goal not set correctly");
    }

    function test_createFundraiser_fail_DeadlineError() public {
        vm.startPrank(CREATOR);
        vm.expectRevert(EthFlo.EthFlo_DeadlineError.selector);
        ethFlo.createFundraiser(CREATOR, block.timestamp + 4 days, 50e6);
    }

    function test_createFundraiser_fail_GoalError() public {
        vm.startPrank(CREATOR);
        vm.expectRevert(EthFlo.EthFlo_GoalError.selector);
        ethFlo.createFundraiser(CREATOR, block.timestamp + 6 days, 9e6);
    }

    function test_event_createFundraiser_success() public {
        vm.expectEmit(true, false, false, true);
        emit EthFlo.CreateFundraiser(CREATOR, block.timestamp + 6 days, 50e6);
        ethFlo.createFundraiser(CREATOR, block.timestamp + 6 days, 50e6);
    }

    // donate TESTS

    function test_donate_fail_EthFlo_FundraiserDoesNotExist() public {}

    function test_donate_fail_EthFlo_FundraiserDeadlineHasPassed() public {}

    function test_donate_fail_EthFlo_MinimumDonationNotMet() public {}

    function test_donate_receiveDonation_success() public {}

    function test_event_donate_success() public {
        _createFunctionForTests(CREATOR, block.timestamp + 60 days, 15e6);

        console.log("donors balance", USDT.balanceOf(DONOR));

        vm.startPrank(DONOR);

        // SafeERC20.sol
        USDT.forceApprove(address(ethFlo), 15e6);

        vm.expectEmit(true, true, false, true);
        emit EthFlo.Donation(DONOR, 1, 15e6);
        ethFlo.donate(1, 15e6);
    }
}
