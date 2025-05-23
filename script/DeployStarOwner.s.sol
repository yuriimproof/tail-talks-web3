// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {StarOwner} from "../src/StarOwner.sol";

contract DeployStarOwner is Script {
    // Default deployment parameters for pet NFT platform
    string public constant NAME = "PetOwner NFT";
    string public constant SYMBOL = "PETS";
    uint256 public constant MINT_PRICE = 0.001 ether; // 0.001 ETH per mint
    uint256 public constant TOKEN_MINT_PRICE = 1000 * 10 ** 18; // 1000 tokens per mint
    address public constant PAYMENT_TOKEN = address(0); // No ERC20 token initially

    function run() external returns (StarOwner) {
        vm.startBroadcast();

        console.log("Deploying StarOwner contract...");
        console.log("Name:", NAME);
        console.log("Symbol:", SYMBOL);
        console.log("Mint Price (ETH):", MINT_PRICE);
        console.log("Token Mint Price:", TOKEN_MINT_PRICE);
        console.log("Payment Token:", PAYMENT_TOKEN);

        StarOwner starOwner = new StarOwner(NAME, SYMBOL, MINT_PRICE, TOKEN_MINT_PRICE, PAYMENT_TOKEN);

        console.log("StarOwner deployed at:", address(starOwner));
        console.log("Initial admin:", msg.sender);

        vm.stopBroadcast();
        return starOwner;
    }

    // Alternative deployment with custom parameters
    function runCustom(
        string memory _name,
        string memory _symbol,
        uint256 _mintPrice,
        uint256 _tokenMintPrice,
        address _paymentToken
    ) external returns (StarOwner) {
        vm.startBroadcast();

        console.log("Deploying custom StarOwner contract...");
        console.log("Name:", _name);
        console.log("Symbol:", _symbol);
        console.log("Mint Price (ETH):", _mintPrice);
        console.log("Token Mint Price:", _tokenMintPrice);
        console.log("Payment Token:", _paymentToken);

        StarOwner starOwner = new StarOwner(_name, _symbol, _mintPrice, _tokenMintPrice, _paymentToken);

        console.log("StarOwner deployed at:", address(starOwner));
        console.log("Initial admin:", msg.sender);

        vm.stopBroadcast();
        return starOwner;
    }
}
