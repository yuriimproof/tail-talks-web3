-include .env

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Default to local anvil network
NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

# Deployment targets with network support
deploy-star-owner:
	@forge script script/DeployStarOwner.s.sol:DeployStarOwner $(NETWORK_ARGS)

deploy-star-keeper-factory:
	@forge script script/DeployStarKeeperFactory.s.sol:DeployStarKeeperFactory $(NETWORK_ARGS)

# BSC Mainnet deployments
deploy-star-owner-bsc-mainnet:
	@forge script script/DeployStarOwner.s.sol:DeployStarOwner \
		--rpc-url $(BSC_MAINNET_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--etherscan-api-key $(BSC_API_KEY) \
		-vvvv

deploy-star-keeper-factory-bsc-mainnet:
	@forge script script/DeployStarKeeperFactory.s.sol:DeployStarKeeperFactory \
		--rpc-url $(BSC_MAINNET_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--etherscan-api-key $(BSC_API_KEY) \
		-vvvv

# Help target
help:
	@echo "Available targets:"
	@echo "  deploy-star-owner                       - Deploy StarOwner to local anvil"
	@echo "  deploy-star-keeper-factory              - Deploy StarKeeperFactory to local anvil"
	@echo "  deploy-star-owner-bsc-testnet           - Deploy StarOwner to BSC testnet"
	@echo "  deploy-star-keeper-factory-bsc-testnet  - Deploy StarKeeperFactory to BSC testnet"
	@echo "  deploy-star-owner-bsc-mainnet           - Deploy StarOwner to BSC mainnet"
	@echo "  deploy-star-keeper-factory-bsc-mainnet  - Deploy StarKeeperFactory to BSC mainnet"

.PHONY: help deploy-star-owner deploy-star-keeper-factory deploy-star-owner-bsc-testnet deploy-star-keeper-factory-bsc-testnet deploy-star-owner-bsc-mainnet deploy-star-keeper-factory-bsc-mainnet

