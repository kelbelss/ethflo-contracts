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

    function _createFunctionForTests(uint256 deadline, uint256 goal) internal {
        vm.startPrank(CREATOR);
        ethFlo.createFundraiser({_deadline: deadline, _goal: goal});
        vm.stopPrank();
    }

    // createFundraiser TESTS

    function test_createFundraiser_success() public {
        vm.startPrank(CREATOR);
        uint256 id = ethFlo.createFundraiser({_deadline: block.timestamp + 6 days, _goal: 50e6});

        // check variables were set correctly

        (address _creator, uint256 _deadline, uint256 _goal, uint256 _amountRaised) = ethFlo.fundraisers(id);

        assertEq(_creator, CREATOR, "Creator not set correctly");
        assertEq(_deadline, block.timestamp + 6 days, "Deadline not set correctly");
        assertEq(_goal, 50e6, "Goal not set correctly");
        assertEq(_amountRaised, 0, "Amount raised not correct");
    }

    function test_createFundraiser_fail_DeadlineError() public {
        vm.startPrank(CREATOR);
        vm.expectRevert(EthFlo.EthFlo_DeadlineError.selector);
        ethFlo.createFundraiser(block.timestamp + 4 days, 50e6);
    }

    function test_createFundraiser_fail_GoalError() public {
        vm.startPrank(CREATOR);
        vm.expectRevert(EthFlo.EthFlo_GoalError.selector);
        ethFlo.createFundraiser(block.timestamp + 6 days, 9e6);
    }

    function test_event_createFundraiser_success() public {
        vm.expectEmit(true, false, false, true);
        vm.startPrank(CREATOR);
        emit EthFlo.CreateFundraiser(CREATOR, block.timestamp + 6 days, 50e6);
        ethFlo.createFundraiser(block.timestamp + 6 days, 50e6);
    }

    // donate TESTS

    function test_donate_fail_EthFlo_FundraiserDoesNotExist() public {
        vm.startPrank(DONOR);
        vm.expectRevert(EthFlo.EthFlo_FundraiserDoesNotExist.selector);
        ethFlo.donate(1, 0);
    }

    function test_donate_fail_EthFlo_FundraiserDeadlineHasPassed() public {
        _createFunctionForTests(block.timestamp + 5 days, 30e6);
        vm.warp(30e12);

        vm.startPrank(DONOR);
        USDT.forceApprove(address(ethFlo), 20e6);
        vm.expectRevert(EthFlo.EthFlo_FundraiserDeadlineHasPassed.selector);
        ethFlo.donate(1, 20e6);
    }

    function test_donate_fail_EthFlo_MinimumDonationNotMet() public {
        _createFunctionForTests(block.timestamp + 5 days, 30e6);

        vm.startPrank(DONOR);
        USDT.forceApprove(address(ethFlo), 20e6);
        vm.expectRevert(EthFlo.EthFlo_MinimumDonationNotMet.selector);
        ethFlo.donate(1, 5e6);
    }

    function test_donate_receiveDonation_success() public {
        _createFunctionForTests(block.timestamp + 5 days, 30e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 0);
        console.log("EthFlo balance before donation", USDT.balanceOf(address(ethFlo)));
        vm.startPrank(DONOR);
        USDT.forceApprove(address(ethFlo), 35e6);
        ethFlo.donate(1, 35e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 35e6);
        console.log("EthFlo balance after donation", USDT.balanceOf(address(ethFlo)));
    }

    function test_event_donate_success() public {
        _createFunctionForTests(block.timestamp + 60 days, 15e6);

        console.log("donors balance", USDT.balanceOf(DONOR));

        vm.startPrank(DONOR);

        // SafeERC20.sol
        USDT.forceApprove(address(ethFlo), 15e6);

        vm.expectEmit(true, true, false, true);
        emit EthFlo.Donation(DONOR, 1, 15e6);
        ethFlo.donate(1, 15e6);
    }

    // creatorWithdraw TESTS

    function test_creatorWithdraw_success() public {
        // create fundraiser
        _createFunctionForTests(block.timestamp + 5 days, 20e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 0);
        // make donation
        vm.startPrank(DONOR);
        USDT.forceApprove(address(ethFlo), 25e6);
        ethFlo.donate(1, 25e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 25e6);
        console.log("EthFlo balance after donation", USDT.balanceOf(address(ethFlo)));
        vm.stopPrank();
        // creator withdraw
        vm.startPrank(CREATOR);
        vm.warp(20e12);
        ethFlo.creatorWithdraw(1);

        console.log("EthFlo balance after withdraw", USDT.balanceOf(address(ethFlo)));
    }

    function test_creatorWithdraw_fail_EthFlo_IncorrectFundraiserOwner() public {
        // create fundraiser
        _createFunctionForTests(block.timestamp + 5 days, 20e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 0);
        // make donation
        vm.startPrank(DONOR);
        USDT.forceApprove(address(ethFlo), 25e6);
        ethFlo.donate(1, 25e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 25e6);
        console.log("EthFlo balance after donation", USDT.balanceOf(address(ethFlo)));
        vm.stopPrank();
        // creator withdraw
        vm.warp(20e12);
        vm.expectRevert(EthFlo.EthFlo_IncorrectFundraiserOwner.selector);
        ethFlo.creatorWithdraw(1);
    }

    function test_creatorWithdraw_fail_EthFlo_FundraiserStillActive() public {
        // create fundraiser
        _createFunctionForTests(block.timestamp + 5 days, 20e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 0);
        // make donation
        vm.startPrank(DONOR);
        USDT.forceApprove(address(ethFlo), 25e6);
        ethFlo.donate(1, 25e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 25e6);
        console.log("EthFlo balance after donation", USDT.balanceOf(address(ethFlo)));
        vm.stopPrank();
        // creator withdraw
        vm.startPrank(CREATOR);
        vm.expectRevert(EthFlo.EthFlo_FundraiserStillActive.selector);
        ethFlo.creatorWithdraw(1);
    }

    function test_creatorWithdraw_fail_EthFlo_GoalNotReached() public {
        // create fundraiser
        _createFunctionForTests(block.timestamp + 5 days, 30e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 0);
        // make donation
        vm.startPrank(DONOR);
        USDT.forceApprove(address(ethFlo), 25e6);
        ethFlo.donate(1, 25e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 25e6);
        console.log("EthFlo balance after donation", USDT.balanceOf(address(ethFlo)));
        vm.stopPrank();
        // creator withdraw
        vm.warp(20e12);
        vm.startPrank(CREATOR);
        vm.expectRevert(EthFlo.EthFlo_GoalNotReached.selector);
        ethFlo.creatorWithdraw(1);
    }

    function test_creatorWithdraw_checkAdminFee_success() public {}

    function test_event_creatorWithdraw_success() public {}

    // claimRewardForSuccessfulFundraiser TESTS

    //

    // withdrawDonationFromUnsuccessfulFundraiser TESTS

    function test_withdrawDonationFromUnsuccessfulFundraiser_success() public {
        // create fundraiser
        _createFunctionForTests(block.timestamp + 5 days, 30e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 0);
        console.log("EthFlo balance before donation", USDT.balanceOf(address(ethFlo)));
        // make donation
        vm.startPrank(DONOR);
        USDT.forceApprove(address(ethFlo), 25e6);
        ethFlo.donate(1, 25e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 25e6);
        console.log("EthFlo balance after donation", USDT.balanceOf(address(ethFlo)));
        // withdraw donation
        vm.warp(30e12);
        ethFlo.withdrawDonationFromUnsuccessfulFundraiser(1);
        vm.stopPrank();

        console.log("EthFlo balance after withdraw", USDT.balanceOf(address(ethFlo)));
    }

    function test_withdrawDonationFromUnsuccessfulFundraiser_fail_EthFlo_NotYourDonation() public {
        // create fundraiser
        _createFunctionForTests(block.timestamp + 5 days, 30e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 0);
        console.log("EthFlo balance before donation", USDT.balanceOf(address(ethFlo)));
        // make donation
        vm.startPrank(DONOR);
        USDT.forceApprove(address(ethFlo), 25e6);
        ethFlo.donate(1, 25e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 25e6);
        console.log("EthFlo balance after donation", USDT.balanceOf(address(ethFlo)));
        vm.stopPrank();
        // withdraw donation
        vm.warp(30e12);
        vm.expectRevert(EthFlo.EthFlo_NotYourDonation.selector);
        ethFlo.withdrawDonationFromUnsuccessfulFundraiser(1);

        console.log("EthFlo balance after withdraw", USDT.balanceOf(address(ethFlo)));
        console.log("Caller address:", address(this), "does not match actual donor:", DONOR);
    }

    function test_withdrawDonationFromUnsuccessfulFundraiser_fail_EthFlo_FundraiserStillActive() public {
        // create fundraiser
        _createFunctionForTests(block.timestamp + 5 days, 30e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 0);
        console.log("EthFlo balance before donation", USDT.balanceOf(address(ethFlo)));
        // make donation
        vm.startPrank(DONOR);
        USDT.forceApprove(address(ethFlo), 35e6);
        ethFlo.donate(1, 35e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 35e6);
        console.log("EthFlo balance after donation", USDT.balanceOf(address(ethFlo)));
        // withdraw donation
        // vm.warp(30e12);
        vm.expectRevert(EthFlo.EthFlo_FundraiserStillActive.selector);
        ethFlo.withdrawDonationFromUnsuccessfulFundraiser(1);

        console.log("EthFlo balance after withdraw", USDT.balanceOf(address(ethFlo)));
    }

    function test_withdrawDonationFromUnsuccessfulFundraiser_fail_EthFlo_FundraiserWasSuccessful() public {
        // create fundraiser
        _createFunctionForTests(block.timestamp + 5 days, 30e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 0);
        console.log("EthFlo balance before donation", USDT.balanceOf(address(ethFlo)));
        // make donation
        vm.startPrank(DONOR);
        USDT.forceApprove(address(ethFlo), 35e6);
        ethFlo.donate(1, 35e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 35e6);
        console.log("EthFlo balance after donation", USDT.balanceOf(address(ethFlo)));
        // withdraw donation
        vm.warp(30e12);
        vm.expectRevert(EthFlo.EthFlo_FundraiserWasSuccessful.selector);
        ethFlo.withdrawDonationFromUnsuccessfulFundraiser(1);
    }
}
