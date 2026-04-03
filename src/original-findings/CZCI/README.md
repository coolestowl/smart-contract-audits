# CZCI Token Presale Exploit

## Overview

| Item | Detail |
|------|--------|
| **Chain** | BSC (BNB Smart Chain) |
| **Target** | [CZCI Token](https://bscscan.com/address/0xfE447da6ec701C5003696395CB276c9b5B0eB80D) |
| **Block** | 47,143,639 |
| **Category** | Presale Logic Flaw |

## Vulnerability

CZCI 合约存在多个设计缺陷的组合利用：

1. **`isContract` 检查可绕过** — 合约使用 `Address.isContract(msg.sender)` 限制 EOA 调用，但在构造函数（constructor）中调用时，合约字节码尚未写入存储，该检查返回 `false`，从而被绕过。
2. **Inviter 地址无校验** — `fallback()` 函数通过 `extractAddress()` 从 calldata 提取地址作为 inviter，未验证该地址是否为合法用户。攻击者可将 Pancake 流动性池地址设为 inviter，使池子获得 5% 的邀请奖励代币。
3. **流动性初始化缺乏保护** — 添加流动性时未检查是否已初始化、无价格校验，且 slippage 参数为 0。攻击者可提前向池子注入少量 WBNB 并 `sync()` 来操控初始价格。
4. **单地址购买限制可绕过** — 每地址限制 2 次 `MintTokens()`，但攻击者通过部署多个子合约（constructor 中完成购买后 selfdestruct）批量参与，直至 `accumulatedEth` 达到 `MAX_PRESALE_BNB`（64 BNB）触发合约自动添加流动性。

## Attack Flow

```
Attacker
  │
  ├─ 1. 向 Pancake Pair 转入少量 WBNB，准备操控初始化价格
  │
  ├─ 2. 调用 CZCI fallback()，携带 pool 地址作为 calldata
  │     └─ extractAddress() 将 pool 设为 inviter
  │     └─ MintTokens() 执行：90% 给购买者，5% 给 pool（inviter），5% 给 CZ
  │
  ├─ 3. 调用 pool.sync() → 池子获得邀请奖励代币，更新储备，初始化流动性
  │
  ├─ 4. 循环部署 AttackerHelper 子合约（绕过 isContract + 单地址限制）
  │     ├─ 每个 Helper 在 constructor 中发送 BNB 参与预售
  │     ├─ approve CZCI 给 Attacker
  │     └─ selfdestruct
  │     └─ 持续直到 accumulatedEth == MAX_PRESALE_BNB → 合约自动 addLiquidity()
  │
  ├─ 5. transferFrom 从所有 Helper 收集 CZCI 代币
  │
  ├─ 6. 通过 PancakeSwap 卖出全部 CZCI → WBNB（掏空新添加的流动性）
  │
  └─ 7. WBNB → BNB，selfdestruct 将利润返还给调用者
```

## Reproduce

```bash
forge test --match-contract CZCITest -vvv
```

## Files

| File | Description |
|------|-------------|
| [CZCI.sol](./CZCI.sol) | PoC 测试合约及攻击合约 |
| [interfaces.sol](./interfaces.sol) | WBNB / Uniswap Router & Pair 接口定义 |

## Key Takeaways

- **不要依赖 `isContract()` 做访问控制** — constructor 中调用可轻易绕过，应使用 `tx.origin == msg.sender` 或其他机制。
- **Inviter/Referral 地址必须校验** — 允许任意地址作为 inviter 会导致奖励代币流向非预期地址（如流动性池）。
- **流动性添加需保护** — 应检查是否已初始化、设置合理的 slippage，防止被抢跑或价格操纵。
- **单地址限制无法防御合约工厂攻击** — 通过 constructor + selfdestruct 模式可批量创建地址绕过限制。
- **`renounceOwnership()` 需谨慎** — 一旦放弃所有权，合约出现漏洞将无法修复。

## Reference

- [原始分析文章](https://life.coolestowl.me/posts/2603/28/)
