# Trustee

A decentralized stake-based protocol built on the Stacks blockchain that enables secure, transparent, and fair distribution of pooled resources through cryptographic randomness.

## Overview

Trustee is a smart contract protocol that manages stake-based sessions where participants can contribute tokens to a shared treasury. The protocol uses cryptographic randomness to fairly select winners and distribute accumulated rewards, ensuring transparency and trust through blockchain immutability.

## Key Features

- **Secure Stake Management**: Participants can acquire stakes with built-in overflow protection and parameter validation
- **Cryptographic Fairness**: Uses multiple entropy sources for unbiased winner selection
- **Administrative Controls**: System administrators can manage sessions and adjust protocol parameters
- **Transparent Records**: All transactions and outcomes are permanently recorded on-chain
- **Emergency Safety**: Emergency halt functionality for critical situations

## Protocol Architecture

### Core Components

**Session Management**
- Initialize and conclude sessions with administrative oversight
- Track active sessions and prevent overlapping rounds
- Maintain participant rosters with capacity limits

**Stake Acquisition**
- Secure token transfers with overflow protection
- Automatic participant registration
- Cumulative stake tracking per participant

**Random Selection**
- Multi-source entropy generation using block data and transaction context
- Pseudo-random selection algorithm for winner determination
- Tamper-resistant randomness with entropy modifiers

**Treasury Management**
- Secure accumulation of participant stakes
- Automatic reward distribution to selected winners
- Complete audit trail of all transactions

## Smart Contract Functions

### Public Functions

**Administrative Functions**
- `initialize-session()` - Start a new stake session
- `conclude-session()` - End session and distribute rewards
- `emergency-halt()` - Immediately stop active session
- `adjust-parameters(price, threshold)` - Update protocol parameters

**Participant Functions**
- `acquire-stakes(count)` - Purchase stakes in current session

### Read-Only Functions

**System Queries**
- `get-system-status()` - Current protocol state and parameters
- `get-victory-data(epoch)` - Historical winner information
- `get-holder-stakes(participant, epoch)` - Individual stake holdings
- `get-session-info(epoch)` - Session metadata and statistics
- `get-participant-list(epoch)` - Complete participant roster
- `calculate-estimated-payout()` - Current session projections

## Configuration Parameters

### Constraints
- **Minimum Stake Price**: 10 STX
- **Maximum Stake Price**: 10,000 STX
- **Minimum Threshold**: 1 participant
- **Maximum Threshold**: 50 participants
- **Session Capacity**: 75 participants maximum

### Default Settings
- **Initial Stake Price**: 150 STX
- **Minimum Participants**: 5
- **Maximum Capacity**: 75 participants

## Security Features

### Arithmetic Safety
- Overflow protection for all calculations
- Secure addition and multiplication functions
- Parameter validation and bounds checking

### Access Control
- Administrator-only functions for critical operations
- Session state validation for all operations
- Proper error handling with specific error codes

### Error Codes
- `127` - Arithmetic overflow detected
- `400` - Invalid parameter provided
- `403` - Access denied (insufficient permissions)
- `422` - Invalid state for operation
- `423` - Resource locked (capacity exceeded)

## Usage Example

```clarity
;; Administrator initializes a new session
(contract-call? .trustee initialize-session)

;; Participants acquire stakes
(contract-call? .trustee acquire-stakes u3) ;; Purchase 3 stakes

;; Check current system status
(contract-call? .trustee get-system-status)

;; Administrator concludes session when ready
(contract-call? .trustee conclude-session)
```

## Technical Requirements

- **Blockchain**: Stacks blockchain
- **Language**: Clarity smart contract language
- **Token**: STX (Stacks native token)

## Development & Deployment

The contract is designed for deployment on the Stacks mainnet with proper testing on testnet environments. Ensure proper administrative key management and parameter configuration before mainnet deployment.
