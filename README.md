# Around - Decentralized Self-Yielding Prediction Market

## Project Overview

Around is a blockchain-based decentralized prediction market platform that allows users to make Yes/No predictions on various events (cryptocurrency, sports, games, politics, economy, technology, weather, etc.). The platform employs an Automated Market Maker (AMM) mechanism combined with a virtual liquidity model to provide users with a smooth trading experience. Additionally, the platform integrates with the Aave protocol, enabling pools to automatically generate yields, achieving the "self-yielding" feature.

## Core Features

### 1. Prediction Market Functionality
- **Market Creation**: Users can create various types of prediction markets
- **Bidirectional Trading**: Supports Yes/No predictions and trading in both directions
- **Real-time Pricing**: Dynamic price discovery mechanism based on AMM model
- **Liquidity Provision**: Users can add liquidity and earn trading fees

### 2. Self-Yielding Mechanism
- **Aave Integration**: Pools can optionally deposit funds into the Aave protocol
- **Auto-compounding**: Yields from Aave are automatically reinvested into the pool
- **Flexible Configuration**: Each market can independently configure whether to enable Aave yields

### 3. Decentralized Oracle
- **Optimistic Oracle**: Uses EchoOptimisticOracle for result determination
- **Multiple Data Sources**: Supports multiple data providers submitting results
- **Dispute Mechanism**: Includes challenge and dispute voting mechanisms to ensure result accuracy
- **Incentive Mechanism**: Data providers who submit correct results receive rewards

### 4. Reward Mechanism
- **Lucky Pool (LuckyPool)**: Users who reach the trading volume threshold can participate in a lottery
- **Creator Rewards**: Market creators receive a portion of trading fees
- **NFT Discounts**: Users holding ELF NFTs enjoy 50% fee discounts

### 5. Risk Management
- **Multi-signature Management**: Critical operations require multi-signature confirmation
- **Invalid Market Mechanism**: Supports marking invalid markets as InvalidMarket

## System Architecture

### Core Contracts

#### 1. AroundMarket
**Location**: `contracts/core/AroundMarket.sol`

Core market contract responsible for:
- Market creation and management
- Buy/sell trade execution
- Liquidity management (add)
- Profit distribution and redemption
- Interaction with AroundPool

**Main Functions**:
- `createMarket()`: Create a new prediction market
- `buy()`: Purchase Yes/No shares
- `sell()`: Sell Yes/No shares
- `addLiquidity()`: Add liquidity
- `redeemWinnings()`: Redeem winning profits and liquidity provides collateral and liquidity fees
- `touchAllot()`: Trigger fund allocation

#### 2. AroundPool
**Location**: `contracts/core/AroundPool.sol`

Pool contract responsible for:
- Collateral management
- Aave protocol interaction
- Fund deposit/withdrawal operations

**Main Functions**:
- `deposite()`: Deposit funds (optionally to Aave)
- `touch()`: Withdraw funds
- `allot()`: Fund allocation (called during market settlement)

#### 3. AroundPoolFactory
**Location**: `contracts/core/AroundPoolFactory.sol`

Factory contract responsible for:
- Creating new market pools and lucky pools
- Managing supported tokens
- Configuring fee structure
- Managing Aave integration information

**Main Functions**:
- `createPool()`: Create a new market pool
- `setTokenInfo()`: Set token information
- `changeBaseFee()`: Modify base fees
- `setAaveInfo()`: Configure Aave information

#### 4. EchoOptimisticOracle
**Location**: `contracts/oracle/EchoOptimisticOracle.sol`

Optimistic oracle contract responsible for:
- Receiving result submissions from data providers
- Processing challenges and disputes
- Generating random numbers (for lottery)
- Distributing oracle rewards

**Main Functions**:
- `submitData()`: Data providers submit results
- `challenge()`: Challenge submitted results
- `disputeVote()`: Dispute voting
- `withdrawEarn()`: Withdraw rewards

#### 5. LuckyPool
**Location**: `contracts/core/LuckyPool.sol`

Lottery pool contract responsible for:
- Collecting lucky fees
- Randomly selecting winners
- Distributing winning rewards

**Main Functions**:
- `bump()`: Trigger lottery and select winner

#### 7. AroundUIHelper
**Location**: `contracts/core/AroundUIHelper.sol`

Frontend helper contract providing batch query functionality to optimize frontend data retrieval.

## Pricing Mechanism

### Virtual Liquidity AMM Model

The platform uses a virtual liquidity-based AMM pricing model with the formula:

```
P_yes = (yesAmount + virtualLiquidity) / (yesAmount + noAmount + 2 * virtualLiquidity)
P_no = 1 - P_yes
```

Where:
- `yesAmount`: Total Yes shares
- `noAmount`: Total No shares
- `virtualLiquidity`: Virtual liquidity (initial value configurable)

Virtual liquidity provides initial price discovery capability, ensuring markets have a reasonable initial price (0.5) even without trades.

### Trading Fee Structure

Total fee rate: Default 0.6% (600/100000)

Fee distribution:
- **Official Fee**: 2% (200/100000) - To platform
- **Liquidity Fee**: 1.5% (150/100000) - To liquidity providers
- **Oracle Fee**: 1% (100/100000) - To oracle data providers
- **Lucky Fee**: 0.075% (75/100000) - To lottery pool
- **Creator Fee**: 0.075% (75/100000) - To market creator

Users holding ELF NFTs enjoy a 50% fee discount.

## Workflows

### 1. Market Creation Flow

```
User → createPool() → AroundPoolFactory
  ↓
Create AroundPool and LuckyPool
  ↓
Inject question to oracle
  ↓
User → createMarket() → AroundMarket
  ↓
Pay guarantee amount (calculated based on virtual liquidity)
  ↓
Market activated
```

### 2. Trading Flow

**Buy Flow**:
```
User → buy(Yes/No, amount, marketId)
  ↓
Calculate fees and net input
  ↓
Transfer tokens to AroundPool
  ↓
Calculate output shares (based on AMM formula)
  ↓
Update user position and liquidity info
  ↓
Record trade and update raffle ticket
```

**Sell Flow**:
```
User → sell(Yes/No, amount, marketId)
  ↓
Verify user balance
  ↓
Calculate output amount and fees
  ↓
Withdraw funds from AroundPool
  ↓
Update user position and liquidity info
  ↓
Transfer tokens to user
```

### 3. Market Settlement Flow

```
Market end time reached
  ↓
Data providers submit results → EchoOptimisticOracle
  ↓
Result determined (Yes/No) after reaching threshold
  ↓
Challengeable during cooling period (2 hours)
  ↓
touchAllot() → Trigger AroundPool.allot() and LuckyPool.bump()
  ↓
Update final amount
  ↓
User → redeemWinnings() → Withdraw profits
```

### 4. Aave Yield Flow

```
Market enables Aave (ifOpenAave = true)
  ↓
Funds deposited → AroundPool.deposite()
  ↓
AroundPool → Aave Pool.deposit()
  ↓
Receive aToken (yield-bearing token)
  ↓
During market settlement → AroundPool.allot()
  ↓
Withdraw funds from Aave
  ↓
Calculate yields and update pool balance
```

## Technical Details

### Contract Version
- Solidity: ^0.8.26
- OpenZeppelin: Latest version

### Dependencies
- OpenZeppelin Contracts (ERC20, Ownable, ReentrancyGuard, etc.)
- Aave Protocol V3 Interfaces

### Key Constants

```solidity
RATE = 100_000                    // Fee denominator
Min_Lucky_Volume = 1000            // Minimum lottery trading volume
DefaultVirtualLiquidity = 100_000  // Default virtual liquidity
MinimumProfit = 10000             // Minimum profit
```

### Security Features

1. **SafeERC20**: All ERC20 operations use SafeERC20 library
2. **Access Control**: Critical functions use modifiers like onlyCaller, onlyMultiSig
3. **Initialization Protection**: Uses isInitialize flag to prevent re-initialization
4. **Zero Amount Check**: Critical operations check for zero amount inputs

## Usage Guide

### Creating a Market

1. Ensure token is registered in factory contract
2. Call `AroundPoolFactory.createPool()` to create pool
3. Call `AroundMarket.createMarket()` to activate market
4. Pay corresponding guarantee amount
5、Or you can directly use AroundRouter `AroundRouter.createMarket()` to make the payment and then proceed with the creation.

### Participating in Trading

1. Query current price: `AroundUIHelper.getYesPrice()` / `getNoPrice()`
2. Calculate slippage: `AroundUIHelper.getBuySlippage()`
3. Execute trade: `AroundMarket.buy()` or `sell()`

### Providing Liquidity

1. Call `AroundMarket.addLiquidity()`
2. Receive LP shares
3. Earn trading fee share

### Redeeming Profits

1. Wait for market settlement
2. Confirm result is determined
3. Call `AroundMarket.redeemWinnings()`
4. Receive profits corresponding to winning shares and retrieve the funds that were added for liquidity purposes

## Market Types

The following market types (MarketType) are supported:
- Other
- Crypto (Cryptocurrency)
- Sport
- Game
- Politics
- Economy
- Tech
- Weather

## Fee Structure

### Market Creation Fee
Guarantee amount calculated based on expected virtual liquidity, formula:
```
guaranteeAmount = 10 * (expectVirtualAmount / currentVirtualAmount + 1) * 10^decimals
```

### Trading Fees
- Buy: Pay 0.6% of total amount as fee
- Sell: Fee calculated based on sold shares

### Liquidity Fees
- Add liquidity: No fee

## Risk Warnings

1. **Smart Contract Risk**: Code may contain vulnerabilities, use with caution
2. **Oracle Risk**: Results depend on oracle data providers, errors may occur
3. **Liquidity Risk**: Insufficient market liquidity may cause large slippage
4. **Aave Risk**: Using Aave protocol involves smart contract and liquidation risks
5. **Market Risk**: Prediction markets inherently have price volatility risks

## Development Information

### Project Structure

```
contracts/
├── core/              # Core contracts
│   ├── AroundMarket.sol
│   ├── AroundPool.sol
│   ├── AroundPoolFactory.sol
│   ├── AroundUIHelper.sol
│   ├── AroundRouter.sol
│   ├── LuckyPool.sol
│   └── InsurancePool.sol
├── oracle/            # Oracle contracts
│   └── EchoOptimisticOracle.sol
├── interfaces/        # Interface definitions
├── libraries/         # Library contracts
│   ├── AroundMath.sol
│   └── AroundLib.sol
├── nft/              # NFT related
```

## License

GPL-3.0

## Warning
It is hereby stated that any third party not authorized by the author of this project, who uses this code for commercial purposes and generates corresponding profits, is required to pay at least 20% of the profits to the author of this project, namely **VineFiLabs**.

## Contact

This is the public repository of VineFi LABS.

---

**Disclaimer**: This document is for reference only and does not constitute any investment advice. Please fully understand the relevant risks before using this protocol.
