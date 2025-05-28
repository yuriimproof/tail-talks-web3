-include .env

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Default to local anvil network
NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

# BSC Mainnet deployments
deploy-star-owner-bsc-mainnet:
	@forge script script/DeployStarOwner.s.sol:DeployStarOwner \
		--sig "runCustom(string,string,uint256,uint256,address)" \
		$(NAME) $(SYMBOL) $(MINT_PRICE) $(TOKEN_MINT_PRICE) $(PAYMENT_TOKEN) \
		--rpc-url $(BSC_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		-vvvv

deploy-star-keeper-factory-bsc-mainnet:
	@forge script script/DeployStarKeeperFactory.s.sol:DeployStarKeeperFactory \
		--rpc-url $(BSC_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		-vvvv

deploy-star-keeper-factory-bsc-mainnet-multi-admin:
	@forge script script/DeployStarKeeperFactory.s.sol:DeployStarKeeperFactory \
		--sig "runWithMultipleAdmins(address[])" $(ADMIN_ADDRESSES) \
		--rpc-url $(BSC_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
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

.PHONY: help deploy-star-owner-bsc-mainnet deploy-star-owner-bsc-mainnet-custom deploy-star-keeper-factory-bsc-mainnet deploy-star-keeper-factory-bsc-mainnet-multi-admin

