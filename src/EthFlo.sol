// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPool} from "@aave/contracts/interfaces/IPool.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title EthFlo Contract
 * @author Kelly Smulian
 * @notice This contract implements a crowdfunding platform with USDT donations and AAVE yield generation
 * @dev Inherits from ERC20 for reward token functionality and Ownable for access control
 */
contract EthFlo is ERC20, Ownable {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Struct to store information about each fundraiser
     * @dev Used in the fundraisers mapping
     */
    struct Fundraiser {
        uint256 deadline;
        uint256 goal;
        uint256 amountRaised;
        bool claimed;
        address creatorAddr;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 public constant MIN_DURATION = 5 days;
    uint256 public constant MAX_DURATION = 90 days;
    uint256 public constant MIN_GOAL = 10e6; // $10
    uint256 public constant MAX_GOAL = 100_000_000e6; // $100 million
    uint256 public constant MINIMUM_DONATION = 10e6; // $10
    uint256 public constant ADMIN_FEE = 5; // 5%
    uint256 public constant USDT_TO_ETHFLO_DECIMALS = 1e12;
    uint256 public constant SCALE = 100;

    /// @notice The aUSDT token address
    IERC20 public immutable aUSDT_ADDRESS;

    /// @notice The USDT token contract
    IERC20 public immutable USDT;

    /// @notice The Aave lending pool contract
    IPool public immutable AAVE_POOL;

    /// @notice The total number of fundraisers created
    uint256 internal s_fundraiserCount;

    /// @notice The total amount of funds currently held in escrow
    uint256 internal s_totalEscrowedFunds;

    /// @notice Mapping of fundraiser IDs to Fundraiser structs
    mapping(uint256 fundraiserId => Fundraiser fundraiser) public fundraisers;

    /// @notice Mapping of donor addresses to fundraiser IDs to donation amounts
    mapping(address donor => mapping(uint256 id => uint256 amount)) public donorsAmount;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new fundraiser is created
    event CreateFundraiser(address indexed creatorAddr, uint256 deadline, uint256 goal);

    /// @notice Emitted when a donation is made to a fundraiser
    event Donation(address indexed donorAddr, uint256 indexed fundraiserId, uint256 amount);

    /// @notice Emitted when funds are withdrawn by a fundraiser creator
    event FundsWithdrawn(address indexed creatorAddr, uint256 indexed fundraiserId, uint256 amountReceived);

    /// @notice Emitted when a donor's funds are returned from an unsuccessful fundraiser
    event DonorFundsReturned(address indexed donorAddr, uint256 indexed fundraiserId, uint256 amount);

    /// @notice Emitted when reward tokens are claimed by a donor
    event TokensClaimed(address indexed donorAddr, uint256 indexed fundraiserId, uint256 amountClaimed);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error EthFlo_NoFeesAndYieldAvailable();
    error EthFlo_DeadlineError();
    error EthFlo_GoalError();
    error EthFlo_FundraiserDoesNotExist();
    error EthFlo_FundraiserDeadlineHasPassed();
    error EthFlo_MinimumDonationNotMet();
    error EthFlo_FundraiserStillActive();
    error EthFlo_GoalNotReached();
    error EthFlo_IncorrectFundraiserOwner();
    error EthFlo_AlreadyClaimed();
    error EthFlo_NothingToClaim();
    error EthFlo_FundraiserWasUnsuccessful();
    error EthFlo_FundraiserWasSuccessful();

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the EthFlo contract
     * @param usdtAddress The address of the USDT token contract
     * @param aavePool The address of the Aave lending pool
     */
    constructor(address usdtAddress, address aavePool) ERC20("EthFlo", "ETHFLO") Ownable(msg.sender) {
        USDT = IERC20(usdtAddress);
        AAVE_POOL = IPool(aavePool);
        aUSDT_ADDRESS = IERC20(IPool(AAVE_POOL).getReserveData(address(USDT)).aTokenAddress);
    }

    /*//////////////////////////////////////////////////////////////
                              MAIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a new fundraiser
     * @dev The fundraiser duration must be within the allowed range, and the goal must be between the minimum and maximum allowed amounts
     * @param deadline The timestamp when the fundraiser will end
     * @param goal The fundraising goal in USDT
     * @return id The unique identifier of the newly created fundraiser
     * @custom:throws EthFlo_DeadlineError If the fundraiser duration is outside the allowed range
     * @custom:throws EthFlo_GoalError If the fundraising goal is outside the allowed range
     * @custom:emits CreateFundraiser when a new fundraiser is successfully created
     */
    function createFundraiser(uint256 deadline, uint256 goal) external returns (uint256) {
        // Checks for deadline and goal

        uint256 _duration = deadline - block.timestamp;

        if (_duration < MIN_DURATION || _duration > MAX_DURATION) {
            revert EthFlo_DeadlineError();
        }

        if (goal < MIN_GOAL || goal > MAX_GOAL) {
            revert EthFlo_GoalError();
        }

        uint256 id = s_fundraiserCount;
        ++id;

        fundraisers[id] =
            Fundraiser({deadline: deadline, goal: goal, amountRaised: 0, claimed: false, creatorAddr: msg.sender});

        s_fundraiserCount = id;

        emit CreateFundraiser(msg.sender, deadline, goal);

        return id;
    }

    /**
     * @notice Allows a user to donate to a specific fundraiser
     * @dev This function can only be called for existing and active fundraisers
     * @param fundraiserId The ID of the fundraiser to donate to
     * @param amountDonated The amount of USDT to donate
     * @custom:throws EthFlo_FundraiserDoesNotExist If the specified fundraiser does not exist
     * @custom:throws EthFlo_FundraiserDeadlineHasPassed If the fundraiser's deadline has already passed
     * @custom:throws EthFlo_MinimumDonationNotMet If the donation amount is less than the minimum required
     * @custom:emits Donation when the donation is successfully processed
     */
    function donate(uint256 fundraiserId, uint256 amountDonated) external {
        uint256 _deadline = fundraisers[fundraiserId].deadline;

        // Checks: 1. if fundraiser exists
        if (_deadline == 0) {
            revert EthFlo_FundraiserDoesNotExist();
        }

        // Checks: 2. if fundraiser is still active
        if (block.timestamp > _deadline) {
            revert EthFlo_FundraiserDeadlineHasPassed();
        }

        // Checks: 3. if minimum amount is reached
        if (amountDonated < MINIMUM_DONATION) {
            revert EthFlo_MinimumDonationNotMet();
        }

        // donorsAmount Mapping update - fundraisers id and amount donated by donor
        donorsAmount[msg.sender][fundraiserId] += amountDonated;

        // fundraiser Mapping update - amount raised per fundraiser
        fundraisers[fundraiserId].amountRaised += amountDonated;

        // Update accounting
        s_totalEscrowedFunds += amountDonated;

        // Receive funds
        USDT.safeTransferFrom(msg.sender, address(this), amountDonated);

        // Send funds to AAVE to earn yield
        IERC20(USDT).forceApprove(address(AAVE_POOL), amountDonated);
        AAVE_POOL.supply(address(USDT), amountDonated, address(this), 0);

        // Event
        emit Donation(msg.sender, fundraiserId, amountDonated);
    }

    /**
     * @notice Allows the creator of a successful fundraiser to withdraw the raised funds
     * @dev This function can only be called by the fundraiser creator after the deadline has passed and if the goal was reached
     * @param fundraiserId The ID of the successful fundraiser from which to withdraw funds
     * @custom:throws EthFlo_IncorrectFundraiserOwner If the caller is not the creator of the fundraiser
     * @custom:throws EthFlo_AlreadyClaimed If the funds have already been claimed
     * @custom:throws EthFlo_FundraiserStillActive If the fundraiser's deadline has not yet passed
     * @custom:throws EthFlo_GoalNotReached If the fundraiser did not reach its goal
     * @custom:emits FundsWithdrawn when the funds are successfully withdrawn by the creator
     */
    function creatorWithdraw(uint256 fundraiserId) external {
        Fundraiser memory _selectedFundraiser = fundraisers[fundraiserId];

        // Checks

        // Checks: 1. if caller is the creator
        if (msg.sender != _selectedFundraiser.creatorAddr) {
            revert EthFlo_IncorrectFundraiserOwner();
        }

        // Checks: 2. if claim has been made already
        if (_selectedFundraiser.claimed) {
            revert EthFlo_AlreadyClaimed();
        }

        // Checks: 3. if deadline has been reached
        if (block.timestamp < _selectedFundraiser.deadline) {
            revert EthFlo_FundraiserStillActive();
        }

        // Checks: 4. if goal is reached
        if (_selectedFundraiser.amountRaised < _selectedFundraiser.goal) {
            revert EthFlo_GoalNotReached();
        }

        // Deduct 5% fee
        uint256 _amountAfterFee = _selectedFundraiser.amountRaised * (SCALE - ADMIN_FEE) / SCALE;

        // Withdraw funds from AAVE and send to EthFlo
        AAVE_POOL.withdraw(address(USDT), _amountAfterFee, msg.sender);

        // Update accounting - deduct full amount donated from escrow to account for fees
        s_totalEscrowedFunds -= _selectedFundraiser.amountRaised;

        // set claimed to true to avoid double claims
        fundraisers[fundraiserId].claimed = true;

        // Event
        emit FundsWithdrawn(msg.sender, fundraiserId, _amountAfterFee);
    }

    /**
     * @notice Allows a donor to claim reward tokens for a successful fundraiser
     * @dev This function can only be called after the fundraiser deadline has passed and if the fundraiser reached its goal
     * @param fundraiserId The ID of the successful fundraiser for which to claim reward tokens
     * @custom:throws EthFlo_NothingToClaim If the caller has no tokens to claim from this fundraiser
     * @custom:throws EthFlo_FundraiserStillActive If the fundraiser's deadline has not yet passed
     * @custom:throws EthFlo_FundraiserWasUnsuccessful If the fundraiser did not reach its goal
     * @custom:emits TokensClaimed when the reward tokens are successfully minted to the donor
     */
    function claimRewardForSuccessfulFundraiser(uint256 fundraiserId) external {
        // mint tokens to donators in proportion to donation - only mint when goal is reached - let them claim them (and they pay gas)
        uint256 _amountDonated = donorsAmount[msg.sender][fundraiserId];

        // Check 1. if caller is the donor
        if (_amountDonated == 0) {
            revert EthFlo_NothingToClaim();
        }

        // SLOAD operations
        uint256 _deadline = fundraisers[fundraiserId].deadline;
        uint256 _amountRaised = fundraisers[fundraiserId].amountRaised;
        uint256 _goal = fundraisers[fundraiserId].goal;

        // Checks: 2. check if fundraiser deadline has passed
        if (block.timestamp < _deadline) {
            revert EthFlo_FundraiserStillActive();
        }

        // Checks: 3. if fundraiser succeeded
        if (_amountRaised < _goal) {
            revert EthFlo_FundraiserWasUnsuccessful();
        }

        uint256 _amountOfTokens = _amountDonated * USDT_TO_ETHFLO_DECIMALS;

        // set donorsAmount to 0
        donorsAmount[msg.sender][fundraiserId] = 0;

        _mint(msg.sender, _amountOfTokens);

        // Event
        emit TokensClaimed(msg.sender, fundraiserId, _amountOfTokens);
    }

    /**
     * @notice Allows a donor to withdraw their donation from an unsuccessful fundraiser
     * @dev This function can only be called after the fundraiser deadline has passed and if the fundraiser did not reach its goal
     * @param fundraiserId The ID of the fundraiser from which to withdraw the donation
     * @custom:throws EthFlo_NothingToClaim If the caller has no funds to claim from this fundraiser
     * @custom:throws EthFlo_FundraiserStillActive If the fundraiser's deadline has not yet passed
     * @custom:throws EthFlo_FundraiserWasSuccessful If the fundraiser reached or exceeded its goal
     * @custom:emits DonorFundsReturned when the funds are successfully returned to the donor
     */
    function withdrawDonationFromUnsuccessfulFundraiser(uint256 fundraiserId) external {
        // return amount to donor if deadline not reached - claim refund (so they pay gas)
        uint256 _amountToBeReturned = donorsAmount[msg.sender][fundraiserId];

        // Checks: 1. if caller is the donor
        if (_amountToBeReturned == 0) {
            revert EthFlo_NothingToClaim();
        }

        // SLOAD operations
        uint256 _deadline = fundraisers[fundraiserId].deadline;
        uint256 _amountRaised = fundraisers[fundraiserId].amountRaised;
        uint256 _goal = fundraisers[fundraiserId].goal;

        // Checks: 2. check if fundraiser deadline has passed
        if (block.timestamp < _deadline) {
            revert EthFlo_FundraiserStillActive();
        }

        // Checks: 3. if fundraiser succeeded
        if (_amountRaised >= _goal) {
            revert EthFlo_FundraiserWasSuccessful();
        }

        // Update accounting
        s_totalEscrowedFunds -= _amountToBeReturned;

        // set donorsAmount to 0
        donorsAmount[msg.sender][fundraiserId] = 0;

        // Withdraw funds from AAVE and send to donor - avoid reentrancy by doing it after acc update and donor amount set to 0
        AAVE_POOL.withdraw(address(USDT), _amountToBeReturned, msg.sender);

        // Event
        emit DonorFundsReturned(msg.sender, fundraiserId, _amountToBeReturned);
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getFundraiserCount() external view returns (uint256) {
        return s_fundraiserCount;
    }

    function getTotalEscrowedFunds() external view returns (uint256) {
        return s_totalEscrowedFunds;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allows the contract owner to withdraw accumulated fees and yield
     * @dev This function can only be called by the contract owner
     * @param to The address to receive the withdrawn fees and yield
     * @custom:throws EthFlo_NoFeesAndYieldAvailable If there are no fees or yield to withdraw
     */
    function withdrawFeesAndYield(address to) external onlyOwner {
        uint256 _aUSDTBalance = IERC20(aUSDT_ADDRESS).balanceOf(address(this));

        uint256 _feesAndYield = _aUSDTBalance - s_totalEscrowedFunds;

        if (_feesAndYield == 0) {
            revert EthFlo_NoFeesAndYieldAvailable();
        }

        AAVE_POOL.withdraw(address(USDT), _feesAndYield, to);
    }
}
