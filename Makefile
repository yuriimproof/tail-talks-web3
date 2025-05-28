-include .env

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Default to local anvil network
NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

# BSC Mainnet deployments
deploy-star-owner-bsc-mainnet:
	@forge script script/DeployStarOwner.s.sol:DeployStarOwner \
		--sig "runCustom(string,string,uint256,uint256,address)" \
		"$(DEFAULT_NAME)" "$(DEFAULT_SYMBOL)" $(DEFAULT_MINT_PRICE) $(DEFAULT_TOKEN_MINT_PRICE) "$(DEFAULT_PAYMENT_TOKEN)" \
		--rpc-url $(BSC_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		-vvvv

deploy-star-owner-bsc-mainnet-custom:
	@if [ -z "$(NAME)" ] || [ -z "$(SYMBOL)" ] || [ -z "$(MINT_PRICE)" ] || [ -z "$(TOKEN_MINT_PRICE)" ] || [ -z "$(PAYMENT_TOKEN)" ]; then \
		echo "Error: Missing parameters. Use format:"; \
		echo "make deploy-star-owner-bsc-mainnet-custom NAME=\"My Pet NFT\" SYMBOL=\"MPNFT\" MINT_PRICE=500000000000000 TOKEN_MINT_PRICE=1000000000000000000000 PAYMENT_TOKEN=0x0000000000000000000000000000000000000000"; \
		exit 1; \
	fi
	@forge script script/DeployStarOwner.s.sol:DeployStarOwner \
		--sig "runCustom(string,string,uint256,uint256,address)" \
		"$(NAME)" "$(SYMBOL)" $(MINT_PRICE) $(TOKEN_MINT_PRICE) "$(PAYMENT_TOKEN)" \
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
	@if [ -z "$(ADMIN_ADDRESSES)" ]; then \
		echo "Using default admin addresses from .env"; \
		ADDRESSES=$(DEFAULT_ADMIN_ADDRESSES); \
	else \
		ADDRESSES=$(ADMIN_ADDRESSES); \
	fi; \
	forge script script/DeployStarKeeperFactory.s.sol:DeployStarKeeperFactory \
		--sig "runWithMultipleAdmins(address[])" $$ADDRESSES \
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

