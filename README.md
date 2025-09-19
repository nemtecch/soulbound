# Decentralized Identity & Reputation with Soulbound Credentials (SBTs)

A comprehensive blockchain-based identity and reputation system built on the Stacks blockchain using Clarity smart contracts. This system enables the creation, management, and verification of non-transferable credentials that are permanently bound to wallet addresses.

## 🎯 Overview

This project implements a decentralized identity system where credentials are represented as Soulbound Tokens (SBTs) - non-transferable NFTs that cannot be sold or moved once issued. These credentials serve as tamper-proof digital identity proofs that can be verified across the entire Web3 ecosystem.

## ✨ Core Features

### 1. Soulbound Credential NFTs (SBTs) ✅
- **Non-transferable**: Credentials are permanently bound to recipient wallets
- **Rich Metadata**: Each credential contains issuer, type, issue date, expiry, and custom data
- **Multiple Types**: Support for university degrees, certifications, government IDs, DAO memberships
- **Expiry Support**: Time-bound credentials with automatic expiration
- **Revocation**: Issuers can revoke credentials for fraud or misconduct

### 2. Issuer Governance System ✅
- **Authorized Issuers**: Smart contract registry of authorized credential issuers
- **Type-specific Authorization**: Only authorized entities can issue specific credential types
- **Decentralized Control**: Contract owner manages issuer permissions
- **Multi-issuer Support**: Future support for credentials requiring multiple signatures

### 3. Standardized Verification ✅
- **Universal Verification**: Any dApp can verify credentials without off-chain dependencies
- **Type-based Queries**: Check if a wallet holds specific credential types
- **Status Validation**: Automatic checking of expiry and revocation status
- **Cross-contract Integration**: Easy integration with DeFi, DAOs, and other protocols

## 🏗️ Architecture

### Smart Contract Structure
\`\`\`
contracts/
└── soulbound-credentials.cty    # Main SBT credential contract (Feature 1)
\`\`\`

### Technology Stack
- **Blockchain**: Stacks (Bitcoin Layer 2)
- **Smart Contract Language**: Clarity
- **Development Tool**: Clarinet
- **NFT Standard**: SIP-009 (Modified for non-transferability)
- **Testing Framework**: Clarinet Test Suite

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- [Stacks CLI](https://docs.stacks.co/docs/cli) for deployment
- Node.js 16+ for development tools

### Installation

1. **Clone the repository**
   \`\`\`bash
   git clone https://github.com/your-org/soulbound-credentials.git
   cd soulbound-credentials
   \`\`\`

2. **Initialize Clarinet project**
   \`\`\`bash
   clarinet new soulbound-credentials
   cd soulbound-credentials
   \`\`\`

3. **Install dependencies**
   \`\`\`bash
   npm install
   \`\`\`

### Development Setup

1. **Start local blockchain**
   \`\`\`bash
   clarinet integrate
   \`\`\`

2. **Run tests**
   \`\`\`bash
   clarinet test
   \`\`\`

3. **Deploy to testnet**
   \`\`\`bash
   clarinet deploy --testnet
   \`\`\`

## 📋 Smart Contract API

### Feature 1: Soulbound Credential NFTs

#### Public Functions

**`issue-credential`**
```clarity
(issue-credential (recipient principal) 
                  (credential-type (string-ascii 50)) 
                  (metadata (string-utf8 500)) 
                  (expiry (optional uint)))
