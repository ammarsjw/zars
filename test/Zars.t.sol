// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import "forge-std/Test.sol";

import { Zars } from "contracts/Zars.sol";

contract ZarsTest is Test {

    /* ========== STATE VARIABLES ========== */

    // Setup variables.
    address[4] feeCollectors = [
        0x0000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000002,
        0x0000000000000000000000000000000000000003,
        0x0000000000000000000000000000000000000004
    ];
    address saleWallet = 0x49A61ba8E25FBd58cE9B30E1276c4Eb41dD80a80;
    address stakingRewardWallet = 0x3edCe801a3f1851675e68589844B1b412EAc6B07;

    // Protocol contracts.
    Zars zars;

    /* ========== ERRORS ========== */

    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

    /* ========== SETUP ========== */

    /**
     * @dev Invoked before each test.
     */
    function setUp() public {
        zars = new Zars("Zars", "ZRS", 9, feeCollectors, saleWallet, stakingRewardWallet);
    }

    /* ========== TESTS ========== */

    function testTransfer() public {
        zars.transfer(address(1), (zars.totalSupply() * 40) / 100);
        assertEq(zars.balanceOf(address(this)), 0);
    }

    function testTransferFail() public {
        uint256 amountToken = ((zars.totalSupply() * 40) / 100) + 1;

        bytes4 selector = bytes4(keccak256(
            "ERC20InsufficientBalance(address,uint256,uint256)"
        ));
        vm.expectRevert(abi.encodeWithSelector(
            selector,
            address(this), zars.balanceOf(address(this)), amountToken
        ));

        zars.transfer(address(1), amountToken);
    }
}
