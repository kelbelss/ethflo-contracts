# EthFlo 

**EthFlo, derived from the Latin word 'Efflo' meaning 'to blossom', is a crowdfunding platform which embodies the spirit of potential and growth, utilising smart contracts built with Solidity and Foundry.**


## About

EthFlo is a fundraising platform that allows users to create a fundraiser or donate to other users and gain ERC20 tokens as rewards in proportion to their contribution.


- **Create Fundraiser**: Users can create a fundraiser with a duration of 5 - 90 days and a goal of 10 - 100 million USDT. 
- **Donate**: Donors can donate any amount over 10 USDT. The donation will immediately be supplied to the UDST Aave pool and start earning yield.
- **Creator Withdraw**: If a fundraiser reaches its goal within the provided deadline, the creator will be allowed to withdraw the donated USDT. A 5% fee will be taken to prevent Sybil attacks. The amount owed will be withdrawn from Aave and sent to the creator.
- **Donor Token Claim**: Once a fundraiser has met its goal in the specified deadline, each donor will be able to claim EthFlo tokens in proportion to their donation. 
- **Donor Donation Claim**: If a fundraiser is not successful, each donor will be able to withdraw their donated amount by claiming it back. This USDT will come directly from Aave.

## Contract Address

The EthFlo contract is deployed on the Sepolia network. You can view the contract on Etherscan using the following link:

[EthFlo Contract on Sepolia Etherscan](https://sepolia.etherscan.io/address/0x90F897AF3c3780A68eB198ddAc574C994911604b)

## Test Coverage

| File                      | % Lines         | % Statements    | % Branches      | % Funcs       |
|---------------------------|-----------------|-----------------|-----------------|---------------|
| src/EthFlo.sol            | ![green](https://via.placeholder.com/15/008000/000000?text=+) 100.00% (74/74) | ![green](https://via.placeholder.com/15/008000/000000?text=+) 100.00% (84/84) | ![green](https://via.placeholder.com/15/008000/000000?text=+) 100.00% (30/30) | ![green](https://via.placeholder.com/15/008000/000000?text=+) 100.00% (7/7) |
| Total                     | ![green](https://via.placeholder.com/15/008000/000000?text=+) 100.00% (74/74) | ![green](https://via.placeholder.com/15/008000/000000?text=+) 100.00% (84/84) | ![green](https://via.placeholder.com/15/008000/000000?text=+) 100.00% (30/30) | ![green](https://via.placeholder.com/15/008000/000000?text=+) 100.00% (7/7) |


## V2 Plans

1. Allow fundraiser creators to extend their fundraiser if goal is not met by the deadline. An option will be given to donors at this point if they want to claim their donation back or allow the fundraiser to continue.
2. Allow fundraiser creators to verify themselves - this will allow the Sybil attack fee to be removed.
3. Decide on the value for token holders (perks, yield cut, badges, etc).