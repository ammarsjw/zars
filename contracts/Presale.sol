// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import { Errors } from "./interfaces/Errors.sol";
import { IERC20 } from "./interfaces/IERC20.sol";
import { IStaking } from "./interfaces/IStaking.sol";

import { Address } from "./libraries/Address.sol";
import { PriceFeed, AggregatorV3Interface } from "./libraries/PriceFeed.sol";

import { Ownable } from "./utils/Ownable.sol";

contract Presale is Ownable, Errors {
    using PriceFeed for AggregatorV3Interface;
    using Address for address payable;

    /* ========== STATE VARIABLES ========== */

    // TODO change to 0xC5A35FC58EFDC4B88DDCA51AcACd2E8F593504bE
    /// @notice Address of the BNB/USD price aggregator.
    AggregatorV3Interface public priceFeed =
        AggregatorV3Interface(0xb39B176130aCFd652F228D45b634A5fB1bE3bb11);

    /// @notice Minimum value of zars token, in terms of USD, that can be bought - magnified by 1e18.
    uint128 public constant MIN_PURCHASE_USD = 25 * 1e18;
    /// @notice Maximum value of zars token, in terms of USD, that can be bought - magnified by 1e18.
    uint128 public constant MAX_PURCHASE_USD = 250 * 1e18;
    /// @notice Price at which users can buy zars token - magnified by 1e18.
    uint256 public constant PRICE_TOKEN = 0.01 * 1e18;

    /// @notice The address of the zars token.
    IERC20 public zars;
    /// @notice The address of the staking contract.
    IStaking public staking;
    /// @notice The address of the sale funds holding wallet.
    address public saleWallet;

    /// @dev Initialization variables.
    address private immutable _INITIALIZER;
    bool private _isInitialized;

    /* ========== EVENTS ========== */

    event UpdatePriceFeed(address newPriceFeed, address oldPriceFeed);
    event PresaleToStake(
        address user,
        uint256 price,
        uint256 value,
        uint256 valueUSD,
        uint256 valueToken
    );

    /* ========== CONSTRUCTOR ========== */

    /**
     * @dev Constructor.
     * @param saleWallet_ Address of the sale funds holding wallet.
     */
    constructor(address saleWallet_) Ownable(_msgSender()) {
        saleWallet = saleWallet_;
        _INITIALIZER = _msgSender();
    }

    /* ========== INITIALIZE ========== */

    /**
     * @notice Initializes external dependencies and certain state variables. This function can
     * only be called once.
     * @param zars_ Address of the zars token.
     * @param staking_ Address of the staking contract.
     */
    function initialize(address zars_, address staking_) external {
        if (_msgSender() != _INITIALIZER) revert InvalidInitializer();
        if (_isInitialized) revert AlreadyInitialized();
        if (zars_ == address(0)) revert InvalidAddress();
        if (staking_ == address(0)) revert InvalidAddress();

        zars = IERC20(zars_);
        staking = IStaking(staking_);

        _delegateApprove(zars, address(staking), true);

        _isInitialized = true;
    }

    /* ========== FUNCTIONS ========== */

    /**
     * @notice Allows this contract to approve tokens being sent out. Caller must be the owner.
     * @param token The address of the token to approve.
     * @param spender The address of the spender.
     * @param isApproved The new state of the spender's allowance.
     */
    function delegateApprove(IERC20 token, address spender, bool isApproved) external onlyOwner {
        _delegateApprove(token, spender, isApproved);
    }

    function _delegateApprove(IERC20 token, address spender, bool isApproved) internal {
        uint256 value = isApproved ? type(uint256).max : 0;
        token.approve(spender, value);
    }

    /**
     * @notice Updates the address of the price feed. Only the `owner` can call this function.
     * @param newPriceFeed The address of the new price feed.
     */
    function updatePriceFeed(address newPriceFeed) external onlyOwner {
        if (newPriceFeed == address(priceFeed))
            revert IdenticalAddressReassignment(address(priceFeed));
        emit UpdatePriceFeed({newPriceFeed: newPriceFeed, oldPriceFeed: address(priceFeed)});
        priceFeed = AggregatorV3Interface(newPriceFeed);
    }

    /**
     * @notice Receives BNB and gives an equivalent amount of zars token back with respect to a fixed price.
     */
    function presale() external payable {
        if (msg.value == 0) revert InvalidValue();
        uint256 price = priceFeed.getLatestPriceETH();
        uint256 valueUSD = (msg.value * price) / 1e8;

        if (valueUSD < MIN_PURCHASE_USD || valueUSD > MAX_PURCHASE_USD)
            revert OutOfBoundValue(valueUSD, MAX_PURCHASE_USD, MIN_PURCHASE_USD);
        uint256 valueToken = (valueUSD * 1e9) / PRICE_TOKEN;
        zars.transferFrom(saleWallet, address(this), valueToken);
        staking.stakePresale(valueToken);
        payable(saleWallet).sendValue(msg.value);
        emit PresaleToStake({
            user: _msgSender(),
            price: price,
            value: msg.value,
            valueUSD: valueUSD,
            valueToken: valueToken
        });
    }
}
