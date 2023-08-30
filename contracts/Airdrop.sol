// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import {IERC20} from "./interfaces/IERC20.sol";
import {IStaking} from "./interfaces/IStaking.sol";

import {PriceFeed} from "./libraries/PriceFeed.sol";

import {Ownable} from "./utils/Ownable.sol";

contract Airdrop is Ownable {
    using PriceFeed for address;

    /* ========== STATE VARIABLES ========== */

    // TODO change to 0xC5A35FC58EFDC4B88DDCA51AcACd2E8F593504bE
    /// @notice Address of the BNB/USD price aggregator.
    address public priceFeed = 0xb39B176130aCFd652F228D45b634A5fB1bE3bb11;

    /// @notice Minimum value of zars, in terms of USD, that can be bought - magnified by 1e18.
    uint128 public constant MIN_PURCHASE_USD = 1 * 1e18;
    /// @notice Price at which users can buy zars - magnified by 1e18.
    uint128 public constant PRICE_TOKEN = 0.01 * 1e18;

    IERC20 public zars;
    IStaking public staking;
    address public saleWallet;

    /// @dev Initialization variables.
    address private immutable _INITIALIZER;
    bool private _isInitialized;

    /* ========== ERRORS ========== */

    error AirdropUnauthorizedInitializer();
    error AirdropAlreadyInitialized();
    error AirdropInvalidAddress();
    error AirdropSameVariableReassignment(address newVariable, address oldVariable);
    error AirdropInvalidValue();
    error AirdropInsufficientValue(uint256 argumentValueUSD, uint256 minPurchaseUSD);

    /* ========== EVENTS ========== */

    event UpdatePriceFeed(address newPriceFeed, address oldPriceFeed);
    event AirdropToStake(
        address user,
        uint256 price,
        uint256 value,
        uint256 valueUSD,
        uint256 valueToken
    );

    /* ========== CONSTRUCTOR ========== */

    constructor(address saleWallet_) Ownable(_msgSender()) {
        saleWallet = saleWallet_;
        _INITIALIZER = _msgSender();
    }

    /* ========== INITIALIZE ========== */

    function initialize(address zars_, address staking_) external {
        if (_msgSender() != _INITIALIZER) revert AirdropUnauthorizedInitializer();
        if (_isInitialized) revert AirdropAlreadyInitialized();
        if (zars_ == address(0)) revert AirdropInvalidAddress();
        if (staking_ == address(0)) revert AirdropInvalidAddress();

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

    function updatePriceFeed(address newPriceFeed) external onlyOwner {
        if (newPriceFeed == priceFeed)
            revert AirdropSameVariableReassignment(newPriceFeed, priceFeed);
        emit UpdatePriceFeed({newPriceFeed: newPriceFeed, oldPriceFeed: priceFeed});
        priceFeed = newPriceFeed;
    }

    function airdrop() external payable {
        if (msg.value == 0) revert AirdropInvalidValue();
        uint256 price = priceFeed.getLatestPrice();
        uint256 valueUSD = (msg.value * price) / 1e8;

        if (valueUSD < MIN_PURCHASE_USD)
            revert AirdropInsufficientValue(valueUSD, MIN_PURCHASE_USD);
        uint256 valueToken = (valueUSD * 1e9) / PRICE_TOKEN;
        zars.transferFrom(saleWallet, address(this), valueToken);
        staking.stakeAirdrop(valueToken);
        emit AirdropToStake({
            user: _msgSender(),
            price: price,
            value: msg.value,
            valueUSD: valueUSD,
            valueToken: valueToken
        });
    }
}
