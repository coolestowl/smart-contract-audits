# Smart Contract Audits

**Language: [English](https://github.com/coolestowl/smart-contract-audits/blob/main/README.md) | [中文](https://github.com/coolestowl/smart-contract-audits/blob/main/README.cn.md)**

[![Github Actions](https://github.com/coolestowl/smart-contract-audits/actions/workflows/test.yml/badge.svg)](https://github.com/coolestowl/smart-contract-audits/actions)
![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C?logo=ethereum)
![Solidity](https://img.shields.io/badge/Solidity-%5E0.8.0-363636?logo=solidity)
![Last Commit](https://img.shields.io/github/last-commit/coolestowl/smart-contract-audits)
[![Blog](https://img.shields.io/badge/Blog-coolestowl.me-blue?logo=hugo)](https://coolestowl.me)

A collection of smart contract security audits and vulnerability reproductions, built with [Foundry](https://book.getfoundry.sh/).

## Structure

```
src/
├── original-findings/   # Original vulnerability analyses & PoCs
│   └── CZCI/            # CZCI presale logic flaw
└── reproductions/       # Reproductions of known vulnerabilities
    └── 260327-EST/      # EST token whitelist bypass & price manipulation
```

## Findings

### Original Findings

| # | Name | Chain | Category | Impact | Link |
|---|------|-------|----------|--------|------|
| 1 | CZCI Token Presale Exploit | BSC | Presale Logic Flaw | ![Loss](https://img.shields.io/badge/loss-61.8_BNB-red) | [Detail](./src/original-findings/CZCI/) |

### Reproductions

| # | Name | Chain | Category | Impact | Link |
|---|------|-------|----------|--------|------|
| 1 | EST Token Exploit | BSC | Whitelist Bypass + Price Manipulation | ![Loss](https://img.shields.io/badge/loss-150.2_WBNB-red) | [Detail](./src/reproductions/260327-EST/) |

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

- [Foundry](https://book.getfoundry.sh/) — Solidity development & testing framework
- [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts) — Standard contract library
