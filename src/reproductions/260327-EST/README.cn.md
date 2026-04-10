# EST Token Exploit

**语言: [English](https://github.com/coolestowl/smart-contract-audits/blob/main/src/reproductions/260327-EST/README.md) | [中文](https://github.com/coolestowl/smart-contract-audits/blob/main/src/reproductions/260327-EST/README.cn.md)**

## Overview

| Item | Detail |
|------|--------|
| **Chain** | BSC (BNB Smart Chain) |
| **Target** | [EST Token](https://bscscan.com/address/0xD4524Be41cd452576aB9FF7b68a0b89aF8498a91) |
| **Block** | 89,060,337 |
| **Category** | Whitelist Bypass + Price Manipulation |

攻击者事先部署合约并发送链上消息，吸引 EST 持有者以高价卖出，真实付款获取初始筹码。资金溯源（通过 [Symbiosis 跨链桥](https://explorer.symbiosis.finance/transactions)）：Cronos → BSC → Base → BSC。

- [买入发送者](https://bscscan.com/address/0x01407631f07be7c13ac9e06f47021adb0df2958d)
- [高价收购合约](https://bscscan.com/address/0xf8e80f5af23f4a48d3886296d1d0fae5e2e29985#code)

## Vulnerability

1. **白名单绕过买入限制** — EST 合约将 `BNBDeposit`（作为 `burnReceiver`）加入了免税白名单。`swapsEnabled = false` 时，买入检查要求 `from` 和 `to` 均不在白名单，因此任何人都可以以 BNBDeposit 为收款方从 Pair 买入 EST，绕过限制。

2. **BNBDeposit 按比例分配可操纵** — 用户存入 BNB 获得 LP 份额，按 `contractBalance × lpAmount / totalLP` 领取 EST，上限为存入时 LP 价值的 5 倍（USDT 计价，以**领取时实时价格**换算）。攻击者先小额拉高合约余额，再在大额拉盘前领取，使同等上限对应更多代币数量。

3. **延迟卖出销毁无冷却** — 每次向 Pair 卖出 EST 会记入 `_pendingSellBurn`，下一笔非买入交易触发时从 Pair 余额中直接扣除最多 10% 并 `sync()`。没有任何冷却限制，可被无限循环触发。

## Attack Flow

```
Attacker
  │
  ├─ 1. Flash loan 20,000 WBNB from Moolah
  │
  ├─ 2. Unwrap maxDeposit × 30 WBNB → BNB, deposit into BNBDeposit in a loop
  │     └─ Establishes lpAmount; lpValueInUSDT recorded at current low price
  │
  ├─ 3. Swap 400 WBNB → EST, recipient = BNBDeposit (whitelist bypass)
  │     └─ Boosts BNBDeposit's EST balance before claim
  │
  ├─ 4. Transfer 1 EST to BNBDeposit → triggers onTokenReceived → claimToken
  │     └─ Claims EST proportional to LP share at low price, before the big pump
  │
  ├─ 5. Swap all remaining WBNB → EST, recipient = BNBDeposit (whitelist bypass)
  │     └─ Drains Pair's EST, pumps price; WBNB stays in Pair reserves
  │
  ├─ 6. Loop 100×:
  │     ├─ Transfer pairBalance × 10/95 EST to Pair
  │     │   └─ Triggers previous _pendingSellBurn: burns 10% of Pair's EST → sync()
  │     └─ skim(BNBDeposit) — clears unaccounted EST from Pair
  │         └─ Must go to a whitelisted address: after sync(), any transfer from Pair
  │            is detected as remove-liquidity; non-whitelist recipients get burned
  │
  └─ 7. Sell all claimed EST for WBNB → repay flash loan → profit
```

## Reproduce

```bash
forge test --match-contract ESTTest -vvv
```

## Files

| File | Description |
|------|-------------|
| [EST.sol](./EST.sol) | PoC test and attack contracts |
| [interfaces.sol](./interfaces.sol) | WBNB / Uniswap / Moolah interface definitions |

## Key Takeaways

- **Don't whitelist addresses that hold distributable funds** — Making the burn receiver / reward distributor a whitelisted address creates a backdoor that bypasses all trading restrictions.
- **Deflationary mechanics without rate limits are weaponizable** — The delayed sell burn has no cooldown; any actor can loop it to drain the Pair's token balance at 10% per iteration.
- **Claim formulas based on real-time prices are exploitable** — A 5× cap denominated in real-time USD value allows an attacker to extract far more tokens by claiming at a suppressed price before pumping.
