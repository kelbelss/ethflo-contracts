// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title EthFlo Contract
 * @author Kelly Smulian
 * @notice This contract is for creating a crowdfunding program
 * @dev
 */
contract EthFlo {
    // GO SLOW AND TEST AS YOU GO
    // CEI: Checks, Effects, Interactions

    using SafeERC20 for IERC20;

    error EthFlo_DeadlineError();
    error EthFlo_GoalError();
    error EthFlo_FundraiserDoesNotExist();
    error EthFlo_FundraiserDeadlineHasPassed();
    error EthFlo_MinimumDonationNotMet();
    error EthFlo_FundraiserStillActive();
    error EthFlo_GoalNotReached();
    error EthFlo_IncorrectFundraiserOwner();

    struct Fundraiser {
        address creatorAddr;
        uint256 deadline;
        uint256 goal;
        uint256 amountRaised;
    }

    mapping(uint256 fundraiserId => Fundraiser fundraiser) public fundraisers;
    mapping(address donor => mapping(uint256 id => uint256 amount)) public donorsAmount;

    uint256 public constant MIN_DURATION = 5 days;
    uint256 public constant MAX_DURATION = 90 days; // $10
    uint256 public constant MIN_GOAL = 10e6; // $10
    uint256 public constant MAX_GOAL = 100_000_000e6; // $100 million
    uint256 public constant MINIMUM_DONATION = 10000000; // $10
    uint256 public constant ADMIN_FEE = 5; // 5%
    IERC20 public immutable USDT;
    uint256 public s_fundraiserCount;

    event CreateFundraiser(address indexed creatorAddr, uint256 deadline, uint256 goal);
    event Donation(address indexed donorAddr, uint256 indexed fundraiserId, uint256 amount);
    event FundsWithdrawn(address indexed creatorAddr, uint256 indexed fundraiserId, uint256 amountReceived);

    constructor(address _usdtAddress) {
        USDT = IERC20(_usdtAddress);
    }

    function createFundraiser(uint256 _deadline, uint256 _goal) external returns (uint256) {
        // Checks for deadline and goal

        uint256 duration = _deadline - block.timestamp;

        if (duration < MIN_DURATION || duration > MAX_DURATION) {
            revert EthFlo_DeadlineError();
        }

        if (_goal < MIN_GOAL || _goal > MAX_GOAL) {
            revert EthFlo_GoalError();
        }

        uint256 id = s_fundraiserCount;
        ++id;

        fundraisers[id] = Fundraiser(msg.sender, _deadline, _goal, 0);

        s_fundraiserCount = id;

        emit CreateFundraiser(msg.sender, _deadline, _goal);

        return id;
    }

    function donate(uint256 _fundraiserId, uint256 _amountDonated) external {
        Fundraiser memory selectedFundraiser = fundraisers[_fundraiserId];

        // Checks: 1. if fundraiser exists
        if (selectedFundraiser.goal == 0) {
            revert EthFlo_FundraiserDoesNotExist();
        }

        // Checks: 2. if fundraiser is still active
        if (block.timestamp > selectedFundraiser.deadline) {
            revert EthFlo_FundraiserDeadlineHasPassed();
        }

        // Checks: 3. if minimum amount is reached
        if (_amountDonated < MINIMUM_DONATION) {
            revert EthFlo_MinimumDonationNotMet();
        }

        // Mapping - donor projects mapping - address to array of id projects donated too with amount
        //      mapping (address donor => idArray[] and amounts) public donorsDifferentDonationsIds;

        // donorsAmount Mapping update - fundraisers id and amount donated by donor
        donorsAmount[msg.sender][_fundraiserId] = _amountDonated;

        // fundraiser Mapping update - amount raised per fundraiser
        fundraisers[_fundraiserId].amountRaised += _amountDonated;

        // Receive funds
        USDT.safeTransferFrom(msg.sender, address(this), _amountDonated);

        // Event
        emit Donation(msg.sender, _fundraiserId, _amountDonated);
    }

    function yieldStuff() internal {}

    function creatorWithdraw(uint256 _fundraiserId) public {
        // only creator
        /**
         * TODO: check user has reached goal at deadline
         *     deduct fee - 10% for unverified, 2% for verified - 5% for V1
         *     calculate split of yield amount - V1 admin gets 100%
         */
        Fundraiser memory selectedFundraiser = fundraisers[_fundraiserId];

        // Check: goal is reached by deadline
        address creator = selectedFundraiser.creatorAddr;
        uint256 goal = selectedFundraiser.goal;
        uint256 deadline = selectedFundraiser.deadline;
        uint256 amountRaised = selectedFundraiser.amountRaised;

        // Checks: 1. if caller is the creator
        if (msg.sender != creator) {
            revert EthFlo_IncorrectFundraiserOwner();
        }

        // Checks: 2. if deadline has been reached
        if (block.timestamp < deadline) {
            revert EthFlo_FundraiserStillActive();
        }

        // Checks: 3. if goal is reached
        if (amountRaised < goal) {
            revert EthFlo_GoalNotReached();
        }

        // Deduct 5% fee
        uint256 amountAfterFee = amountRaised * (100 - ADMIN_FEE) / 100;

        // Send funds
        USDT.safeTransfer(msg.sender, amountAfterFee);

        // Event
        emit FundsWithdrawn(msg.sender, _fundraiserId, amountAfterFee);
    }

    function claimRewardForSuccessfulFundraiser() public {
        // mint tokens to donators in proportion to donation - only mint when goal is reached - let them claim them (and they pay gas)
    }

    function withdrawDonationFromUnsuccessfulFundraiser() public {
        // return amount to donor if deadline not reached - claim refund (so they pay gas)
    }
}
