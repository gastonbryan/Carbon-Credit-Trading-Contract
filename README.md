# 🌱 Carbon Credit Trading Contract

A comprehensive smart contract for carbon credit issuance, trading, and retirement on the Stacks blockchain.

## 🎯 Features

### 🏭 Credit Issuance
- **Authorized Issuers**: Only verified entities can issue carbon credits
- **Project Tracking**: Credits linked to specific environmental projects
- **Vintage Dating**: Credits tagged with vintage year for compliance

### 💱 Marketplace Trading
- **Peer-to-Peer Trading**: Direct credit transfers between users
- **Marketplace Listings**: Create time-limited credit sales
- **Automated Settlement**: Secure STX payments with automatic credit transfer

### ♻️ Credit Management
- **Credit Retirement**: Permanently remove credits from circulation
- **Batch Operations**: Transfer or retire multiple credits efficiently
- **Balance Tracking**: Real-time user credit balances

### 📊 Analytics & Reporting
- **Project Statistics**: Total credits issued per project
- **Contract Metrics**: System-wide issuance and retirement data
- **Vintage Filtering**: Query credits by vintage year
- **Price History**: Track marketplace pricing trends

## 🚀 Quick Start

### Deploy Contract
```bash
clarinet deploy --testnet
```

### Basic Usage

#### Issue Credits (Authorized Issuers Only)
```clarity
(contract-call? .carbon-credit-trading-contract issue-credits u1000 "FOREST-001" u2023)
```

#### Transfer Credits
```clarity
(contract-call? .carbon-credit-trading-contract transfer-credits u1 'SP1ABC...)
```

#### Create Marketplace Listing
```clarity
(contract-call? .carbon-credit-trading-contract create-listing u1 u500000 u144)
```

#### Buy Credits from Marketplace
```clarity
(contract-call? .carbon-credit-trading-contract buy-credits u1)
```

#### Retire Credits
```clarity
(contract-call? .carbon-credit-trading-contract retire-credits u1)
```

## 📋 Contract Functions

### 🔐 Admin Functions
- `authorize-issuer` - Grant issuing permissions
- `revoke-issuer` - Remove issuing permissions

### 🏭 Credit Operations
- `issue-credits` - Create new carbon credits
- `transfer-credits` - Transfer ownership
- `retire-credits` - Permanently remove from circulation
- `batch-transfer` - Transfer multiple credits
- `batch-retire` - Retire multiple credits

### 🏪 Marketplace Functions
- `create-listing` - List credits for sale
- `cancel-listing` - Remove listing
- `buy-credits` - Purchase listed credits

### 📊 Read-Only Functions
- `get-credit-info` - Get credit details
- `get-user-balance` - Check user's total credits
- `get-project-total` - Total credits for project
- `get-contract-stats` - System-wide statistics
- `is-credit-available` - Check if credit is active

## 🔍 Error Codes

| Code | Description |
|------|-------------|
| u100 | Owner only operation |
| u101 | Not authorized |
| u102 | Insufficient balance |
| u103 | Invalid amount |
| u104 | Credit not found |
| u105 | Credit already retired |
| u106 | Invalid price |
| u107 | Listing not found |
| u108 | Cannot buy own listing |
| u109 | Listing expired |

## 🧪 Testing

```bash
npm install
npm test
```

## 🌍 Environmental Impact

This contract enables:
- **Transparent Carbon Markets**: Immutable record of credit creation and retirement
- **Compliance Tracking**: Auditable carbon offset verification
- **Market Efficiency**: Reduced friction in carbon credit trading
- **Environmental Accountability**: Permanent retirement prevents double-counting

## 📝 License

MIT License - see LICENSE file for details


## 📞 Support

For questions or issues, please open a GitHub issue or contact the development team.

---

**Built with 💚 for a sustainable future**
