# EST Token Exploit

**Language: [English](https://github.com/coolestowl/smart-contract-audits/blob/main/src/reproductions/260327-EST/README.md) | [中文](https://github.com/coolestowl/smart-contract-audits/blob/main/src/reproductions/260327-EST/README.cn.md)**

## Overview

| Item | Detail |
|------|--------|
| **Chain** | BSC (BNB Smart Chain) |
| **Target** | [EST Token](https://bscscan.com/address/0xD4524Be41cd452576aB9FF7b68a0b89aF8498a91) |
| **Block** | 89,060,337 |
| **Category** | Whitelist Bypass + Price Manipulation |

The attacker deployed a contract and sent on-chain messages to attract EST holders into selling at a premium, genuinely paying above market price to acquire the initial tokens. Fund tracing (via [Symbiosis bridge](https://explorer.symbiosis.finance/transactions)): Cronos → BSC → Base → BSC.

- [Buyer sender](https://bscscan.com/address/0x01407631f07be7c13ac9e06f47021adb0df2958d)
- [High-price acquisition contract](https://bscscan.com/address/0xf8e80f5af23f4a48d3886296d1d0fae5e2e29985#code)

## Vulnerability

1. **Whitelist bypasses the buy restriction** — EST whitelists `BNBDeposit` (as `burnReceiver`) with `_isExcludedFromFee`. When `swapsEnabled = false`, the buy guard is skipped whenever either `from` or `to` is whitelisted, so anyone can buy EST from the Pair by routing the output to BNBDeposit.

2. **BNBDeposit proportional claim is manipulable** — Users deposit BNB to earn LP shares and claim EST via `contractBalance × lpAmount / totalLP`, capped at 5× their deposited LP value in USDT, **evaluated at the real-time price at claim time**. The attacker first inflates the contract balance with a small buy, then claims before the large pump, maximizing the token count under the same USD cap.

3. **Delayed sell burn has no cooldown** — Every EST sell records `transferAmount` into `_pendingSellBurn`. The next non-buy transfer triggers it, burning up to 10% of the Pair's EST balance and calling `sync()`. There is no rate limit; it can be triggered in an unbounded loop.

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
