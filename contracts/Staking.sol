// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import {IERC20} from "./interfaces/IERC20.sol";

import {PriceFeed} from "./libraries/PriceFeed.sol";

import {AccessControl} from "./utils/AccessControl.sol";

contract Staking is AccessControl {
    using PriceFeed for address;

    /* ========== STATE VARIABLES ========== */

    /// @dev Roles.
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
    address public priceFeed = 0xb39B176130aCFd652F228D45b634A5fB1bE3bb11;

    /// @dev Fixed time variables.
    uint128 private constant _ONE_DAY_TIME = 86400;
    uint128 private constant _FIVE_MONTHS_TIME = 12960000;
    uint128 private constant _SIX_MONTHS_TIME = 15552000;

    /// @notice Price at which users can buy zars - magnified by 1e18.
    uint128 public constant BUYBACK_PRICE_TOKEN = 0.03 * 1e18;

    /// @notice Percentage daily reward for airdrop and presale respectively - magnified by 1e18.
    uint128[2] public dailyReward = [0.5 * 1e18, 3 * 1e18];

    IERC20 public zars;
    address public airdrop;
    address public presale;
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

    /* ========== ERRORS ========== */

    error StakingUnauthorizedInitializer();
    error StakingAlreadyInitialized();
    error StakingInvalidAddress();
    error StakingSameVariableReassignment();
    error StakingInvalidValue();
    error StakingNotEnoughStakes(uint256 argumentLength, uint256 stakingLength);
    error StakingInvalidIndex(uint256 stakingLength);
    error StakingNoSuchStake();
    error StakingNoReward();
    error StakingBuybackTimeNotReached(uint256 currentTime, uint256 buybackTime);
    error StakingIncorrectBuybackValue(uint256 argumentValue, uint256 value);
    error StakingEndTimeNotReached(uint256 currentTime, uint256 endTime);

    /* ========== EVENTS ========== */

    event UpdatePriceFeed(address newPriceFeed, address oldPriceFeed);
    event Stake(address user, StakeInfo staking);
    event Claim(address user, uint256 index, uint256 reward);
    event Buyback(address user, uint256 index);
    event Unstake(address user, uint256 index);

    /* ========== CONSTRUCTOR ========== */

    constructor(address stakingRewardWallet_) {
        stakingRewardWallet = stakingRewardWallet_;
        _INITIALIZER = _msgSender();
    }

    /* ========== INITIALIZE ========== */

    function initialize(address zars_, address airdrop_, address presale_) external {
        if (_msgSender() != _INITIALIZER) revert StakingUnauthorizedInitializer();
        if (_isInitialized) revert StakingAlreadyInitialized();
        if (zars_ == address(0)) revert StakingInvalidAddress();
        if (airdrop_ == address(0)) revert StakingInvalidAddress();
        if (presale_ == address(0)) revert StakingInvalidAddress();

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

    function updatePriceFeed(address newPriceFeed) external onlyRole(OWNER_ROLE) {
        if (newPriceFeed == priceFeed)
            revert StakingSameVariableReassignment();
        emit UpdatePriceFeed({newPriceFeed: newPriceFeed, oldPriceFeed: priceFeed});
        priceFeed = newPriceFeed;
    }

    function getRewardBatch(address user) external view returns (uint256) {
        uint256 totalReward;

        for (uint256 i = 0 ; i < getStakingLengths[user] ; i++) {
            totalReward += getReward(user, i);
        }
        return totalReward;
    }

    function getRewardKind(address user, Kind kind) external view returns (uint256) {
        uint256 totalReward;

        for (uint256 i = 0 ; i < getStakingLengths[user] ; i++) {
            if (getStakings[user][i].kind == kind) {
                totalReward += getReward(user, i);
            }
        }
        return totalReward;
    }

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

    function stakeAirdrop(uint256 value) external onlyRole(PRIMARY_STAKING_ROLE) {
        _stake(value, Kind.Airdrop);
    }

    function stakePresale(uint256 value) external onlyRole(SECONDARY_STAKING_ROLE) {
        _stake(value, Kind.Presale);
    }

    function _stake(uint256 value, Kind kind) internal {
        if (value == 0) revert StakingInvalidValue();
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

    function claimBatch(uint256[] memory indexes) external {
        uint256 stakingLength = getStakingLengths[_msgSender()];

        if (indexes.length > stakingLength)
            revert StakingNotEnoughStakes(indexes.length, stakingLength);

        for (uint256 i = 0 ; i < stakingLength ; i++) {
            claim(indexes[i]);
        }
    }

    function claim(uint256 index) public {
        uint256 stakingLength = getStakingLengths[_msgSender()];

        if (index >= stakingLength) revert StakingInvalidIndex(stakingLength);
        StakeInfo memory staking = getStakings[_msgSender()][index];

        if (staking.value == 0) revert StakingNoSuchStake();
        uint256 reward = getReward(_msgSender(), index);

        if (reward == 0) revert StakingNoReward();
        uint256 endTime = block.timestamp > staking.endTime ? staking.endTime : block.timestamp;
        uint256 numberOfDays = (endTime - staking.lastClaimTime) / _ONE_DAY_TIME;
        staking.lastClaimTime = staking.lastClaimTime + (numberOfDays * _ONE_DAY_TIME);
        zars.transferFrom(stakingRewardWallet, _msgSender(), reward);
        emit Claim({user: _msgSender(), index: index, reward: reward});
    }

    function buybackBatch(uint256[] memory indexes) external payable {
        uint256 stakingLength = getStakingLengths[_msgSender()];

        if (indexes.length > stakingLength)
            revert StakingNotEnoughStakes(indexes.length, stakingLength);

        for (uint256 i = 0 ; i < stakingLength ; i++) {
            buyback(indexes[i]);
        }
    }

    function buyback(uint256 index) public payable {
        if (msg.value == 0) revert StakingInvalidValue();
        uint256 stakingLength = getStakingLengths[_msgSender()];

        if (index >= stakingLength) revert StakingInvalidIndex(stakingLength);
        StakeInfo memory staking = getStakings[_msgSender()][index];

        if (staking.value == 0) revert StakingNoSuchStake();
        if (block.timestamp <= staking.buybackTime)
            revert StakingBuybackTimeNotReached(block.timestamp, staking.buybackTime);
        uint256 price = priceFeed.getLatestPrice();
        uint256 value = (staking.value * BUYBACK_PRICE_TOKEN) / (price * 1e1);

        if (msg.value != value) revert StakingIncorrectBuybackValue(msg.value, value);
        uint256 reward = getReward(_msgSender(), index);
        uint256 stakingValue = staking.value;
        delete getStakings[_msgSender()][index];

        if (reward > 0) {
            zars.transferFrom(stakingRewardWallet, _msgSender(), reward);
        }
        zars.transfer(_msgSender(), stakingValue);
        emit Buyback({user: _msgSender(), index: index});
    }

    function unstakeBatch(uint256[] memory indexes) external {
        uint256 stakingLength = getStakingLengths[_msgSender()];

        if (indexes.length > stakingLength)
            revert StakingNotEnoughStakes(indexes.length, stakingLength);

        for (uint256 i = 0 ; i < stakingLength ; i++) {
            unstake(indexes[i]);
        }
    }

    function unstake(uint256 index) public {
        uint256 stakingLength = getStakingLengths[_msgSender()];

        if (index >= stakingLength) revert StakingInvalidIndex(stakingLength);
        StakeInfo memory staking = getStakings[_msgSender()][index];

        if (staking.value == 0) revert StakingNoSuchStake();
        if (block.timestamp <= staking.endTime)
            revert StakingEndTimeNotReached(block.timestamp, staking.endTime);
        uint256 reward = getReward(_msgSender(), index);
        uint256 stakingValue = staking.value;
        delete getStakings[_msgSender()][index];

        if (reward > 0) {
            zars.transferFrom(stakingRewardWallet, _msgSender(), reward);
        }
        zars.transfer(_msgSender(), stakingValue);
        emit Unstake({user: _msgSender(), index: index});
    }
}
