// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { ZarsErrors } from "./interfaces/Errors.sol";
import { IPancakeFactory } from "./interfaces/IPancakeFactory.sol";
import { IPancakeRouter02 } from "./interfaces/IPancakeRouter02.sol";

import { ERC20 } from "./utils/ERC20.sol";
import { Ownable } from "./utils/Ownable.sol";

/**
 * @title Zars token.
 * @author Zars team.
 * @notice Primary token contract.
 */
contract Zars is ZarsErrors, ERC20, Ownable {

    /* ========== STATE VARIABLES ========== */

    // TODO change to 0x10ED43C718714eb63d5aA57B78B54704E256024E
    /// @notice Address of the DEX router.
    IPancakeRouter02 public router =
        IPancakeRouter02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    /// @dev Number of decimals for user representation.
    uint8 private _decimals;

    /* ========== STORAGE ========== */

    struct Fee {
        uint256 percentage;
        address collector;
    }

    /// @notice Returns the fee details.
    Fee[4] public getFees;
    /// @notice Returns whether an address is exlcuded from fees.
    mapping(address => bool) public isExcludedFromFees;
    /// @notice Returns whether an address is a market maker pair.
    mapping(address => bool) public automatedMarketMakerPairs;

    /* ========== EVENTS ========== */

    event UpdateRouter(address newRouter, address oldRouter);
    event ExcludeFromFees(address user, bool isExcluded);
    event ExcludeMultipleFromFees(address[] users, bool isExcluded);
    event SetAutomatedMarketMakerPair(address pair, bool isPair);

    /* ========== CONSTRUCTOR ========== */

    /**
     * @dev Constructor.
     * @param name_ Name of the token.
     * @param symbol_ Symbol of the token.
     * @param decimals_ Decimals of the token.
     * @param feeCollectors_ Addresses of the fee collectors.
     * @param saleWallet_ Address of the sale funds holding wallet.
     * @param stakingRewardWallet_ Address of the staking funds holding wallet.
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address[4] memory feeCollectors_,
        address saleWallet_,
        address stakingRewardWallet_
    ) ERC20(name_, symbol_) Ownable(_msgSender()) {
        _decimals = decimals_;

        uint256[] memory feePercentages = new uint256[](4);
        feePercentages[0] = 2;  // DAO
        feePercentages[1] = 1;  // Development
        feePercentages[2] = 1;  // Marketing
        feePercentages[3] = 1;  // Liquidity

        for (uint256 i = 0; i < getFees.length; i++) {
            getFees[i] = Fee(feePercentages[i], feeCollectors_[i]);
            _excludeFromFees(feeCollectors_[i], true);
        }
        _excludeFromFees(address(this), true);
        _excludeFromFees(owner(), true);
        _excludeFromFees(saleWallet_, true);
        _excludeFromFees(stakingRewardWallet_, true);

        /// @dev Creating a pair for this token.
        address pair = IPancakeFactory(router.factory()).createPair(address(this), router.WETH());

        /// @dev Setting aforementioned pair as a market maker pair.
        setAutomatedMarketMakerPair(pair, true);

        uint256 totalSupply = 21_000_000 * (10 ** decimals_);
        _mint(owner(), (totalSupply * 40) / 100);               // Reserved
        _mint(saleWallet_, (totalSupply * 50) / 100);           // Airdrop and presale
        _mint(stakingRewardWallet_, (totalSupply * 10) / 100);  // Staking rewards
    }

    /* ========== FUNCTIONS ========== */

    /**
     * @inheritdoc ERC20
     * @dev See {ERC20-decimals}.
     * @dev Allows a custom decimal amount.
     */
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /**
     * @notice Updates the address of the DEX router. Only the `owner` can call this function.
     * @param newRouter The address of the new DEX router.
     */
    function updateRouter(address newRouter) external onlyOwner {
        if (newRouter == address(router))
            revert IdenticalAddressReassignment(address(router));
        emit UpdateRouter({newRouter: newRouter, oldRouter: address(router)});
        router = IPancakeRouter02(newRouter);
    }

    /**
     * @notice Excludes the given address from fees. All address are included in fee collection by
     * default. Only the `owner` can call this function.
     * @param user The address that needs to be interacted with.
     * @param isExcluded The state denoting either being excluded from or included back to fees.
     */
    function excludeFromFees(address user, bool isExcluded) public onlyOwner {
        if (isExcluded == isExcludedFromFees[user])
            revert SameStateReassignment(isExcludedFromFees[user]);
        _excludeFromFees(user, isExcluded);
    }

    function _excludeFromFees(address user, bool isExcluded) internal {
        if (isExcluded == isExcludedFromFees[user]) return;
        isExcludedFromFees[user] = isExcluded;
        emit ExcludeFromFees({user: user, isExcluded: isExcluded});
    }

    /**
     * @notice Excludes the given addresses from fees. All address are included in fee
     * collection be default. Only the `owner` can call this function.
     * @param users The addresses that need to be interacted with.
     * @param isExcluded The state denoting either being excluded from or included back to fees.
     */
    function excludeMultipleFromFees(address[] calldata users, bool isExcluded) external onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            isExcludedFromFees[users[i]] = isExcluded;
        }
        emit ExcludeMultipleFromFees({users: users, isExcluded: isExcluded});
    }

    /**
     * @notice Adds an address as a market maker pair. Only the `owner` can call this function.
     * @param pair The address of the pair contract.
     * @param isPair The state denoting whether it is a market maker pair or not.
     */
    function setAutomatedMarketMakerPair(address pair, bool isPair) public onlyOwner {
        if (isPair == automatedMarketMakerPairs[pair])
            revert SameStateReassignment(automatedMarketMakerPairs[pair]);
        automatedMarketMakerPairs[pair] = isPair;
        emit SetAutomatedMarketMakerPair({pair: pair, isPair: isPair});
    }

    /**
     * @inheritdoc ERC20
     * @dev See {ERC20-_update}.
     * @dev Includes custom fee logic.
     */
    function _update(address from, address to, uint256 value) internal override {
        if (value == 0) {
            return super._update(from, to, 0);
        }
        if (!isExcludedFromFees[from] || !isExcludedFromFees[to]) {
            Fee[4] memory fees = getFees;

            for (uint256 i = 0; i < fees.length; i++) {
                if (_isBuy(from) || _isSell(from, to)) {
                    uint256 fee = (value * fees[i].percentage) / 100;
                    value -= fee;
                    super._update(from, fees[i].collector, fee);
                }
            }
        }
        super._update(from, to, value);
    }

    /**
     * @dev Used in the overridden `_update` function. If `from` is a pair then this transfer
     * is a buy swap.
     * @param from Address of the sender.
     */
    function _isBuy(address from) internal view returns (bool) {
        return automatedMarketMakerPairs[from];
    }

    /**
     * @dev Used in the overridden `_update` function. If `from` is an address other than the
     * `router` and `to` is a pair then this transfer is a sell swap.
     * @param from Address of the sender.
     * @param to Address of the recipient.
     */
    function _isSell(address from, address to) internal view returns (bool) {
        return from != address(router) && automatedMarketMakerPairs[to];
    }
}
