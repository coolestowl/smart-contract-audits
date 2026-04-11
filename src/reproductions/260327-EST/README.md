# EST Token Exploit

**Language: [English](https://github.com/coolestowl/smart-contract-audits/blob/main/src/reproductions/260327-EST/README.md) | [中文](https://github.com/coolestowl/smart-contract-audits/blob/main/src/reproductions/260327-EST/README.cn.md)**

## Overview

| Item | Detail |
|------|--------|
| **Chain** | BSC (BNB Smart Chain) |
| **Target** | [EST Token](https://bscscan.com/address/0xD4524Be41cd452576aB9FF7b68a0b89aF8498a91) |
| **Block** | 89,060,337 |
| **Category** | Whitelist Bypass + Price Manipulation |

Exploiting this vulnerability requires the attacker to hold at least 1 EST to claim LP rewards from the BNBDeposit contract. The attacker deployed a high-price acquisition contract and broadcast on-chain messages to attract EST holders into selling, genuinely paying to acquire the initial tokens.

- [Contract deployer](https://bscscan.com/address/0x01407631f07be7c13ac9e06f47021adb0df2958d)
- [High-price acquisition contract](https://bscscan.com/address/0xf8e80f5af23f4a48d3886296d1d0fae5e2e29985#code)

Fund tracing (via [Symbiosis bridge](https://explorer.symbiosis.finance/transactions)):

[Base In](https://basescan.org/tx/0x9fcbffef007e9077718db6970b472a15b98b69b01888bab281f7a99f0553f229) -> [Base Out](https://basescan.org/tx/0xf2b9a2d62b2ce0a23323e544a506db225e2277e213aa6757817a2d7356c1d2ae) -> [BSC In](https://bscscan.com/tx/0x540b88282e3fbda9c588256dccd353fbc48665b37ee0cb50ca51ffe67d5fa7c5) -> [BSC Out](https://bscscan.com/tx/0x35934e00bafd2ed4e83f996555f64320f5f419b48e1b4a2a6f2569c9b7cd084c) -> [Cronos In](https://explorer.cronos.org/tx/0x27ea49488e16c67647a4297fd01e31d966faf9e1a80c95fa3a6d284c5e8ca724) -> [Cronos Out](https://explorer.cronos.org/tx/0x0e6a8fc89aec882248e775b4dc36084f17dedbbad6594294b96910bfbbc37812) -> [BSC In](https://bscscan.com/tx/0x80b38a5bd5915dee473d55ae5f03a200e67b13584376e542ad2fbf64159da61f) -> [BSC Out](https://bscscan.com/tx/0x9d158705b9c233180c67a40f0a36f2235eff9fc2038dc7e7318509ffb4a94a8b) -> [Base In](https://basescan.org/tx/0x70dfce105d8106d6ce0ca5bee9686fe333e6066a05347b62c14e425d62ddbcf3) -> [Base Out](https://basescan.org/tx/0xcf83e9fd72363f6a9200d3d281dbc2072982aac83d4b73c17ee6bbf1823f26c7) -> [Deployer funding source](https://bscscan.com/tx/0x280334ce8eb2eb469a129fe8d1d9469f3134c494a6077af394f3bb82b5a55602)

## Vulnerability

1. **Whitelist bypasses buy restriction** — EST whitelists `BNBDeposit` as fee-exempt. When `swapsEnabled = false`, the buy guard requires both `from` and `to` to not be whitelisted, so anyone can buy EST from the Pair by routing the output to BNBDeposit, bypassing the restriction.

2. **BNBDeposit proportional claim is manipulable** — Users deposit BNB to earn LP shares and claim EST via `contractBalance × lpAmount / totalLP`, capped at 5× their deposited LP value in USDT (**evaluated at the real-time price at claim time**). The attacker first inflates the contract balance with a small buy, then claims before the large pump, maximizing the token count under the same USD cap.

3. **Delayed sell burn has no cooldown** — Every EST sell records `transferAmount` into `_pendingSellBurn`. The next non-buy transfer triggers it, burning up to 10% of the Pair's EST balance and calling `sync()`. There is no rate limit; it can be triggered in an unbounded loop.

## Attack Flow

```
Attacker
  │
  ├─ 1. Flash loan 20,000 WBNB from Moolah
  │
  ├─ 2. Unwrap maxDeposit × 30 WBNB → BNB, deposit into BNBDeposit in a loop
  │     └─ Establishes lpAmount
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

- **Burn mechanism without cooldown** — The delayed sell burn has no cooldown and no whitelist restriction; any address can exploit this mechanism to drain the Pair's token balance.
