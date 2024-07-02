// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPool} from "@aave/contracts/interfaces/IPool.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title EthFlo Contract
 * @author Kelly Smulian
 * @notice This contract is for creating a crowdfunding program
 * @dev
 */
contract EthFlo is ERC20, Ownable {
    using SafeERC20 for IERC20;

    error EthFlo_NoFeesAndYieldAvailable();
    error EthFlo_DeadlineError();
    error EthFlo_GoalError();
    error EthFlo_FundraiserDoesNotExist();
    error EthFlo_FundraiserDeadlineHasPassed();
    error EthFlo_MinimumDonationNotMet();
    error EthFlo_FundraiserStillActive();
    error EthFlo_GoalNotReached();
    error EthFlo_IncorrectFundraiserOwner();
    error EthFlo_NotYourDonation();
    error EthFlo_FundraiserWasUnsuccessful();
    error EthFlo_FundraiserWasSuccessful();

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
    uint256 public constant USDT_TO_ETHFLO_DECIMALS = 1e12;
    address public aUSDT_ADDRESS;
    IERC20 public immutable USDT;
    IPool public immutable AAVE_POOL;
    uint256 public s_fundraiserCount;
    uint256 public s_totalEscrowedFunds;

    // AAVE INTERACTION
    // address constant AAVE_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    // address constant USDT_ADDRESS = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    event CreateFundraiser(address indexed creatorAddr, uint256 deadline, uint256 goal);
    event Donation(address indexed donorAddr, uint256 indexed fundraiserId, uint256 amount);
    event FundsWithdrawn(address indexed creatorAddr, uint256 indexed fundraiserId, uint256 amountReceived);
    event DonorFundsReturned(address indexed donorAddr, uint256 indexed fundraiserId, uint256 amount);
    event TokensClaimed(address indexed donorAddr, uint256 indexed fundraiserId, uint256 amountClaimed);

    constructor(address _usdtAddress, address _aavePool) ERC20("EthFlo", "ETHFLO") Ownable(msg.sender) {
        USDT = IERC20(_usdtAddress);
        AAVE_POOL = IPool(_aavePool);
        aUSDT_ADDRESS = IPool(AAVE_POOL).getReserveData(address(USDT)).aTokenAddress;
    }

    function withdrawFeesAndYield(address _to) external onlyOwner {
        uint256 aUSDTBalance = IERC20(aUSDT_ADDRESS).balanceOf(address(this));

        uint256 feesAndYield = aUSDTBalance - s_totalEscrowedFunds;

        if (feesAndYield == 0) {
            revert EthFlo_NoFeesAndYieldAvailable();
        }

        AAVE_POOL.withdraw(address(USDT), feesAndYield, _to);
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

        // mapping (uint256 id => address donorAddr) public donorDonated;
        // donorDonated[_fundraiserId] = msg.sender;

        // Receive funds
        USDT.safeTransferFrom(msg.sender, address(this), _amountDonated);

        // Update accounting
        s_totalEscrowedFunds += _amountDonated;

        // Send funds to AAVE to earn yield
        IERC20(USDT).forceApprove(address(AAVE_POOL), _amountDonated);
        AAVE_POOL.supply(address(USDT), _amountDonated, address(this), 0);

        // Event
        emit Donation(msg.sender, _fundraiserId, _amountDonated);
    }

    function creatorWithdraw(uint256 _fundraiserId) external {
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

        // Withdraw funds from AAVE and send to EthFlo
        AAVE_POOL.withdraw(address(USDT), amountAfterFee, msg.sender);

        // Send funds to creator
        // USDT.safeTransfer(msg.sender, amountAfterFee);

        // Update accounting - deduct full amount donated from escrow to account for fees
        s_totalEscrowedFunds -= amountRaised;

        // Event
        emit FundsWithdrawn(msg.sender, _fundraiserId, amountAfterFee);
    }

    function claimRewardForSuccessfulFundraiser(uint256 _fundraiserId) external {
        // mint tokens to donators in proportion to donation - only mint when goal is reached - let them claim them (and they pay gas)
        uint256 amountDonated = donorsAmount[msg.sender][_fundraiserId];

        Fundraiser memory selectedFundraiser = fundraisers[_fundraiserId];
        uint256 deadline = selectedFundraiser.deadline;
        uint256 goal = selectedFundraiser.goal;
        uint256 amountRaised = selectedFundraiser.amountRaised;

        // Checks

        // Check 1. if caller is the donor
        if (amountDonated == 0) {
            revert EthFlo_NotYourDonation();
        }

        // Checks: 2. check if fundraiser deadline has passed
        if (block.timestamp < deadline) {
            revert EthFlo_FundraiserStillActive();
        }

        // Checks: 3. if fundraiser succeeded
        if (amountRaised < goal) {
            revert EthFlo_FundraiserWasUnsuccessful();
        }

        uint256 amountOfTokens = amountDonated * USDT_TO_ETHFLO_DECIMALS;

        _mint(msg.sender, amountOfTokens);

        // Event
        emit TokensClaimed(msg.sender, _fundraiserId, amountOfTokens);
    }

    function withdrawDonationFromUnsuccessfulFundraiser(uint256 _fundraiserId) external {
        // return amount to donor if deadline not reached - claim refund (so they pay gas)
        uint256 amountToBeReturned = donorsAmount[msg.sender][_fundraiserId];

        Fundraiser memory selectedFundraiser = fundraisers[_fundraiserId];
        uint256 deadline = selectedFundraiser.deadline;
        uint256 goal = selectedFundraiser.goal;
        uint256 amountRaised = selectedFundraiser.amountRaised;

        // Checks

        // Checks: 1. if caller is the donor
        if (amountToBeReturned == 0) {
            revert EthFlo_NotYourDonation();
        }

        // Checks: 2. check if fundraiser deadline has passed
        if (block.timestamp < deadline) {
            revert EthFlo_FundraiserStillActive();
        }

        // Checks: 3. if fundraiser succeeded
        if (amountRaised >= goal) {
            revert EthFlo_FundraiserWasSuccessful();
        }

        // Refund donor
        // USDT.safeTransfer(msg.sender, amountToBeReturned);

        // Withdraw funds from AAVE and send to donor
        AAVE_POOL.withdraw(address(USDT), amountToBeReturned, msg.sender);

        // Update accounting
        s_totalEscrowedFunds -= amountToBeReturned;

        // Event
        emit DonorFundsReturned(msg.sender, _fundraiserId, amountToBeReturned);
    }

    function getTotalEscrowedFunds() external view returns (uint256) {
        return s_totalEscrowedFunds;
    }
}
