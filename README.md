# Smart Contract Audits

[![Github Actions](https://github.com/coolestowl/smart-contract-audits/actions/workflows/test.yml/badge.svg)](https://github.com/coolestowl/smart-contract-audits/actions)
![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C?logo=ethereum)
![Solidity](https://img.shields.io/badge/Solidity-%5E0.8.0-363636?logo=solidity)
![Last Commit](https://img.shields.io/github/last-commit/coolestowl/smart-contract-audits)
[![Blog](https://img.shields.io/badge/Blog-coolestowl.me-blue?logo=hugo)](https://coolestowl.me)

智能合约安全审计与漏洞复现集合，基于 [Foundry](https://book.getfoundry.sh/) 框架构建。

## Structure

```
src/
├── original-findings/   # 原创发现的漏洞分析与 PoC
│   └── CZCI/            # CZCI 预售逻辑缺陷
└── reproductions/       # 已知漏洞的复现
```

## Findings

### Original Findings

| # | Name | Chain | Category | Link |
|---|------|-------|----------|------|
| 1 | CZCI Token Presale Exploit | BSC | Presale Logic Flaw | [Detail](./src/original-findings/CZCI/) |

### Reproductions

_TBD_

## Quick Start

```bash
# Install dependencies
forge install

# Run all tests
forge test

# Run specific finding
forge test --match-contract CZCITest -vvv
```

## Tech Stack

- [Foundry](https://book.getfoundry.sh/) — Solidity 开发 & 测试框架
- [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts) — 标准合约库
