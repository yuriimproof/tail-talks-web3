# 🐾 TailTalks Web3

> **A decentralized NFT platform for pet lovers to immortalize their furry friends on the blockchain**

TailTalks Web3 is a comprehensive smart contract platform that enables pet owners to mint unique NFTs of their beloved pets with custom IPFS-hosted images. The platform features both individual pet NFT collections and a factory system for creating curated pet-themed collections, all governed by multi-signature admin systems.

## 🌟 Features

### 🎨 StarOwner Contract - Individual Pet NFTs
- **Custom Pet Photos**: Mint NFTs with personalized IPFS-hosted pet images
- **Dual Payment Systems**: Accept both native tokens (BNB) and custom ERC20 tokens
- **Multi-Admin Governance**: 75% quorum-based governance for all admin operations
- **Proposal System**: Democratic decision-making for price changes, admin management, and fund withdrawals
- **Individual Token URIs**: Each NFT has its own unique IPFS metadata

### 🏭 StarKeeper Factory System - Curated Collections
- **Collection Factory**: Create themed pet collections (e.g., "Dogs of Berlin", "Rescue Cats")
- **Batch Operations**: Efficiently manage multiple collections from a single factory
- **Governance Integration**: Multi-admin approval system for collection creation and management
- **Flexible Configuration**: Customizable pricing, supply limits, and payment tokens per collection

## 📁 Project Structure

```
tail-talks-web3/
├── src/                          # Smart contracts source code
│   ├── StarOwner.sol            # Individual pet NFT contract
│   └── StarKeeper.sol           # Collection NFT contract  
├── script/                      # Foundry deployment scripts
├── test/                        # Test files
│   ├── unit/                    # Unit tests
│   ├── integration/             # Integration tests
│   ├── invariant/              # Property-based tests
│   └── mocks/                  # Mock contracts
└── foundry.toml                # Foundry configuration
```

## 🚀 Quick Start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation.html)
- [Git](https://git-scm.com/downloads)

### Installation

```bash
# Clone the repository
git clone https://github.com/your-username/tail-talks-web3.git
cd tail-talks-web3

# Install dependencies
forge install

# Build the project
forge build
```

### Testing

```bash
# Run all tests
forge test

# Run tests with verbose output
forge test -vvv

# Generate gas report
forge test --gas-report

# Generate coverage report
forge coverage
```

## 📦 Deployment

The project is configured for deployment to BSC mainnet.

### Environment Setup

Create a `.env` file with the following variables:


### Available Deployment Commands

```bash
# StarOwner Deployment
make deploy-star-owner-bsc-mainnet              # Deploy with default parameters
make deploy-star-owner-bsc-mainnet-custom       # Deploy with custom parameters

# StarKeeperFactory Deployment
make deploy-star-keeper-factory-bsc-mainnet          # Deploy with single admin
make deploy-star-keeper-factory-bsc-mainnet-multi-admin  # Deploy with multiple admins
```

# BSC Mainnet
make deploy-star-owner-bsc-mainnet         # Deploy StarOwner to mainnet
make deploy-star-keeper-factory-bsc-mainnet # Deploy StarKeeperFactory to mainnet
```

## 🎯 Usage Examples

### Minting Pet NFTs (StarOwner)

```solidity
// Mint with BNB
string memory ipfsUri = "ipfs://QmYourPetPhotoHash";
uint256 tokenId = starOwner.mint{value: mintPrice}(ipfsUri);

// Mint with ERC20 tokens (if enabled)
uint256 tokenId = starOwner.mintWithToken(ipfsUri);
```

### Creating Collections (StarKeeperFactory)

```solidity
// Admins create proposals for new collections
uint256 proposalId = factory.createCollectionProposal(
    "Rescue Dogs of NYC",     // name
    "RESCUE",                 // symbol
    1000,                     // maxSupply
    0.01 ether,              // mintPrice
    100 * 10**18,            // tokenMintPrice
    address(paymentToken),    // paymentToken
    "ipfs://base-uri/",       // baseTokenURI
    "ipfs://collection-image" // collectionImageURI
);

// Other admins vote on the proposal
factory.voteForProposal(proposalId);
```

### Governance Operations

```solidity
// Add new admin (requires 75% approval)
uint256 proposalId = starOwner.createAddAdminProposal(newAdminAddress);
starOwner.voteForProposal(proposalId);

// Update mint prices
uint256 proposalId = starOwner.createSetMintPriceProposal(0.002 ether);
starOwner.voteForProposal(proposalId);

// Withdraw funds
uint256 proposalId = starOwner.createWithdrawFundsProposal(treasuryAddress, amount);
starOwner.voteForProposal(proposalId);
```

## 🏛️ Contract Addresses

### BSC Mainnet
```
StarOwner: 0x... (To be deployed)
StarKeeperFactory: 0x... (To be deployed)
```

## 🧪 Testing Strategy

The project includes comprehensive testing across multiple layers:

- **Unit Tests**: Individual contract function testing
- **Integration Tests**: Cross-contract interaction testing  
- **Invariant Tests**: Property-based testing for system invariants
- **Mock Contracts**: Isolated testing with controlled dependencies

### Test Coverage

```bash
# Generate detailed coverage report
forge coverage --ir-minimum
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- **OpenZeppelin**: For secure, audited smart contract libraries
- **Foundry**: For the excellent development and testing framework
- **The Pet Community**: For inspiring this project 🐕🐱

---

**Made with ❤️ for pet lovers everywhere** 🐾
