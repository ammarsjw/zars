// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import {Errors} from "./interfaces/Errors.sol";
import {IERC20} from "./interfaces/IERC20.sol";

import {Address} from "./libraries/Address.sol";
import {PriceFeed, AggregatorV3Interface} from "./libraries/PriceFeed.sol";

import {AccessControl} from "./utils/AccessControl.sol";

contract Staking is AccessControl, Errors {
    using PriceFeed for AggregatorV3Interface;
    using Address for address payable;

    /* ========== STATE VARIABLES ========== */

    /// @dev Access control role variables.
    bytes32 public constant ADMIN_ROLE =
        keccak256("ADMIN_ROLE");
    bytes32 public constant OWNER_ROLE =
        keccak256("OWNER_ROLE");
    bytes32 public constant PRIMARY_STAKING_ROLE =
        keccak256("PRIMARY_STAKING_ROLE");
    bytes32 public constant SECONDARY_STAKING_ROLE =
        keccak256("SECONDARY_STAKING_ROLE");

    // TODO change to 0xC5A35FC58EFDC4B88DDCA51AcACd2E8F593504bE
    /// @notice Address of the BNB/USD price aggregator.
    AggregatorV3Interface public priceFeed =
        AggregatorV3Interface(0xb39B176130aCFd652F228D45b634A5fB1bE3bb11);

    /// @dev Fixed time variables.
    uint128 private constant _ONE_DAY_TIME = 86400;
    uint128 private constant _FIVE_MONTHS_TIME = 12960000;
    uint128 private constant _SIX_MONTHS_TIME = 15552000;

    /// @notice Price at which users can buyback their zars token - magnified by 1e18.
    uint128 public constant BUYBACK_PRICE_TOKEN = 0.03 * 1e18;

    /// @notice Percentage daily reward for airdrop and presale respectively - magnified by 1e18.
    uint128[2] public dailyReward = [0.5 * 1e18, 3 * 1e18];

    /// @notice The address of the zars token.
    IERC20 public zars;
    /// @notice The address of the airdrop contract.
    address public airdrop;
    /// @notice The address of the presale contract.
    address public presale;
    /// @notice The address of the staking rewards holder wallet.
    address public stakingRewardWallet;

    /// @dev Initialization variables.
    address private immutable _INITIALIZER;
    bool private _isInitialized;

    /* ========== STORAGE ========== */

    enum Kind {
        Airdrop,
        Presale
    }

    struct StakeInfo {
        uint256 index;
        Kind kind;
        uint256 value;
        uint256 startTime;
        uint256 buybackTime;
        uint256 endTime;
        uint256 lastClaimTime;
    }

    /// @notice User stakings.
    mapping (address => mapping (uint256 => StakeInfo)) public getStakings;
    /// @notice Number of stakings for each user.
    mapping (address => uint256) public getStakingLengths;

    /* ========== EVENTS ========== */

    event UpdatePriceFeed(address newPriceFeed, address oldPriceFeed);
    event Stake(address user, StakeInfo staking);
    event Claim(address user, uint256 index, uint256 reward);
    event Buyback(
        address user,
        uint256 index,
        uint256 reward,
        uint256 price,
        uint256 value,
        uint256 valueUSD,
        uint256 valueToken
    );
    event Unstake(address user, uint256 index, uint256 reward);

    /* ========== CONSTRUCTOR ========== */

    /**
     * @dev Constructor.
     * @param stakingRewardWallet_ Address of the staking funds holding wallet.
     */
    constructor(address stakingRewardWallet_) {
        stakingRewardWallet = stakingRewardWallet_;
        _INITIALIZER = _msgSender();
    }

    /* ========== INITIALIZE ========== */

    /**
     * @notice Initializes external dependencies and certain state variables. This function can
     * only be called once.
     * @param zars_ Address of the zars token
     * @param airdrop_ Address of the airdrop contract.
     * @param presale_ Address of the presale contract.
     */
    function initialize(address zars_, address airdrop_, address presale_) external {
        if (_msgSender() != _INITIALIZER) revert InvalidInitializer();
        if (_isInitialized) revert AlreadyInitialized();
        if (zars_ == address(0)) revert InvalidAddress();
        if (airdrop_ == address(0)) revert InvalidAddress();
        if (presale_ == address(0)) revert InvalidAddress();

        /// @dev Assigning admin role to all non-admin roles.
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(OWNER_ROLE, ADMIN_ROLE);
        _setRoleAdmin(PRIMARY_STAKING_ROLE, ADMIN_ROLE);
        _setRoleAdmin(SECONDARY_STAKING_ROLE, ADMIN_ROLE);

        /// @dev Setting admin and all roleplayers.
        _grantRole(ADMIN_ROLE, _msgSender());
        _grantRole(OWNER_ROLE, _msgSender());
        _grantRole(PRIMARY_STAKING_ROLE, airdrop_);
        _grantRole(SECONDARY_STAKING_ROLE, presale_);

        zars = IERC20(zars_);
        airdrop = airdrop_;
        presale = presale_;

        _isInitialized = true;
    }

    /* ========== FUNCTIONS ========== */

    /**
     * @notice Updates the address of the price feed. Only the `owner` role can call this function.
     * @param newPriceFeed The address of the new price feed.
     */
    function updatePriceFeed(address newPriceFeed) external onlyRole(OWNER_ROLE) {
        if (newPriceFeed == address(priceFeed))
            revert IdenticalAddressReassignment(address(priceFeed));
        emit UpdatePriceFeed({newPriceFeed: newPriceFeed, oldPriceFeed: address(priceFeed)});
        priceFeed = AggregatorV3Interface(newPriceFeed);
    }

    /**
     * @notice Returns cumulative rewards of a given user from all stakes.
     * @param user Address of the user.
     */
    function getRewardBatch(address user) external view returns (uint256) {
        uint256 totalReward;

        for (uint256 i = 0 ; i < getStakingLengths[user] ; i++) {
            totalReward += getReward(user, i);
        }
        return totalReward;
    }

    /**
     * @notice Returns cumulative rewards of a given user in a specific kind of stake.
     * @param user Address of the user.
     * @param kind The type of kind.
     */
    function getRewardKind(address user, Kind kind) external view returns (uint256) {
        uint256 totalReward;

        for (uint256 i = 0 ; i < getStakingLengths[user] ; i++) {
            if (getStakings[user][i].kind == kind) {
                totalReward += getReward(user, i);
            }
        }
        return totalReward;
    }

    /**
     * @notice Returns reward of a given user in a specific stake.
     * @param user Address of the user.
     * @param index The index of the stake.
     */
    function getReward(address user, uint256 index) public view returns (uint256) {
        uint256 reward;
        StakeInfo memory staking = getStakings[user][index];

        if (staking.value > 0) {
            uint256 endTime = block.timestamp > staking.endTime ? staking.endTime : block.timestamp;
            uint256 numberOfDays = (endTime - staking.lastClaimTime) / _ONE_DAY_TIME;

            if (numberOfDays > 0) {
                uint256 percentage = dailyReward[uint8(staking.kind)];
                uint256 rewardPerDay = ((staking.value * percentage) / 1e2) / 1e18;
                reward = rewardPerDay * numberOfDays;
            }
        }
        return reward;
    }

    /**
     * @notice Stake via airdrop
     * @param value Amount of tokens to stake.
     */
    function stakeAirdrop(uint256 value) external onlyRole(PRIMARY_STAKING_ROLE) {
        _stake(value, Kind.Airdrop);
    }

    /**
     * @notice Stake via presale
     * @param value Amount of tokens to stake.
     */
    function stakePresale(uint256 value) external onlyRole(SECONDARY_STAKING_ROLE) {
        _stake(value, Kind.Presale);
    }

    function _stake(uint256 value, Kind kind) internal {
        if (value == 0) revert InvalidValue();
        zars.transferFrom(_msgSender(), address(this), value);

        StakeInfo memory staking = StakeInfo({
            index: getStakingLengths[_msgSender()],
            kind: kind,
            value: value,
            startTime: block.timestamp,
            buybackTime: block.timestamp + _FIVE_MONTHS_TIME,
            endTime: block.timestamp + _SIX_MONTHS_TIME,
            lastClaimTime: block.timestamp
        });

        getStakings[_msgSender()][staking.index] = staking;
        getStakingLengths[_msgSender()]++;
        emit Stake({user: _msgSender(), staking: staking});
    }

    /**
     * @notice Claim cumulative rewards from the given stakes.
     *
     * NOTE: Beware of high gas spending.
     *
     * @param indexes Unique identifiers of the user's stakes.
     */
    function claimBatch(uint256[] memory indexes) external {
        uint256 stakingLength = getStakingLengths[_msgSender()];

        if (indexes.length > stakingLength)
            revert NotEnoughStakes(indexes.length, stakingLength);

        for (uint256 i = 0 ; i < stakingLength ; i++) {
            claim(indexes[i]);
        }
    }

    /**
     * @notice Claim rewards of a given stake.
     * @param index Unique identifier of the user's stake.
     */
    function claim(uint256 index) public {
        uint256 stakingLength = getStakingLengths[_msgSender()];

        if (index >= stakingLength) revert InvalidIndex(stakingLength);
        StakeInfo memory staking = getStakings[_msgSender()][index];

        if (staking.value == 0) revert NoSuchStake();
        uint256 reward = getReward(_msgSender(), index);

        if (reward == 0) revert NoReward();
        uint256 endTime = block.timestamp > staking.endTime ? staking.endTime : block.timestamp;
        uint256 numberOfDays = (endTime - staking.lastClaimTime) / _ONE_DAY_TIME;
        staking.lastClaimTime = staking.lastClaimTime + (numberOfDays * _ONE_DAY_TIME);
        zars.transferFrom(stakingRewardWallet, _msgSender(), reward);
        emit Claim({user: _msgSender(), index: index, reward: reward});
    }

    /**
     * @notice Buyback tokens from the given stakes.
     *
     * NOTE: Beware of high gas spending.
     *
     * @param indexes Unique identifiers of the user's stakes.
     */
    function buybackBatch(uint256[] memory indexes) external payable {
        uint256 stakingLength = getStakingLengths[_msgSender()];

        if (indexes.length > stakingLength)
            revert NotEnoughStakes(indexes.length, stakingLength);

        for (uint256 i = 0 ; i < stakingLength ; i++) {
            buyback(indexes[i]);
        }
    }

    /**
     * @notice Buyback tokens from a given stake.
     * @param index Unique identifier of the user's stake.
     */
    function buyback(uint256 index) public payable {
        if (msg.value == 0) revert InvalidValue();
        uint256 stakingLength = getStakingLengths[_msgSender()];

        if (index >= stakingLength) revert InvalidIndex(stakingLength);
        StakeInfo memory staking = getStakings[_msgSender()][index];

        if (staking.value == 0) revert NoSuchStake();
        if (block.timestamp <= staking.buybackTime)
            revert BuybackTimeNotReached(block.timestamp, staking.buybackTime);
        uint256 price = priceFeed.getLatestPriceETH();
        uint256 value = (staking.value * BUYBACK_PRICE_TOKEN) / (price * 1e1);

        if (msg.value != value) revert IncorrectBuybackValue(value);
        uint256 reward = getReward(_msgSender(), index);
        delete getStakings[_msgSender()][index];
        payable(stakingRewardWallet).sendValue(msg.value);

        if (reward > 0) {
            zars.transferFrom(stakingRewardWallet, _msgSender(), reward);
        }
        zars.transfer(_msgSender(), staking.value);
        emit Buyback({
            user: _msgSender(),
            index: index,
            reward: reward,
            price: price,
            value: msg.value,
            valueUSD: (msg.value * price) / 1e8,
            valueToken: staking.value
        });
    }

    /**
     * @notice Unstake the given stakes.
     *
     * NOTE: Beware of high gas spending.
     *
     * @param indexes Unique identifiers of the user's stakes.
     */
    function unstakeBatch(uint256[] memory indexes) external {
        uint256 stakingLength = getStakingLengths[_msgSender()];

        if (indexes.length > stakingLength)
            revert NotEnoughStakes(indexes.length, stakingLength);

        for (uint256 i = 0 ; i < stakingLength ; i++) {
            unstake(indexes[i]);
        }
    }

    /**
     * @notice Unstake a given stake.
     * @param index Unique identifier of the user's stake.
     */
    function unstake(uint256 index) public {
        uint256 stakingLength = getStakingLengths[_msgSender()];

        if (index >= stakingLength) revert InvalidIndex(stakingLength);
        StakeInfo memory staking = getStakings[_msgSender()][index];

        if (staking.value == 0) revert NoSuchStake();
        if (block.timestamp <= staking.endTime)
            revert EndTimeNotReached(block.timestamp, staking.endTime);
        uint256 reward = getReward(_msgSender(), index);
        delete getStakings[_msgSender()][index];

        if (reward > 0) {
            zars.transferFrom(stakingRewardWallet, _msgSender(), reward);
        }
        zars.transfer(_msgSender(), staking.value);
        emit Unstake({user: _msgSender(), index: index, reward: reward});
    }
}
