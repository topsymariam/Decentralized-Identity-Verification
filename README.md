# Decentralized Identity Verification Contract

A comprehensive Clarity smart contract for decentralized identity management, verification, and reputation tracking on the Stacks blockchain.

## Overview

This contract provides a trustless system for identity verification where multiple independent verifiers can attest to user identities, creating a decentralized web of trust. Users can manage their digital identities, build reputation scores, and implement recovery mechanisms without relying on centralized authorities.

## Key Features

### 🆔 Identity Management
- **Create Identity**: Register with cryptographic hash representation
- **Update Identity**: Modify identity hash with proper authorization
- **Reputation System**: Earn reputation through verifications and activity
- **Activity Tracking**: Monitor last activity and verification counts

### ✅ Verification System
- **Multi-Verifier Approach**: Require multiple independent verifications
- **Configurable Threshold**: Admin-set minimum verifications for full verification status
- **Time-Limited Verifications**: Verifications expire after ~1 year (52,560 blocks)
- **Fee-Based System**: Pay verification fees to prevent spam
- **Metadata Support**: Include verification type and additional context

### 🔐 Security Features
- **Challenge-Response**: Cryptographic challenges for identity validation
- **Recovery Guardians**: Designate trusted guardians for account recovery
- **Guardian Approval System**: Multi-signature recovery process
- **Input Validation**: Comprehensive validation of all user inputs
- **Access Controls**: Role-based permissions throughout the system

### 🏆 Verifier Network
- **Staking Mechanism**: Verifiers must stake minimum 5 STX to participate
- **Reputation Tracking**: Verifiers earn reputation through quality verifications
- **Economic Incentives**: Fee distribution and stake-based participation
- **Performance Metrics**: Track verification counts and accuracy

## Contract Architecture

### Data Structures

```clarity
;; Core identity information
identities: {
  hash: (buff 32),           // Cryptographic identity hash
  created-at: uint,          // Registration timestamp
  verified: bool,            // Verification status
  reputation-score: uint,    // Accumulated reputation
  verification-count: uint,  // Number of verifications received
  last-activity: uint        // Last interaction timestamp
}

;; Verifier information
verifiers: {
  active: bool,             // Verifier status
  reputation: uint,         // Verifier reputation score
  verifications-made: uint, // Total verifications performed
  stake: uint,              // Staked STX amount
  joined-at: uint           // Registration timestamp
}
```

### Key Functions

#### Identity Functions
- `create-identity(identity-hash)` - Register new identity
- `update-identity(new-hash)` - Update identity hash
- `get-identity(user)` - Retrieve identity information
- `is-verified(user)` - Check verification status

#### Verification Functions
- `register-verifier(stake)` - Join as verifier with stake
- `verify-identity(identity, type, metadata)` - Verify an identity
- `get-verification-status(identity, verifier)` - Check verification details

#### Security Functions
- `create-challenge(challenge-hash)` - Create identity challenge
- `solve-challenge(identity, solution)` - Solve identity challenge
- `add-recovery-guardian(guardian)` - Add recovery guardian
- `initiate-recovery(identity, new-hash)` - Start recovery process

#### Admin Functions
- `set-verification-fee(new-fee)` - Update verification fee
- `set-min-verification-threshold(threshold)` - Set minimum verifications
- `toggle-contract-status()` - Enable/disable contract
- `withdraw-fees(amount)` - Withdraw accumulated fees

## Usage Examples

### 1. Register as User
```clarity
;; Create identity with hash
(contract-call? .identity-contract create-identity 0x1234567890abcdef...)

;; Check verification status
(contract-call? .identity-contract is-verified 'SP1ABC...)
```

### 2. Become a Verifier
```clarity
;; Register with 5 STX stake
(contract-call? .identity-contract register-verifier u5000000)

;; Verify an identity
(contract-call? .identity-contract verify-identity 'SP1ABC... "KYC" (some "Government ID verified"))
```

### 3. Set Up Recovery
```clarity
;; Add trusted guardian
(contract-call? .identity-contract add-recovery-guardian 'SP2DEF...)

;; Guardian approves
(contract-call? .identity-contract approve-guardian 'SP1ABC...)
```

## Economic Model

### Fees & Stakes
- **Minimum Verifier Stake**: 5 STX
- **Default Verification Fee**: 1 STX (configurable)
- **Maximum Fee Limit**: 100 STX
- **Fee Distribution**: Collected by contract, withdrawable by admin

### Reputation System
- **Base Verification Reward**: 10 reputation points
- **Verifier Bonus**: Additional points based on verifier reputation
- **Verifier Reputation**: +5 points per verification performed
- **Starting Verifier Reputation**: 100 points

## Security Considerations

### Input Validation
- Hash length validation (1-32 bytes)
- String length limits (1-20 characters for types, 1-100 for metadata)
- Principal address validation
- Numeric bounds checking

### Access Controls
- Owner-only admin functions
- Verifier authorization checks
- Identity ownership verification
- Guardian approval requirements

### Economic Security
- Staking requirements prevent sybil attacks
- Verification fees prevent spam
- Reputation system incentivizes quality
- Time-limited verifications ensure freshness

## Error Codes

| Code | Name | Description |
|------|------|-------------|
| 100 | ERR_NOT_AUTHORIZED | Insufficient permissions |
| 101 | ERR_IDENTITY_EXISTS | Identity already registered |
| 102 | ERR_IDENTITY_NOT_FOUND | Identity not found |
| 103 | ERR_INVALID_VERIFIER | Invalid or inactive verifier |
| 104 | ERR_ALREADY_VERIFIED | Already verified by this verifier |
| 105 | ERR_VERIFICATION_EXPIRED | Verification has expired |
| 106 | ERR_INVALID_CHALLENGE | Invalid challenge solution |
| 107 | ERR_INSUFFICIENT_REPUTATION | Not enough reputation |
| 108 | ERR_INVALID_INPUT | Input validation failed |

## Deployment

1. Deploy contract to Stacks blockchain
2. Set initial verification fee and threshold
3. Fund contract for fee collection
4. Register initial verifiers
5. Begin identity registrations

## Configuration

### Default Settings
- **Minimum Verification Threshold**: 3 verifications
- **Verification Fee**: 1 STX
- **Verification Expiry**: ~1 year (52,560 blocks)
- **Recovery Window**: ~1 week (1,008 blocks)

### Adjustable Parameters
- Verification fee (admin only)
- Minimum verification threshold (admin only)
- Contract active status (admin only)

