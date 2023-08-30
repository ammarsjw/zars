// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IStaking {
    function stakeAirdrop(uint256 amount) external;

    function stakePresale(uint256 amount) external;
}
