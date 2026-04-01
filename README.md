# Upgradable DeFi Vault with Auditable CI/CD

An **ERC-4626 compliant** yield vault built in Solidity with **UUPS proxy upgradeability**, automated testing via **Foundry**, and static analysis via **Slither**.

## Architecture

```
User ──deposit──► ERC1967Proxy ──delegatecall──► VaultV1 (ERC-4626)
                      │                              │
                      │                     ┌────────┴────────┐
                      │                     │  MockYieldSource │
                      │                     │  (yield strategy)│
                      │                     └─────────────────┘
                      │
                 upgradeTo(VaultV2)
                      │
                      ▼
                  VaultV2 (+ performance fees)
```

## Tech Stack

- **Solidity ^0.8.24** — Smart contract language
- **OpenZeppelin v5** — ERC-4626, UUPS, Ownable
- **Foundry** — Build, test, deploy, fuzz
- **Slither** — Static analysis and vulnerability detection
- **GitHub Actions** — Automated CI/CD pipeline

## Features

- ERC-4626 standard vault interface (deposit, withdraw, redeem, mint)
- UUPS proxy pattern for seamless contract upgrades
- Yield source integration with harvest mechanism
- V2 upgrade adds configurable performance fees
- Invariant (stateful fuzz) testing for solvency guarantees
- Automated Slither analysis in CI

## Quick Start

```bash
# Install dependencies
forge install OpenZeppelin/openzeppelin-contracts
forge install OpenZeppelin/openzeppelin-contracts-upgradeable

# Build
forge build

# Test
forge test -vvv

# Deploy (local anvil)
anvil &
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

## Testing

```bash
# All tests
forge test -vvv

# Only invariant tests
forge test --match-contract Invariant -vvv

# Gas report
forge test --gas-report

# Coverage
forge coverage
```

## Static Analysis

```bash
slither src/ --config-file slither.config.json
```

## Project Structure

```
├── src/
│   ├── VaultV1.sol          # ERC-4626 vault with UUPS proxy
│   ├── VaultV2.sol          # Upgraded vault with performance fees
│   ├── MockERC20.sol        # Test token
│   └── MockYieldSource.sol  # Simulated yield protocol
├── test/
│   ├── VaultTest.t.sol      # Unit tests (14 tests)
│   └── VaultInvariant.t.sol # Invariant fuzz tests
├── script/
│   └── Deploy.s.sol         # Deployment script
├── foundry.toml
└── slither.config.json
```

## Security

- Owner-gated upgrades and yield management
- Invariant tests verify solvency and exchange rate consistency
- Slither static analysis runs on every PR
- Fee capped at 20% maximum (VaultV2)
