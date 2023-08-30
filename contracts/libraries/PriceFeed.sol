// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "../interfaces/AggregatorV3Interface.sol";

library PriceFeed {
    /**
     * @notice Fetches the price of BNB from the BSC price feed.
     * @return price The price of BNB in 8 decimals.
     */
    function getLatestPrice(address aggregator) public view returns (uint256 price) {
        (
            /*roundId uint80*/,
            int256 answer,
            /*startedAt uint256*/,
            /*updatedAt uint256*/,
            /*answeredInRound uint80*/
        ) = AggregatorV3Interface(aggregator).latestRoundData();
        price = uint256(answer);
    }
}
