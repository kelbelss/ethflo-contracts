// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title EthFlo Contract
 * @author Kelly Smulian
 * @notice This contract is for creating a crowdfunding program
 * @dev
 */
contract EthFlo {
    // GO SLOW AND TEST AS YOU GO
    // CEI: Checks, Effects, Interactions

    error EthFlo_DeadlineError();
    error EthFlo_GoalError();

    event CreateFundraiser(address indexed creatorAddr, uint256 deadline, uint256 goal);

    uint256 public s_fundraiserCount;

    struct Fundraiser {
        address creatorAddr;
        uint256 deadline;
        uint256 goal;
    }

    mapping(uint256 fundraiserId => Fundraiser) public fundraisers;

    // constructor() erc20 - set up

    function createFundraiser(address _creatorAddr, uint256 _deadline, uint256 _goal) external returns (uint256) {
        // Checks for deadline and goal

        if (_deadline < 5 days || _deadline > 90 days) {
            revert EthFlo_DeadlineError();
        }

        if (_goal < 10 || _goal > 100000000) {
            revert EthFlo_GoalError();
        }

        uint256 id = s_fundraiserCount;
        ++id;

        fundraisers[id] = Fundraiser(_creatorAddr, _deadline, _goal);

        s_fundraiserCount = id;

        emit CreateFundraiser(_creatorAddr, _deadline, _goal);

        return id;
    }

    function donate() public {
        /**
         * TODO: import USDT contracts
         * set minimum donation amount
         * add donor to mapping of donors per fundraiser - emit event with donor address and index them for list at the end
         *      mapping(address donor => mapping(address project => uint256 amount)) public donations;
         *      uint256 donorsDonationToFundraiser = donations[donor][fundraiser];
         * yield function
         */
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
