// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import {IPancakeFactory} from "./interfaces/IPancakeFactory.sol";
import {IPancakeRouter02} from "./interfaces/IPancakeRouter02.sol";

import {ERC20} from "./utils/ERC20.sol";
import {Ownable} from "./utils/Ownable.sol";

contract Zars is ERC20, Ownable {

    /* ========== STATE VARIABLES ========== */

    // TODO change to 0x10ED43C718714eb63d5aA57B78B54704E256024E
    /// @notice Address of the DEX router.
    IPancakeRouter02 public router =
        IPancakeRouter02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

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

    /* ========== ERRORS ========== */

    error ZarsSameVariableAssignment(address newVariable, address oldVariable);
    error ZarsSameStateAssignment(bool newState, bool oldState);

    /* ========== EVENTS ========== */

    event UpdateRouter(address newRouter, address oldRouter);
    event ExcludeFromFees(address user, bool isExcluded);
    event ExcludeMultipleFromFees(address[] users, bool isExcluded);
    event SetAutomatedMarketMakerPair(address pair, bool isPair);

    /* ========== CONSTRUCTOR ========== */

    // TODO name and symbol
    constructor(
        address[4] memory feeCollectors_,
        address saleWallet_,
        address stakingRewardWallet_
    ) ERC20("Zars", "ZRS") Ownable(_msgSender()) {
        _decimals = 9;

        uint256[] memory feePercentages = new uint256[](4);
        feePercentages[0] = 2; // DAO
        feePercentages[1] = 1; // Development
        feePercentages[2] = 1; // Marketing
        feePercentages[3] = 1; // Liquidity

        for (uint256 i = 0; i < getFees.length; i++) {
            getFees[i] = Fee(feePercentages[i], feeCollectors_[i]);

            if (!isExcludedFromFees[feeCollectors_[i]]) excludeFromFees(feeCollectors_[i], true);
        }
        excludeFromFees(address(this), true);
        excludeFromFees(owner(), true);
        excludeFromFees(saleWallet_, true);
        excludeFromFees(stakingRewardWallet_, true);

        /// @dev Creating a pair for this token.
        address pair = IPancakeFactory(router.factory()).createPair(address(this), router.WETH());

        setAutomatedMarketMakerPair(pair, true);

        uint256 totalSupply = 21_000_000 * (10 ** _decimals);
        _mint(owner(), (totalSupply * 40) / 100); // Reserved
        _mint(saleWallet_, (totalSupply * 50) / 100); // Airdrop and presale
        _mint(stakingRewardWallet_, (totalSupply * 10) / 100); // Staking rewards
    }

    /* ========== FUNCTIONS ========== */

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function updateRouter(address newRouter) external onlyOwner {
        if (newRouter == address(router))
            revert ZarsSameVariableAssignment(newRouter, address(router));
        emit UpdateRouter({newRouter: newRouter, oldRouter: address(router)});
        router = IPancakeRouter02(newRouter);
    }

    function excludeFromFees(address user, bool isExcluded) public onlyOwner {
        if (isExcludedFromFees[user] == isExcluded)
            revert ZarsSameStateAssignment(isExcludedFromFees[user], isExcluded);
        isExcludedFromFees[user] = isExcluded;
        emit ExcludeFromFees({user: user, isExcluded: isExcluded});
    }

    function excludeMultipleFromFees(address[] calldata users, bool isExcluded) external onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            isExcludedFromFees[users[i]] = isExcluded;
        }
        emit ExcludeMultipleFromFees({users: users, isExcluded: isExcluded});
    }

    function setAutomatedMarketMakerPair(address pair, bool isPair) public onlyOwner {
        if (automatedMarketMakerPairs[pair] != isPair)
            revert ZarsSameStateAssignment(automatedMarketMakerPairs[pair], isPair);
        automatedMarketMakerPairs[pair] = isPair;
        emit SetAutomatedMarketMakerPair({pair: pair, isPair: isPair});
    }

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
     * @dev Transfer from pair is a buy swap.
     */
    function _isBuy(address from) internal view returns (bool) {
        return automatedMarketMakerPairs[from];
    }

    /**
     * @dev Transfer from non-router address to pair is a sell swap.
     */
    function _isSell(address from, address to) internal view returns (bool) {
        return from != address(router) && automatedMarketMakerPairs[to];
    }
}
