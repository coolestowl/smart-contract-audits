// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {console, Test} from "forge-std/Test.sol";

contract CounterTest is Test {
    uint256 internal constant FORK_BLOCK = 80115970;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BSC_RPC_URL", string("bsc")), FORK_BLOCK);
    }

    function testHello() public {
        console.log("balance:", address(0x2804ADA1C219E50898e75B2Bd052030580f4fbAC).balance);
    }
}
