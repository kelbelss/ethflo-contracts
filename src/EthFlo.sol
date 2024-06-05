// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/**
 * @title EthFlo Contract
 * @author Kelly Smulian
 * @notice This contract is for creating a crowdfunding program
 * @dev
 */
contract EthFlo {
    // GO SLOW AND TEST AS YOU GO
    // CEI: Checks, Effects, Interactions

    uint256 s_fundraiserCount;

    struct Fundraiser {
        address creatorAddr;
        uint256 deadline;
        uint256 goal;
    }

    // Fundraiser[] public listOfFundraisers;

    mapping(uint256 fundraiserId => Fundraiser) public fundraisers;
    // mapping(address creator => uint256 fundraiserId) public creatorToFundraiserId;

    // if(creatorToFundraiserId[msg.sender] > 0) revert YouAlreadyHaveOneLol();

    // constructor() erc20 - set up

    function createFundraiser(address _creatorAddr, uint256 _deadline, uint256 _goal) external {
        uint256 id = s_fundraiserCount;
        ++id;

        fundraisers[id] = Fundraiser(_creatorAddr, _deadline, _goal);

        s_fundraiserCount = id;
    }

    // function setCreatorVerification() public {
    // set up verification to prevent sybil attacks - 10% fee for unverified, 2% fee for verified
    // true or false
    // Make 5% fee for V1
    // }

    function donate() public {
        /**
         * TODO: set minimum donation amount
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
