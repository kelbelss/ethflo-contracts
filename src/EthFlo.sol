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
 * @notice This contract implements a crowdfunding platform with USDT donations and AAVE yield generation
 * @dev Inherits from ERC20 for reward token functionality and Ownable for access control
 */
contract EthFlo is ERC20, Ownable {
    using SafeERC20 for IERC20;

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
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Struct to store information about each fundraiser
     * @dev Used in the fundraisers mapping
     */
    struct Fundraiser {
        address creatorAddr;
        bool claimed;
        uint256 deadline;
        uint256 goal;
        uint256 amountRaised;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping of fundraiser IDs to Fundraiser structs
    mapping(uint256 fundraiserId => Fundraiser fundraiser) public fundraisers;

    /// @notice Mapping of donor addresses to fundraiser IDs to donation amounts
    mapping(address donor => mapping(uint256 id => uint256 amount)) public donorsAmount;

    uint256 public constant MIN_DURATION = 5 days;
    uint256 public constant MAX_DURATION = 90 days; // $10
    uint256 public constant MIN_GOAL = 10e6; // $10
    uint256 public constant MAX_GOAL = 100_000_000e6; // $100 million
    uint256 public constant MINIMUM_DONATION = 10000000; // $10
    uint256 public constant ADMIN_FEE = 5; // 5%
    uint256 public constant USDT_TO_ETHFLO_DECIMALS = 1e12;
    address public aUSDT_ADDRESS;

    /// @notice The USDT token contract
    IERC20 public immutable USDT;

    /// @notice The Aave lending pool contract
    IPool public immutable AAVE_POOL;

    /// @notice The total number of fundraisers created
    uint256 public s_fundraiserCount;

    /// @notice The total amount of funds currently held in escrow
    uint256 public s_totalEscrowedFunds;

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
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the EthFlo contract
     * @param _usdtAddress The address of the USDT token contract
     * @param _aavePool The address of the Aave lending pool
     */
    constructor(address _usdtAddress, address _aavePool) ERC20("EthFlo", "ETHFLO") Ownable(msg.sender) {
        USDT = IERC20(_usdtAddress);
        AAVE_POOL = IPool(_aavePool);
        aUSDT_ADDRESS = IPool(AAVE_POOL).getReserveData(address(USDT)).aTokenAddress;
    }

    /*//////////////////////////////////////////////////////////////
                              MAIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a new fundraiser
     * @dev The fundraiser duration must be within the allowed range, and the goal must be between the minimum and maximum allowed amounts
     * @param _deadline The timestamp when the fundraiser will end
     * @param _goal The fundraising goal in USDT
     * @return id The unique identifier of the newly created fundraiser
     * @custom:throws EthFlo_DeadlineError If the fundraiser duration is outside the allowed range
     * @custom:throws EthFlo_GoalError If the fundraising goal is outside the allowed range
     * @custom:emits CreateFundraiser when a new fundraiser is successfully created
     */
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

        fundraisers[id] = Fundraiser(msg.sender, false, _deadline, _goal, 0);

        s_fundraiserCount = id;

        emit CreateFundraiser(msg.sender, _deadline, _goal);

        return id;
    }

    /**
     * @notice Allows a user to donate to a specific fundraiser
     * @dev This function can only be called for existing and active fundraisers
     * @param _fundraiserId The ID of the fundraiser to donate to
     * @param _amountDonated The amount of USDT to donate
     * @custom:throws EthFlo_FundraiserDoesNotExist If the specified fundraiser does not exist
     * @custom:throws EthFlo_FundraiserDeadlineHasPassed If the fundraiser's deadline has already passed
     * @custom:throws EthFlo_MinimumDonationNotMet If the donation amount is less than the minimum required
     * @custom:emits Donation when the donation is successfully processed
     */
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

        // donorsAmount Mapping update - fundraisers id and amount donated by donor
        donorsAmount[msg.sender][_fundraiserId] += _amountDonated;

        // fundraiser Mapping update - amount raised per fundraiser
        fundraisers[_fundraiserId].amountRaised += _amountDonated;

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

    /**
     * @notice Allows the creator of a successful fundraiser to withdraw the raised funds
     * @dev This function can only be called by the fundraiser creator after the deadline has passed and if the goal was reached
     * @param _fundraiserId The ID of the successful fundraiser from which to withdraw funds
     * @custom:throws EthFlo_IncorrectFundraiserOwner If the caller is not the creator of the fundraiser
     * @custom:throws EthFlo_AlreadyClaimed If the funds have already been claimed
     * @custom:throws EthFlo_FundraiserStillActive If the fundraiser's deadline has not yet passed
     * @custom:throws EthFlo_GoalNotReached If the fundraiser did not reach its goal
     * @custom:emits FundsWithdrawn when the funds are successfully withdrawn by the creator
     */
    function creatorWithdraw(uint256 _fundraiserId) external {
        Fundraiser memory selectedFundraiser = fundraisers[_fundraiserId];

        // Checks

        // Checks: 1. if caller is the creator
        if (msg.sender != selectedFundraiser.creatorAddr) {
            revert EthFlo_IncorrectFundraiserOwner();
        }

        // Checks: 2. if claim has been made already
        if (selectedFundraiser.claimed) {
            revert EthFlo_AlreadyClaimed();
        }

        // Checks: 3. if deadline has been reached
        if (block.timestamp < selectedFundraiser.deadline) {
            revert EthFlo_FundraiserStillActive();
        }

        // Checks: 4. if goal is reached
        if (selectedFundraiser.amountRaised < selectedFundraiser.goal) {
            revert EthFlo_GoalNotReached();
        }

        // Deduct 5% fee
        uint256 amountAfterFee = selectedFundraiser.amountRaised * (100 - ADMIN_FEE) / 100;

        // Withdraw funds from AAVE and send to EthFlo
        AAVE_POOL.withdraw(address(USDT), amountAfterFee, msg.sender);

        // Update accounting - deduct full amount donated from escrow to account for fees
        s_totalEscrowedFunds -= selectedFundraiser.amountRaised;

        // set claimed to true to avoid double claims
        fundraisers[_fundraiserId].claimed = true;

        // Event
        emit FundsWithdrawn(msg.sender, _fundraiserId, amountAfterFee);
    }

    /**
     * @notice Allows a donor to claim reward tokens for a successful fundraiser
     * @dev This function can only be called after the fundraiser deadline has passed and if the fundraiser reached its goal
     * @param _fundraiserId The ID of the successful fundraiser for which to claim reward tokens
     * @custom:throws EthFlo_NothingToClaim If the caller has no tokens to claim from this fundraiser
     * @custom:throws EthFlo_FundraiserStillActive If the fundraiser's deadline has not yet passed
     * @custom:throws EthFlo_FundraiserWasUnsuccessful If the fundraiser did not reach its goal
     * @custom:emits TokensClaimed when the reward tokens are successfully minted to the donor
     */
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
            revert EthFlo_NothingToClaim();
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

        // set donorsAmount to 0
        donorsAmount[msg.sender][_fundraiserId] = 0;

        // Event
        emit TokensClaimed(msg.sender, _fundraiserId, amountOfTokens);
    }

    /**
     * @notice Allows a donor to withdraw their donation from an unsuccessful fundraiser
     * @dev This function can only be called after the fundraiser deadline has passed and if the fundraiser did not reach its goal
     * @param _fundraiserId The ID of the fundraiser from which to withdraw the donation
     * @custom:throws EthFlo_NothingToClaim If the caller has no funds to claim from this fundraiser
     * @custom:throws EthFlo_FundraiserStillActive If the fundraiser's deadline has not yet passed
     * @custom:throws EthFlo_FundraiserWasSuccessful If the fundraiser reached or exceeded its goal
     * @custom:emits DonorFundsReturned when the funds are successfully returned to the donor
     */
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
            revert EthFlo_NothingToClaim();
        }

        // Checks: 2. check if fundraiser deadline has passed
        if (block.timestamp < deadline) {
            revert EthFlo_FundraiserStillActive();
        }

        // Checks: 3. if fundraiser succeeded
        if (amountRaised >= goal) {
            revert EthFlo_FundraiserWasSuccessful();
        }

        // Withdraw funds from AAVE and send to donor
        AAVE_POOL.withdraw(address(USDT), amountToBeReturned, msg.sender);

        // Update accounting
        s_totalEscrowedFunds -= amountToBeReturned;

        // set donorsAmount to 0
        donorsAmount[msg.sender][_fundraiserId] = 0;

        // Event
        emit DonorFundsReturned(msg.sender, _fundraiserId, amountToBeReturned);
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getTotalEscrowedFunds() external view returns (uint256) {
        return s_totalEscrowedFunds;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allows the contract owner to withdraw accumulated fees and yield
     * @dev This function can only be called by the contract owner
     * @param _to The address to receive the withdrawn fees and yield
     * @custom:throws EthFlo_NoFeesAndYieldAvailable If there are no fees or yield to withdraw
     */
    function withdrawFeesAndYield(address _to) external onlyOwner {
        uint256 aUSDTBalance = IERC20(aUSDT_ADDRESS).balanceOf(address(this));

        uint256 feesAndYield = aUSDTBalance - s_totalEscrowedFunds;

        if (feesAndYield == 0) {
            revert EthFlo_NoFeesAndYieldAvailable();
        }

        AAVE_POOL.withdraw(address(USDT), feesAndYield, _to);
    }
}
