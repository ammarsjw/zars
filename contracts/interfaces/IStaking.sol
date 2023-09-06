// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @title IStaking.
 * @author Zars team.
 * @notice Interface for the staking contract.
 */
interface IStaking {
    function stakeAirdrop(uint256 amount) external;

    function stakePresale(uint256 amount) external;
}
