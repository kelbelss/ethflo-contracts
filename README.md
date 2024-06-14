# EthFlo 

**EthFlo, derived from the Latin word 'Efflo' meaning 'to blossom', is a crowdfunding platform which embodies the spirit of potential and growth, utilising smart contracts built with Solidity and Foundry.**

## About

Fund raising platform that allows users to create a fund raiser or donate to other users and gain ERC20 tokens as rewards in proportion to their contribution. 


## What do I want it to do?

1. Create createFundraiser() Function with a goal, and a deadline. Add ID to each fundraiser. Add checks for deadline and goals.

2. donate() - set minimum donate amount, add mapping of donor and their amount for that fundraiser, add funds to yield amount. Use USDT.
   
3. Donor money - add funds to general Aave pot to earn yield until deadline. 
   
4. If goal is reached - allow wallet that created that specific fund raiser to withdraw those funds and pay 5% fee to prevent sybil attack. Give creators the donors addresses for possible future rewards. Split of yield logic. creatorWithdraw()

5. If goal not reached - return amount to donors via claim so they pay gas. withdrawDonationFromUnsuccessfulFundraiser()

6. Distribute project utility tokens (an ERC20 token - OpenZeppelin ERC20) to donors as rewards via claim - claimRewardForSuccessfulFundraiser().

7. Decide on rewards... badges, perks, yield cut?

8. V2 - allow fundraisers to mint their own token and donors can decide between crowdfund token or fundraiser token. Another V2 option - allow fundraisers to extend period if goal not reached and donors can decide to remove donation or not. V2 - setCreatorVerification() - Verify fundraisers to prevent sybil attacks farming ERC20 token reward - 10% fee for unverified, 2% fee for verified.