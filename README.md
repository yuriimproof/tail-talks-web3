# 🐾 TailTalks Web3

> **A decentralized NFT platform for pet lovers to immortalize their furry friends on the blockchain**

TailTalks Web3 is a comprehensive smart contract platform that enables pet owners to mint unique NFTs of their beloved pets with custom IPFS-hosted images. The platform features both individual pet NFT collections and a factory system for creating curated pet-themed collections, all governed by multi-signature admin systems.

## 🌟 Features

### 🎨 StarOwner Contract - Individual Pet NFTs
- **Custom Pet Photos**: Mint NFTs with personalized IPFS-hosted pet images
- **Dual Payment Systems**: Accept both ETH and custom ERC20 tokens
- **Multi-Admin Governance**: 75% quorum-based governance for all admin operations
- **Proposal System**: Democratic decision-making for price changes, admin management, and fund withdrawals
- **Individual Token URIs**: Each NFT has its own unique IPFS metadata

### 🏭 StarKeeper Factory System - Curated Collections
- **Collection Factory**: Create themed pet collections (e.g., "Dogs of Berlin", "Rescue Cats")
- **Batch Operations**: Efficiently manage multiple collections from a single factory
- **Governance Integration**: Multi-admin approval system for collection creation and management
- **Flexible Configuration**: Customizable pricing, supply limits, and payment tokens per collection

### 🔐 Security & Governance
- **75% Quorum Governance**: All administrative actions require 75% admin approval
- **Time-Limited Proposals**: 7-day proposal windows for thoughtful decision-making
- **Access Control**: Role-based permissions using OpenZeppelin's AccessControl
- **Comprehensive Testing**: Full test coverage for all critical functions

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   StarOwner     │    │ StarKeeperFactory│    │   StarKeeper    │
│  (Individual)   │    │   (Factory)      │    │  (Collection)   │
├─────────────────┤    ├──────────────────┤    ├─────────────────┤
│ • Custom NFTs   │    │ • Create Collections│ │ • Fixed supply  │
│ • IPFS images   │    │ • Multi-admin    │    │ • Collection NFTs│
│ • Multi-payment │    │ • 75% governance │    │ • Factory-managed│
│ • Governance    │    │ • Proposal system│    │ • Themed content │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 📁 Project Structure

```
tail-talks-web3/
├── src/                          # Smart contracts source code
│   ├── StarOwner.sol            # Individual pet NFT contract
│   ├── StarKeeper.sol           # Collection NFT contract  
│   └── StarKeeperFactory.sol    # Factory for creating collections
├── script/                      # Foundry deployment scripts (.s.sol)
│   ├── DeployStarOwner.s.sol    # StarOwner deployment script
│   └── DeployStarKeeperFactory.s.sol # Factory deployment script
├── test/                        # Test files
│   ├── unit/                    # Unit tests for individual contracts
│   ├── integration/             # Integration tests
│   ├── fork/                    # Fork tests (BSC mainnet)
│   ├── invariant/               # Property-based invariant tests
│   └── mocks/                   # Mock contracts for testing
├── foundry.toml                 # Foundry configuration
├── Makefile                     # Deployment automation
└── README.md                    # Project documentation
```

### Folder Conventions

- **`src/`**: Contains all Solidity smart contracts
- **`script/`**: Foundry deployment scripts (`.s.sol` files) - follows Foundry convention
- **`test/`**: All test files organized by type (unit, integration, fork, etc.)

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

# Run specific test files
forge test --match-path test/unit/StarOwnerTest.t.sol
forge test --match-path test/unit/StarKeeperFactoryTest.t.sol

# Generate gas report
forge test --gas-report

# Generate coverage report
forge coverage
```

### Fork Testing

The project includes fork testing for BSC (Binance Smart Chain) to ensure contracts work correctly in the real BSC environment:

```bash
# Run all fork tests with BSC mainnet fork
forge test --match-path "test/fork/*" --fork-url https://bsc-dataseed.binance.org/ -vv

# Run specific fork test files
forge test --match-path "test/fork/StarOwnerForkTest.t.sol" --fork-url https://bsc-dataseed.binance.org/ -vv
forge test --match-path "test/fork/StarKeeperFactoryForkTest.t.sol" --fork-url https://bsc-dataseed.binance.org/ -vv

# Run BSC-specific tests only
forge test --match-test "*BSCFork*" --fork-url https://bsc-dataseed.binance.org/ -vv

# Run with gas reporting
forge test --match-path "test/fork/*" --fork-url https://bsc-dataseed.binance.org/ --gas-report

# Run specific test patterns
forge test --match-test "*Governance*" --fork-url https://bsc-dataseed.binance.org/ -vv    # Governance tests
forge test --match-test "*Workflow*" --fork-url https://bsc-dataseed.binance.org/ -vv      # Workflow tests
forge test --match-test "*Gas*" --fork-url https://bsc-dataseed.binance.org/ --gas-report  # Gas analysis tests

# Alternative BSC RPC URLs you can use:
# --fork-url https://bsc-dataseed1.defibit.io/
# --fork-url https://bsc-dataseed1.ninicoin.io/
# --fork-url https://bsc.nodereal.io
```

> **Note**: The fork tests include two types:
> - `testBSCFork*` functions: Create their own forks (work with environment variables)
> - `testFork*` and `testDeployOnFork` functions: Work with `--fork-url` flag (recommended)

#### Fork Test Features

- **Real BSC Environment**: Tests run against actual BSC mainnet state
- **BNB Pricing**: Tests use BSC-appropriate pricing (0.01 BNB for StarOwner, 0.05 BNB for Factory)
- **BUSD Integration**: Tests include BUSD token integration scenarios
- **Gas Analysis**: Measure actual gas costs on BSC network
- **Governance Testing**: Multi-admin governance scenarios on BSC
- **High Volume Testing**: Stress testing with multiple NFT mints

#### Environment Configuration

Create a `.env` file with your BSC RPC URL:

```bash
# BSC RPC URL for fork testing
BSC_RPC_URL=https://bsc-dataseed.binance.org/

# Alternative BSC RPC URLs:
# BSC_RPC_URL=https://bsc-dataseed1.defibit.io/
# BSC_RPC_URL=https://bsc-dataseed1.ninicoin.io/
# BSC_RPC_URL=https://bsc.nodereal.io
```

## 📦 Deployment

The project includes a comprehensive Makefile with deployment targets for different networks.

### Prerequisites for Deployment

Ensure your `.env` file is configured with the necessary variables:

```bash
# Private key for deployment
PRIVATE_KEY=your-private-key-here

# BSC Network URLs
BSC_TEST_RPC_URL=https://data-seed-prebsc-1-s1.binance.org:8545
BSC_MAINNET_RPC_URL=https://bsc-dataseed1.binance.org

# BSC API Key for contract verification
BSC_API_KEY=your-bscscan-api-key
```

### Local Development (Anvil)

```bash
# Start local Anvil node (in separate terminal)
anvil

# Deploy StarOwner to local network
make deploy-star-owner

# Deploy StarKeeperFactory to local network
make deploy-star-keeper-factory
```

### BSC Testnet Deployment

```bash
# Deploy StarOwner to BSC testnet (with verification)
make deploy-star-owner-bsc-testnet

# Deploy StarKeeperFactory to BSC testnet (with verification)
make deploy-star-keeper-factory-bsc-testnet
```

### BSC Mainnet Deployment

```bash
# Deploy StarOwner to BSC mainnet (with verification)
make deploy-star-owner-bsc-mainnet

# Deploy StarKeeperFactory to BSC mainnet (with verification)
make deploy-star-keeper-factory-bsc-mainnet
```

### Available Deployment Commands

View all available deployment targets:

```bash
make help
```

This will show:
```
Available targets:
  deploy-star-owner                       - Deploy StarOwner to local anvil
  deploy-star-keeper-factory              - Deploy StarKeeperFactory to local anvil
  deploy-star-owner-bsc-testnet           - Deploy StarOwner to BSC testnet
  deploy-star-keeper-factory-bsc-testnet  - Deploy StarKeeperFactory to BSC testnet
  deploy-star-owner-bsc-mainnet           - Deploy StarOwner to BSC mainnet
  deploy-star-keeper-factory-bsc-mainnet  - Deploy StarKeeperFactory to BSC mainnet
```

### Deployment Features

- **Automatic Verification**: Testnet and mainnet deployments include contract verification on BSCScan
- **Environment Configuration**: Uses `.env` file for secure credential management
- **Network-Specific**: Separate commands for local development, testnet, and mainnet
- **Verbose Logging**: Detailed deployment logs with `-vvvv` flag for debugging

## 🎯 Usage Examples

### Minting Pet NFTs (StarOwner)

```solidity
// Mint with ETH
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

## 🔧 Configuration

### Environment Setup

Create a `.env` file based on `.env.example`:

```bash
# Network configuration
ANVIL_RPC_URL=http://localhost:8545
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/your-api-key

# Account configuration  
PRIVATE_KEY=your-private-key-here
ETHERSCAN_API_KEY=your-etherscan-api-key
```

### Default Deployment Parameters

#### StarOwner
- **Name**: "PetOwner NFT"
- **Symbol**: "PETS"
- **Mint Price**: 0.001 ETH
- **Token Mint Price**: 1000 tokens
- **Payment Token**: None (ETH only initially)

#### StarKeeperFactory
- **Initial Admin**: Deployer address
- **Quorum**: 75% of admins
- **Proposal Duration**: 7 days

## 🏛️ Contract Addresses

### Mainnet
```
StarOwner: 0x... (To be deployed)
StarKeeperFactory: 0x... (To be deployed)
```

### Sepolia Testnet
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
forge coverage --report lcov
genhtml lcov.info --output-directory coverage 
```

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add/update tests as needed
5. Run the full test suite (`forge test`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to your branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

### Development Guidelines

- Follow the existing code style and patterns
- Add comprehensive tests for new features
- Update documentation for any API changes
- Ensure all tests pass before submitting PRs
- Use conventional commit messages

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **OpenZeppelin**: For secure, audited smart contract libraries
- **Foundry**: For the excellent development and testing framework
- **The Pet Community**: For inspiring this project 🐕🐱

## 📞 Support

- **Documentation**: [GitHub Wiki](https://github.com/yuriimproof/tail-talks-web3/wiki)
- **Issues**: [GitHub Issues](https://github.com/yuriimproof/tail-talks-web3/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yuriimproof/tail-talks-web3/discussions)

---

**Made with ❤️ for pet lovers everywhere** 🐾
