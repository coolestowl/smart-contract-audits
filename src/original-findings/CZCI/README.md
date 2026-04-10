# CZCI Token Presale Exploit

**Language: [English](https://github.com/coolestowl/smart-contract-audits/blob/main/src/original-findings/CZCI/README.md) | [中文](https://github.com/coolestowl/smart-contract-audits/blob/main/src/original-findings/CZCI/README.cn.md)**

## Overview

| Item | Detail |
|------|--------|
| **Chain** | BSC (BNB Smart Chain) |
| **Target** | [CZCI Token](https://bscscan.com/address/0xfE447da6ec701C5003696395CB276c9b5B0eB80D) |
| **Block** | 47,143,639 |
| **Category** | Presale Logic Flaw |

## Vulnerability

The CZCI contract is exploitable through a combination of multiple design flaws:

1. **`isContract` check is bypassable** — The contract uses `Address.isContract(msg.sender)` to restrict calls to EOAs only. However, when called from within a constructor, the contract bytecode has not yet been stored, so the check returns `false` and is bypassed.
2. **No validation on inviter address** — The `fallback()` function extracts an address from calldata via `extractAddress()` to use as the inviter, without verifying it is a legitimate user. An attacker can set the Pancake liquidity pool address as the inviter, causing the pool to receive the 5% referral reward tokens.
3. **Unprotected liquidity initialization** — Liquidity addition lacks checks for prior initialization, has no price validation, and uses 0 slippage. An attacker can pre-seed the pool with a small amount of WBNB and call `sync()` to manipulate the initial price.
4. **Per-address purchase limit is bypassable** — Each address is limited to 2 `MintTokens()` calls, but an attacker can deploy multiple child contracts (which complete the purchase in their constructor then selfdestruct) to participate in bulk, until `accumulatedEth` reaches `MAX_PRESALE_BNB` (64 BNB) and the contract automatically adds liquidity.

## Attack Flow

```
Attacker
  │
  ├─ 1. Transfer a small amount of WBNB to the Pancake Pair, preparing to manipulate the initial price
  │
  ├─ 2. Call CZCI fallback() with the pool address as calldata
  │     └─ extractAddress() sets pool as the inviter
  │     └─ MintTokens() executes: 90% to buyer, 5% to pool (inviter), 5% to CZ
  │
  ├─ 3. Call pool.sync() → pool receives referral reward tokens, reserves update, liquidity initialized
  │
  ├─ 4. Deploy AttackerHelper child contracts in a loop (bypassing isContract + per-address limit)
  │     ├─ Each Helper sends BNB to participate in presale within its constructor
  │     ├─ Approves CZCI spending to the Attacker
  │     └─ selfdestructs
  │     └─ Continues until accumulatedEth == MAX_PRESALE_BNB → contract auto-calls addLiquidity()
  │
  ├─ 5. transferFrom to collect CZCI tokens from all Helpers
  │
  ├─ 6. Sell all CZCI for WBNB via PancakeSwap (draining the newly added liquidity)
  │
  └─ 7. WBNB → BNB, selfdestruct to return profits to the caller
```

## Reproduce

```bash
forge test --match-contract CZCITest -vvv
```

## Files

| File | Description |
|------|-------------|
| [CZCI.sol](./CZCI.sol) | PoC test and attack contracts |
| [interfaces.sol](./interfaces.sol) | WBNB / Uniswap Router & Pair interface definitions |

## Key Takeaways

- **Do not rely on `isContract()` for access control** — Calls from a constructor easily bypass it. Use `tx.origin == msg.sender` or other mechanisms instead.
- **Inviter/referral addresses must be validated** — Allowing arbitrary addresses as inviters can cause reward tokens to flow to unintended recipients (e.g., liquidity pools).
- **Liquidity addition needs safeguards** — Check for prior initialization, set reasonable slippage, and prevent front-running or price manipulation.
- **Per-address limits cannot defend against contract factory attacks** — The constructor + selfdestruct pattern enables mass address creation to bypass limits.
- **Use `renounceOwnership()` with caution** — Once ownership is renounced, vulnerabilities in the contract become unfixable.

## Reference

- [Original analysis article](https://life.coolestowl.me/posts/2603/28/)
