# Crowdfunding Platform

**Crowdfunding smart contracts built with Solidity and Foundry.**

## About

Fund raising platform that allows users to create a fund raiser or donate to other users and gain ERC20 tokens as rewards in proportion to their contribution. 


## What do I want it to do?

1. Create createFundraiser() Function with a goal, a deadline and a name. Have a struct for Fundraisers and an array of creator addresses which can be mapped to the fundraisers. 

2. Verify fundraisers to prevent sybil attacks farming ERC20 token reward - 10% fee for unverified, 2% fee for verified.
   
3. If goal is reached before deadline - allow wallet that created that specific fund raiser to withdraw those funds.
   
4. If goal is not reached - allow creator to extend and allow donors to either withdraw, or to donate anyways.

5. Distribute project tokens (an ERC20 token - OpenZeppelin ERC20) to contributors as rewards.

6. Decide on rewards...