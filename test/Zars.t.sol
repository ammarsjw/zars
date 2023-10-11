// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import "forge-std/Test.sol";

import { Zars } from "contracts/Zars.sol";

contract CounterTest is Test {
    Zars zars;

    address saleWallet = 0x49A61ba8E25FBd58cE9B30E1276c4Eb41dD80a80;
    address stakingRewardWallet = 0x3edCe801a3f1851675e68589844B1b412EAc6B07;

    address[4] feeCollectors = [
        0x0000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000002,
        0x0000000000000000000000000000000000000003,
        0x0000000000000000000000000000000000000004
    ];

    function setUp() public {
        zars = new Zars("Zars", "ZRS", 9, feeCollectors, saleWallet, stakingRewardWallet);
    }

    // function test_nothing() external {
    // }
}
