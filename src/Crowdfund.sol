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

    address payable[] private s_creator;

    struct Fundraiser {
        string name;
        uint256 duration;
        uint256 goal;
    }

    Fundraiser[] public listOfFundraisers;

    function createFundraiser(string memory _name, uint256 _duration, uint256 _goal) external {}
}
