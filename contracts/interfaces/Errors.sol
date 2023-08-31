// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface Errors {

    /* ========== COMMON ========== */

    /**
     * @dev Indicates if an address to be reassigned is the same as the new address given.
     * @param currentAddress Address to be reassigned.
     */
    error IdenticalAddressReassignment(address currentAddress);
    /**
     * @dev Indicates a failure with the `initializer`.
     */
    error InvalidInitializer();
    /**
     * @dev Indicates an error when `initialize` is being called more than once.
     */
    error AlreadyInitialized();
    /**
     * @dev Indicates that a given address is not valid. For example, `address(0)`.
     */
    error InvalidAddress();
    /**
     * @dev Indicates that a given integer value is not valid. For example, `0`.
     */
    error InvalidValue();

    /* ========== ZARS ========== */

    /**
     * @dev Indicates an error when reassigning a boolean state variable.
     * @param state State of the boolean variable to be replaced.
     */
    error SameStateReassignment(bool state);

    /* ========== AIRDROP ========== */

    /**
     * @dev Indicates an error related to the `argument` being less than the `minimum` value.
     * @param argument Given value.
     * @param minimum Lower limit for that given value.
     */
    error InsufficientValue(uint256 argument, uint256 minimum);

    /* ========== PRESALE ========== */

    /**
     * @dev Indicates an error related to the `argument` being less than the `minimum` value or greater
     * than the `maximum` value.
     * @param argument Given value.
     * @param maximum Upper limit for that given value.
     * @param minimum Lower limit for that given value.
     */
    error OutOfBoundValue(
        uint256 argument,
        uint256 maximum,
        uint256 minimum
    );

    /* ========== STAKING ========== */

    /**
     * @dev Indicates an error related to the length of `indexes` being greater than the length of
     * all `stakes` for a user.
     * @param indexesLength Length of the argument array.
     * @param stakingLength Length of all stakings of a user.
     */
    error NotEnoughStakes(uint256 indexesLength, uint256 stakingLength);
    /**
     * @dev Indicates an error related to the `index` being greater than the `length` of all stakes
     * for a user.
     * @param stakingLength Length of all stakings of a user.
     */
    error InvalidIndex(uint256 stakingLength);
    /**
     * @dev Indicates an error related to the current `value` staked. If the value is Zero than the
     * stake does not exist.
     */
    error NoSuchStake();
    /**
     * @dev Indicates an error where there are no rewards to withdraw for a user at the given time.
     */
    error NoReward();
    /**
     * @dev Indicates an error where the buyback time has not yet crossed.
     * @param currentTime Time at which the method was called.
     * @param buybackTime Time at which the buyback will be available.
     */
    error BuybackTimeNotReached(uint256 currentTime, uint256 buybackTime);
    /**
     * @dev Indicates an error where the amount being sent for buyback does not match the `needed`
     * amount.
     * @param needed Exact amount needed to execute the buyback.
     */
    error IncorrectBuybackValue(uint256 needed);
    /**
     * @dev Indicates an error where the staking end time has not yet crossed.
     * @param currentTime Time at which the method was called.
     * @param endTime Time at which the unstaking will be available.
     */
    error EndTimeNotReached(uint256 currentTime, uint256 endTime);
}
