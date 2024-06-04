// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/**
 * @title Crowdfund Contract
 * @author Kelly Smulian
 * @notice This contract is for creating a crowdfunding program
 * @dev
 */
contract Crowdfund {
    // GO SLOW AND TEST AS YOU GO
    // CEI: Checks, Effects, Interactions

    struct Fundraiser {
        address creatorAddr;
        string name;
        uint256 deadline;
        uint256 goal;
    }

    Fundraiser[] public listOfFundraisers;

    // constructor() erc20 - set up

    function createFundraiser(address _creatorAddr, string memory _name, uint256 _deadline, uint256 _goal) external {
        // TODO: check if address already has a fundraiser

        // Push parameters to Fundraiser array
        listOfFundraisers.push(Fundraiser(_creatorAddr, _name, _deadline, _goal));
    }

    function creatorVerification() public {
        // set up verification to prevent sybil attacks - 10% fee for unverified, 2% fee for verified
    }

    function donate() public {
        // TODO: mint tokens to donators in proportion to donation - only mint when goal is reached
    }

    function creatorWithdraw() public { // only creator
        /**
         * TODO: check user has reached goal at/before deadline
         *     if goal not reached - allow creator to extend and allow donors to either withdraw, or to donate anyways.
         *     deduct fee - 10% for unverified, 2% for verified
         */
    }

    function donorWithdraw() public {
        // allow donor to withdraw if goal is not reached
    }
}
