# Crowdfunding Platform

**Crowdfunding smart contracts built with Solidity and Foundry.**

## About

Fund raising platform that allows users to create a fund raiser or donate to other users and gain ERC20 tokens as rewards in proportion to their contribution. 


## What do we want it to do?

1. Create fundRaiser() Function with a goal and a deadline.
   
2. If goal is reached before deadline - allow wallet that created that specific fund raiser to withdraw those funds.
   
3. If goal is not reached - allow creator to extend and allow donors to either withdraw, or to donate anyways.

4. Distribute project tokens (an ERC20 token - OpenZeppelin ERC20) to contributors as rewards.

5. Decide on rewards...