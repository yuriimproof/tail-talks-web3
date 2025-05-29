// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {StarKeeper} from "../src/StarKeeper.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MintNFTScript is Script {
    // This is the NFT contract address
    address payable constant STARKEEPER = payable(0xA6D6e0D11cDe8883e31d3510a51816bb8827c23E);
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    uint256 constant MINT_PRICE = 100000000000000; // 0.0001 BNB
    uint256 constant TOKEN_MINT_PRICE = 1000000; // 1 USDT

    function run() external {
        // Make sure your PRIVATE_KEY in .env is for a regular wallet, not the contract address
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sender = vm.addr(deployerPrivateKey);
        require(sender != STARKEEPER, "Using contract address as sender");

        vm.startBroadcast(deployerPrivateKey);

        StarKeeper nft = StarKeeper(STARKEEPER);

        // Check contract state before minting
        console.log("Minting from address:", sender);
        console.log("Contract balance:", address(STARKEEPER).balance);
        console.log("Sender balance:", sender.balance);
        console.log("Mint price:", MINT_PRICE);

        try nft.maxSupply() returns (uint256 maxSupply) {
            console.log("Max supply:", maxSupply);
        } catch {
            console.log("Could not get max supply");
        }

        try nft.totalSupply() returns (uint256 totalSupply) {
            console.log("Total supply:", totalSupply);
        } catch {
            console.log("Could not get total supply");
        }

        // Mint with BNB
        nft.mint{value: MINT_PRICE}();

        // Or mint with USDT (uncomment these lines to use USDT instead)
        // IERC20(USDT).approve(STARKEEPER, TOKEN_MINT_PRICE);
        // nft.mintWithToken();

        vm.stopBroadcast();
    }
}
