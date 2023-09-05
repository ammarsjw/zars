// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { AggregatorV3Interface } from "../interfaces/AggregatorV3Interface.sol";

/**
 * @title PriceFeed.
 * @notice Parses data from the aggregator to be used in the contracts.
 */
library PriceFeed {
    /**
     * @dev Fetches the price of ETH from the given price feed.
     * @param aggregator Address of any standard chainlink aggregator.
     * @return price Price of ETH in 8 decimals.
     */
    function getLatestPriceETH(AggregatorV3Interface aggregator) internal view returns (uint256 price) {
        (
            /*roundId uint80*/,
            int256 answer,
            /*startedAt uint256*/,
            /*updatedAt uint256*/,
            /*answeredInRound uint80*/
        ) = aggregator.latestRoundData();
        price = uint256(answer);
    }
}
