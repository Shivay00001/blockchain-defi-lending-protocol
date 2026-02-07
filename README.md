# Blockchain DeFi Lending Protocol

[![Solidity](https://img.shields.io/badge/Solidity-0.8.20-blue.svg)](https://soliditylang.org/)
[![Hardhat](https://img.shields.io/badge/Hardhat-2.19-yellow.svg)](https://hardhat.org/)
[![OpenZeppelin](https://img.shields.io/badge/OpenZeppelin-5.0-green.svg)](https://openzeppelin.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A **production-grade decentralized lending protocol** built on Ethereum. Enables users to supply assets, earn interest, borrow against collateral, and participate in liquidations.

## 🚀 Features

- **Supply & Earn**: Deposit assets to earn variable interest rates
- **Collateralized Borrowing**: Borrow against supplied collateral
- **Dynamic Interest Rates**: Utilization-based rate model
- **Liquidations**: Incentivized liquidation mechanism for undercollateralized positions
- **Flash Loans**: Uncollateralized loans within a single transaction
- **Multi-Asset Support**: ERC20 token support with price oracles
- **Governance**: Token-based protocol governance

## 📁 Project Structure

```
blockchain-defi-lending-protocol/
├── contracts/
│   ├── core/
│   │   ├── LendingPool.sol         # Main lending pool logic
│   │   ├── LendingPoolStorage.sol  # Storage layout
│   │   └── InterestRateModel.sol   # Interest rate calculations
│   ├── tokens/
│   │   ├── AToken.sol              # Interest-bearing token
│   │   └── DebtToken.sol           # Debt tracking token
│   ├── liquidation/
│   │   └── LiquidationManager.sol  # Liquidation logic
│   ├── oracle/
│   │   └── PriceOracle.sol         # Price feed integration
│   ├── governance/
│   │   └── GovernanceToken.sol     # Protocol governance
│   └── interfaces/
│       └── *.sol                   # Contract interfaces
├── test/
│   ├── LendingPool.test.js
│   ├── InterestRate.test.js
│   └── Liquidation.test.js
├── scripts/
│   ├── deploy.js
│   └── verify.js
├── hardhat.config.js
└── README.md
```

## 🛠️ Installation

```bash
# Clone repository
git clone https://github.com/Shivay00001/blockchain-defi-lending-protocol.git
cd blockchain-defi-lending-protocol

# Install dependencies
npm install

# Compile contracts
npx hardhat compile

# Run tests
npx hardhat test

# Deploy to local network
npx hardhat node
npx hardhat run scripts/deploy.js --network localhost
```

## 📖 Core Concepts

### Lending Pool

The main entry point for users. Handles deposits, withdrawals, borrows, and repayments.

### Interest Rate Model

```
Utilization Rate = Total Borrows / Total Deposits
Borrow Rate = Base Rate + (Utilization * Slope1)  [if U < Optimal]
Borrow Rate = Base Rate + Slope1 + (U - Optimal) * Slope2  [if U >= Optimal]
```

### Health Factor

```
Health Factor = (Collateral Value * Liquidation Threshold) / Borrow Value
If Health Factor < 1, position can be liquidated
```

## 🔐 Security

- Reentrancy guards on all external functions
- Access control with role-based permissions
- Pausable functionality for emergencies
- Comprehensive test coverage
- Slither static analysis

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.
