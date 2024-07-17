// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {StdUtils} from "lib/forge-std/src/StdUtils.sol";
import {EthFlo} from "../src/EthFlo.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPool} from "@aave/contracts/interfaces/IPool.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract EthFloTest is Test {
    using SafeERC20 for IERC20;

    EthFlo ethFlo;

    IERC20 constant USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    address constant AAVE_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

    address public aUSDT_ADDRESS;

    address OWNER = makeAddr("Owner");
    address public CREATOR = makeAddr("creator");
    address public DONOR = makeAddr("donor");

    function setUp() public {
        uint256 forkId = vm.createFork(vm.envString("MAINNET_RPC_URL"), 20_000_000);
        vm.selectFork(forkId);

        // Verify that the Aave Pool contract exists at the expected address
        require(address(AAVE_POOL).code.length > 0, "Aave Pool contract not found");

        // Verify that the USDT contract exists at the expected address
        require(address(USDT).code.length > 0, "USDT contract not found");

        aUSDT_ADDRESS = IPool(AAVE_POOL).getReserveData(address(USDT)).aTokenAddress;
        console.log("aUSDT address retrieved:", aUSDT_ADDRESS);

        vm.startPrank(OWNER);
        ethFlo = new EthFlo(address(USDT), address(AAVE_POOL));

        // console.log("Test address:", address(this));
        // console.log("EthFlo address:", address(ethFlo));
        // console.log("Owner address:", OWNER);
        // console.log("Creators address:", CREATOR);
        // console.log("Donors address:", DONOR);

        deal(address(USDT), DONOR, 100e6);
    }

    function _createFunctionForTests(uint256 deadline, uint256 goal) internal {
        vm.startPrank(CREATOR);
        ethFlo.createFundraiser({deadline: deadline, goal: goal});
        vm.stopPrank();
    }

    function _donateFunctionForTests(uint256 _fundraiserId, uint256 _amount) internal {
        USDT.forceApprove(address(ethFlo), _amount);
        ethFlo.donate(_fundraiserId, _amount);
    }

    // withdrawFeesAndYield TESTS

    function test_withdrawFeesAndYield_success() public {
        // Check initial value of s_totalEscrowedFunds
        assertEq(ethFlo.getTotalEscrowedFunds(), 0);

        // create fundraiser
        _createFunctionForTests(block.timestamp + 5 days, 20e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 0);

        // make donation
        vm.startPrank(DONOR);
        USDT.forceApprove(address(ethFlo), 25e6);
        ethFlo.donate(1, 25e6);

        // Check s_totalEscrowedFunds after donation
        assertEq(ethFlo.getTotalEscrowedFunds(), 25e6);
        console.log("s_totalEscrowedFunds after donation", ethFlo.getTotalEscrowedFunds());

        uint256 aUSDTBalance = IERC20(aUSDT_ADDRESS).balanceOf(address(ethFlo));

        assertEq(aUSDTBalance, 25e6);
        console.log("aUSDT balance after donation", aUSDTBalance);
        console.log("EthFlo balance after donation", USDT.balanceOf(address(ethFlo)));
        vm.stopPrank();

        // creator withdraw
        vm.startPrank(CREATOR);
        vm.warp(block.timestamp + 100 days);
        ethFlo.creatorWithdraw(1);
        vm.stopPrank();

        aUSDTBalance = IERC20(aUSDT_ADDRESS).balanceOf(address(ethFlo));

        console.log("EthFlo balance after withdraw", USDT.balanceOf(address(ethFlo)));
        console.log("aUSDT balance after withdraw", aUSDTBalance);

        // Check s_totalEscrowedFunds after creator withdrawal
        assertEq(ethFlo.getTotalEscrowedFunds(), 0);
        console.log("s_totalEscrowedFunds after creator withdraw", ethFlo.getTotalEscrowedFunds());

        console.log("aUSDT balance before withdrawFeesAndYield", aUSDTBalance);

        vm.startPrank(OWNER);
        aUSDTBalance = IERC20(aUSDT_ADDRESS).balanceOf(address(ethFlo));
        ethFlo.withdrawFeesAndYield(OWNER);

        aUSDTBalance = IERC20(aUSDT_ADDRESS).balanceOf(address(ethFlo));
        console.log("aUSDT balance after withdrawFeesAndYield", aUSDTBalance);
        console.log("Owner balance after fees and yield withdraw", USDT.balanceOf(OWNER));
    }

    function test_withdrawFeesAndYield_fail_NoFeesAndYieldAvailable() public {
        // Check initial value of s_totalEscrowedFunds
        assertEq(ethFlo.getTotalEscrowedFunds(), 0);

        // create fundraiser
        _createFunctionForTests(block.timestamp + 5 days, 20e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 0);

        // make donation
        vm.startPrank(DONOR);
        USDT.forceApprove(address(ethFlo), 25e6);
        ethFlo.donate(1, 25e6);

        // Check s_totalEscrowedFunds after donation
        assertEq(ethFlo.getTotalEscrowedFunds(), 25e6);
        console.log("s_totalEscrowedFunds after donation", ethFlo.getTotalEscrowedFunds());

        uint256 aUSDTBalance = IERC20(aUSDT_ADDRESS).balanceOf(address(ethFlo));

        assertEq(aUSDTBalance, 25e6);
        console.log("aUSDT balance after donation", aUSDTBalance);
        console.log("EthFlo balance after donation", USDT.balanceOf(address(ethFlo)));
        vm.stopPrank();

        console.log("aUSDT balance before withdrawFeesAndYield", aUSDTBalance);

        vm.startPrank(OWNER);
        aUSDTBalance = IERC20(aUSDT_ADDRESS).balanceOf(address(ethFlo));
        vm.expectRevert(EthFlo.EthFlo_NoFeesAndYieldAvailable.selector);
        ethFlo.withdrawFeesAndYield(OWNER);

        aUSDTBalance = IERC20(aUSDT_ADDRESS).balanceOf(address(ethFlo));
        console.log("aUSDT balance after withdrawFeesAndYield", aUSDTBalance);
        console.log("Owner balance after fees and yield withdraw", USDT.balanceOf(OWNER));
    }

    // createFundraiser TESTS

    function test_createFundraiser_success() public {
        vm.startPrank(CREATOR);
        uint256 id = ethFlo.createFundraiser({deadline: block.timestamp + 6 days, goal: 50e6});

        // check variables were set correctly

        (uint256 _deadline, uint256 _goal, uint256 _amountRaised, bool _claimed, address _creator) =
            ethFlo.fundraisers(id);

        assertEq(_deadline, block.timestamp + 6 days, "Deadline not set correctly");
        assertEq(_goal, 50e6, "Goal not set correctly");
        assertEq(_amountRaised, 0, "Amount raised not correct");
        assertEq(_claimed, false, "Bool not set correctly");
        assertEq(_creator, CREATOR, "Creator not set correctly");
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

    function test_event_CreateFundraiser_createFundraiser_success() public {
        vm.expectEmit(true, false, false, true);
        vm.startPrank(CREATOR);
        emit EthFlo.CreateFundraiser(CREATOR, block.timestamp + 6 days, 50e6);
        ethFlo.createFundraiser(block.timestamp + 6 days, 50e6);
    }

    // donate TESTS

    function test_donate_receiveDonation_success() public {
        _createFunctionForTests(block.timestamp + 5 days, 30e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 0);
        console.log("EthFlo balance before donation", USDT.balanceOf(address(ethFlo)));
        vm.startPrank(DONOR);
        USDT.forceApprove(address(ethFlo), 35e6);
        ethFlo.donate(1, 35e6);

        // Check aUSDT balance of ethFlo contract
        // address aUSDT_ADDRESS = IPool(AAVE_POOL).getReserveData(USDT_ADDRESS).aTokenAddress;
        uint256 aUSDTBalance = IERC20(aUSDT_ADDRESS).balanceOf(address(ethFlo));

        assertEq(aUSDTBalance, 35e6);
        console.log("EthFlo USDT balance after donation", USDT.balanceOf(address(ethFlo)));
        console.log("EthFlo aUSDT balance after donation", aUSDTBalance);

        (,, uint256 amountRaised,,) = ethFlo.fundraisers(1);
        console.log("Fundraiser 1 amount raised", amountRaised);
        console.log("Donor's donation amount", ethFlo.donorsAmount(DONOR, 1));
    }

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

    function test_event_Donation_donate_success() public {
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

        uint256 aUSDTBalance = IERC20(aUSDT_ADDRESS).balanceOf(address(ethFlo));

        assertEq(aUSDTBalance, 25e6);
        console.log("aUSDT balance after donation", aUSDTBalance);
        console.log("EthFlo balance after donation", USDT.balanceOf(address(ethFlo)));
        vm.stopPrank();
        // creator withdraw
        vm.startPrank(CREATOR);
        vm.warp(block.timestamp + 100 days);
        ethFlo.creatorWithdraw(1);

        aUSDTBalance = IERC20(aUSDT_ADDRESS).balanceOf(address(ethFlo));

        console.log("EthFlo balance after withdraw", USDT.balanceOf(address(ethFlo)));
        console.log("aUSDT balance after withdraw", aUSDTBalance);
    }

    function test_creatorWithdraw_fail_EthFlo_IncorrectFundraiserOwner() public {
        // create fundraiser
        _createFunctionForTests(block.timestamp + 5 days, 20e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 0);
        // make donation
        vm.startPrank(DONOR);
        USDT.forceApprove(address(ethFlo), 25e6);
        ethFlo.donate(1, 25e6);

        uint256 aUSDTBalance = IERC20(aUSDT_ADDRESS).balanceOf(address(ethFlo));
        assertEq(aUSDTBalance, 25e6);
        console.log("aUSDT balance after donation", aUSDTBalance);

        vm.stopPrank();
        // creator withdraw
        vm.warp(block.timestamp + 100 days);
        vm.expectRevert(EthFlo.EthFlo_IncorrectFundraiserOwner.selector);
        ethFlo.creatorWithdraw(1);
    }

    function test_creatorWithdraw_fail_EthFlo_AlreadyClaimed() public {
        // create fundraiser
        _createFunctionForTests(block.timestamp + 5 days, 20e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 0);
        // make donation
        vm.startPrank(DONOR);
        USDT.forceApprove(address(ethFlo), 25e6);
        ethFlo.donate(1, 25e6);

        uint256 aUSDTBalance = IERC20(aUSDT_ADDRESS).balanceOf(address(ethFlo));
        assertEq(aUSDTBalance, 25e6);
        console.log("aUSDT balance after donation", aUSDTBalance);

        vm.stopPrank();
        // creator withdraw
        vm.startPrank(CREATOR);
        vm.warp(block.timestamp + 100 days);
        ethFlo.creatorWithdraw(1);

        vm.expectRevert(EthFlo.EthFlo_AlreadyClaimed.selector);
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

        uint256 aUSDTBalance = IERC20(aUSDT_ADDRESS).balanceOf(address(ethFlo));
        assertEq(aUSDTBalance, 25e6);
        console.log("aUSDT balance after donation", aUSDTBalance);

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

        uint256 aUSDTBalance = IERC20(aUSDT_ADDRESS).balanceOf(address(ethFlo));
        assertEq(aUSDTBalance, 25e6);
        console.log("aUSDT balance after donation", aUSDTBalance);

        vm.stopPrank();
        // creator withdraw
        vm.warp(block.timestamp + 100 days);
        vm.startPrank(CREATOR);
        vm.expectRevert(EthFlo.EthFlo_GoalNotReached.selector);
        ethFlo.creatorWithdraw(1);
    }

    function test_creatorWithdraw_checkAdminFee_success() public {
        // create fundraiser
        _createFunctionForTests(block.timestamp + 5 days, 20e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 0);
        // make donation
        vm.startPrank(DONOR);
        USDT.forceApprove(address(ethFlo), 25e6);
        ethFlo.donate(1, 25e6);

        uint256 aUSDTBalance = IERC20(aUSDT_ADDRESS).balanceOf(address(ethFlo));
        assertEq(aUSDTBalance, 25e6);
        console.log("aUSDT balance after donation", aUSDTBalance);

        vm.stopPrank();
        // creator withdraw
        vm.startPrank(CREATOR);
        vm.warp(block.timestamp + 100 days);

        ethFlo.creatorWithdraw(1);
        aUSDTBalance = IERC20(aUSDT_ADDRESS).balanceOf(address(ethFlo));
        // admin fee is 5%
        uint256 amountRemainingAfterWithdraw = 25e6 * 5 / 100;
        assertEq(USDT.balanceOf(address(ethFlo)), 0);
        console.log("Fee deducted:", amountRemainingAfterWithdraw);
        console.log("aUSDT balance after withdraw", aUSDTBalance);
    }

    function test_event_FundsWithdrawn_creatorWithdraw_success() public {
        // create fundraiser
        _createFunctionForTests(block.timestamp + 5 days, 20e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 0);
        // make donation
        vm.startPrank(DONOR);
        USDT.forceApprove(address(ethFlo), 25e6);
        ethFlo.donate(1, 25e6);

        uint256 aUSDTBalance = IERC20(aUSDT_ADDRESS).balanceOf(address(ethFlo));
        assertEq(aUSDTBalance, 25e6);
        console.log("aUSDT balance after donation", aUSDTBalance);

        vm.stopPrank();
        // creator withdraw and test event
        vm.expectEmit(true, true, false, true);
        vm.startPrank(CREATOR);
        vm.warp(block.timestamp + 100 days);
        // test event - calculate amount remaining after fee (5%)
        uint256 amountAfterFeeTaken = 25e6 * 95 / 100;
        emit EthFlo.FundsWithdrawn(CREATOR, 1, amountAfterFeeTaken);
        ethFlo.creatorWithdraw(1);
        console.log("EthFlo balance after withdraw", USDT.balanceOf(address(ethFlo)));
    }

    // claimRewardForSuccessfulFundraiser TESTS

    function test_claimRewardForSuccessfulFundraiser_success() public {
        // create fundraiser
        _createFunctionForTests(block.timestamp + 5 days, 20e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 0);
        // make donation
        vm.startPrank(DONOR);
        _donateFunctionForTests(1, 25e6);
        console.log("EthFlo balance after donation", USDT.balanceOf(address(ethFlo)));
        // claim reward
        vm.warp(block.timestamp + 100 days);
        ethFlo.claimRewardForSuccessfulFundraiser(1);
        assertEq(ethFlo.balanceOf(DONOR), 25e18);
        console.log("Donors EthFlo balance", ethFlo.balanceOf(DONOR));
    }

    function test_claimRewardForSuccessfulFundraiser_fail_EthFlo_NothingToClaim() public {
        // create fundraiser
        _createFunctionForTests(block.timestamp + 5 days, 20e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 0);
        // make donation
        vm.startPrank(DONOR);
        _donateFunctionForTests(1, 25e6);
        vm.stopPrank();
        console.log("EthFlo balance after donation", USDT.balanceOf(address(ethFlo)));
        // claim reward
        vm.warp(block.timestamp + 100 days);
        vm.expectRevert(EthFlo.EthFlo_NothingToClaim.selector);
        ethFlo.claimRewardForSuccessfulFundraiser(1);
        assertEq(ethFlo.balanceOf(DONOR), 0);
        console.log("Donors EthFlo balance", ethFlo.balanceOf(DONOR));
    }

    function test_claimRewardForSuccessfulFundraiser_fail_EthFlo_FundraiserStillActive() public {
        // create fundraiser
        _createFunctionForTests(block.timestamp + 5 days, 20e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 0);
        // make donation
        vm.startPrank(DONOR);
        _donateFunctionForTests(1, 25e6);
        console.log("EthFlo balance after donation", USDT.balanceOf(address(ethFlo)));
        // claim reward
        // vm.warp(20e12);
        vm.expectRevert(EthFlo.EthFlo_FundraiserStillActive.selector);
        ethFlo.claimRewardForSuccessfulFundraiser(1);
        assertEq(ethFlo.balanceOf(DONOR), 0);
        console.log("Donors EthFlo balance", ethFlo.balanceOf(DONOR));
    }

    function test_claimRewardForSuccessfulFundraiser_fail_EthFlo_FundraiserWasUnsuccessful() public {
        // create fundraiser
        _createFunctionForTests(block.timestamp + 5 days, 20e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 0);
        // make donation
        vm.startPrank(DONOR);
        _donateFunctionForTests(1, 15e6);
        console.log("EthFlo balance after donation", USDT.balanceOf(address(ethFlo)));
        // claim reward
        vm.warp(block.timestamp + 100 days);
        vm.expectRevert(EthFlo.EthFlo_FundraiserWasUnsuccessful.selector);
        ethFlo.claimRewardForSuccessfulFundraiser(1);
        assertEq(ethFlo.balanceOf(DONOR), 0);
        console.log("Donors EthFlo balance", ethFlo.balanceOf(DONOR));
    }

    function test_event_TokensClaimed_claimRewardForSuccessfulFundraiser_success() public {
        // create fundraiser
        _createFunctionForTests(block.timestamp + 5 days, 20e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 0);
        // make donation
        vm.startPrank(DONOR);
        _donateFunctionForTests(1, 25e6);
        console.log("EthFlo balance after donation", USDT.balanceOf(address(ethFlo)));
        // claim reward and test event
        vm.expectEmit(true, true, false, true);
        vm.warp(block.timestamp + 100 days);
        emit EthFlo.TokensClaimed(DONOR, 1, 25e18);
        ethFlo.claimRewardForSuccessfulFundraiser(1);

        console.log("Donors EthFlo balance", ethFlo.balanceOf(DONOR));
    }

    // withdrawDonationFromUnsuccessfulFundraiser TESTS

    function test_withdrawDonationFromUnsuccessfulFundraiser_success() public {
        // create fundraiser
        _createFunctionForTests(block.timestamp + 5 days, 30e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 0);
        console.log("EthFlo balance before donation", USDT.balanceOf(address(ethFlo)));
        // make donation
        vm.startPrank(DONOR);
        _donateFunctionForTests(1, 25e6);

        uint256 aUSDTBalance = IERC20(aUSDT_ADDRESS).balanceOf(address(ethFlo));
        assertEq(aUSDTBalance, 25e6);
        console.log("aUSDT balance after donation", aUSDTBalance);

        // withdraw donation
        vm.warp(block.timestamp + 100 days);
        ethFlo.withdrawDonationFromUnsuccessfulFundraiser(1);
        vm.stopPrank();

        aUSDTBalance = IERC20(aUSDT_ADDRESS).balanceOf(address(ethFlo));
        console.log("EthFlo aUSD balance after withdraw", aUSDTBalance);
    }

    function test_withdrawDonationFromUnsuccessfulFundraiser_fail_EthFlo_NothingToClaim() public {
        // create fundraiser
        _createFunctionForTests(block.timestamp + 5 days, 30e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 0);
        console.log("EthFlo balance before donation", USDT.balanceOf(address(ethFlo)));
        // make donation
        vm.startPrank(DONOR);
        _donateFunctionForTests(1, 25e6);

        uint256 aUSDTBalance = IERC20(aUSDT_ADDRESS).balanceOf(address(ethFlo));
        assertEq(aUSDTBalance, 25e6);
        console.log("aUSDT balance after donation", aUSDTBalance);

        vm.stopPrank();
        // withdraw donation
        vm.warp(block.timestamp + 100 days);
        vm.expectRevert(EthFlo.EthFlo_NothingToClaim.selector);
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
        _donateFunctionForTests(1, 35e6);

        uint256 aUSDTBalance = IERC20(aUSDT_ADDRESS).balanceOf(address(ethFlo));
        assertEq(aUSDTBalance, 35e6);
        console.log("aUSDT balance after donation", aUSDTBalance);

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
        _donateFunctionForTests(1, 35e6);

        uint256 aUSDTBalance = IERC20(aUSDT_ADDRESS).balanceOf(address(ethFlo));
        assertEq(aUSDTBalance, 35e6);
        console.log("aUSDT balance after donation", aUSDTBalance);

        // withdraw donation
        vm.warp(block.timestamp + 100 days);
        vm.expectRevert(EthFlo.EthFlo_FundraiserWasSuccessful.selector);
        ethFlo.withdrawDonationFromUnsuccessfulFundraiser(1);
    }

    function test_event_DonorFundsReturned_withdrawDonationFromUnsuccessfulFundraiser_success() public {
        // create fundraiser
        _createFunctionForTests(block.timestamp + 5 days, 30e6);
        assertEq(USDT.balanceOf(address(ethFlo)), 0);
        console.log("EthFlo balance before donation", USDT.balanceOf(address(ethFlo)));
        // make donation
        vm.startPrank(DONOR);
        _donateFunctionForTests(1, 25e6);

        uint256 aUSDTBalance = IERC20(aUSDT_ADDRESS).balanceOf(address(ethFlo));
        assertEq(aUSDTBalance, 25e6);
        console.log("aUSDT balance after donation", aUSDTBalance);

        // withdraw donation and test event
        vm.expectEmit(true, true, false, true);
        vm.warp(block.timestamp + 100 days);
        emit EthFlo.DonorFundsReturned(DONOR, 1, 25e6);
        ethFlo.withdrawDonationFromUnsuccessfulFundraiser(1);
        vm.stopPrank();
        console.log("EthFlo balance after withdraw", USDT.balanceOf(address(ethFlo)));

        aUSDTBalance = IERC20(aUSDT_ADDRESS).balanceOf(address(ethFlo));
        console.log("EthFlo aUSD balance after withdraw", aUSDTBalance);
    }
}
