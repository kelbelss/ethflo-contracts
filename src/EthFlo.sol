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

    struct Fundraiser {
        address creatorAddr;
        uint256 deadline;
        uint256 goal;
    }

    mapping(uint256 fundraiserId => Fundraiser fundraiser) public fundraisers;

    uint256 public constant MIN_GOAL = 10e6; // $10
    uint256 public constant MAX_GOAL = 100_000_000e6; // $100 million
    uint256 public constant MINIMUM_DONATION = 10000000; // $10
    IERC20 public immutable USDT;
    uint256 public s_fundraiserCount;

    event CreateFundraiser(address indexed creatorAddr, uint256 deadline, uint256 goal);
    event Donation(address indexed donorAddr, uint256 indexed fundraiserId, uint256 amount);

    constructor(address _usdtAddress) {
        USDT = IERC20(_usdtAddress);
    }

    function createFundraiser(address _creatorAddr, uint256 _deadline, uint256 _goal) external returns (uint256) {
        // Checks for deadline and goal

        uint256 duration = _deadline - block.timestamp;

        if (duration < 5 days || duration > 90 days) {
            revert EthFlo_DeadlineError();
        }

        if (_goal < MIN_GOAL || _goal > MAX_GOAL) {
            revert EthFlo_GoalError();
        }

        uint256 id = s_fundraiserCount;
        ++id;

        fundraisers[id] = Fundraiser(_creatorAddr, _deadline, _goal);

        s_fundraiserCount = id;

        emit CreateFundraiser(_creatorAddr, _deadline, _goal);

        return id;
    }

    function donate(uint256 _fundraiserId, uint256 _amountDonated) external {
        /**
         * TODO:
         * add donor to mapping of donors per fundraiser - emit event with donor address and index them for list at the end
         *      mapping(address donor => mapping(address project => uint256 amount)) public donations;
         *      uint256 donorsDonationToFundraiser = donations[donor][fundraiser];
         */

        //  donor projects mapping - address to array of id projects donated too
        // other mapping -> above mapping and then to amount

        Fundraiser memory selectedFundraiser = fundraisers[_fundraiserId];

        // Checks: 1. if fundraiser exists
        if (selectedFundraiser.goal < MIN_GOAL) {
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

        // Mapping - donors personal donations lis with ID and amounts

        // Mapping - fundraisers list of donors with amount

        // Receive funds
        USDT.safeTransferFrom(msg.sender, address(this), _amountDonated);

        // Event
        emit Donation(msg.sender, _fundraiserId, _amountDonated);
    }

    function yieldStuff() internal {}

    function creatorWithdraw() public { // only creator
        /**
         * TODO: check user has reached goal at deadline
         *     deduct fee - 10% for unverified, 2% for verified - 5% for V1
         *     calculate split of yield amount - V1 admin gets 100%
         */
    }

    function claimRewardForSuccessfulFundraiser() public {
        // mint tokens to donators in proportion to donation - only mint when goal is reached - let them claim them (and they pay gas)
    }

    function withdrawDonationFromUnsuccessfulFundraiser() public {
        // return amount to donor if deadline not reached - claim refund (so they pay gas)
    }
}
