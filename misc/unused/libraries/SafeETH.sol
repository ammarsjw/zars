// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

library SafeETH {
    /**
     * @dev Indicates a failure with sending ETH.
     * @param to Address to which ETH is being transferred.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ETHTransferFailed(address to, uint256 needed);

    /**
     * @dev Transfers ETH from `this` to a given address.
     * @param to Address to which ETH is being transferred.
     * @param value Amount of ETH being transferred.
     */
    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));

        if (!success) revert ETHTransferFailed(to, address(this).balance);
    }
}
