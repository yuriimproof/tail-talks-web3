// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {StarOwner} from "../../src/StarOwner.sol";
import {MockERC20} from "../mocks/ERC20Mock.sol";

/**
 * @title StarOwnerHandler
 * @dev Handler contract for guided fuzzing of StarOwner invariant tests
 */
contract StarOwnerHandler is Test {
    StarOwner public starOwner;
    MockERC20 public paymentToken;

    // Test actors
    address public admin1;
    address public admin2;
    address public admin3;
    address public user1;
    address public user2;

    // Arrays to track actors
    address[] public admins;
    address[] public users;

    // Ghost variables for tracking
    uint256 public ghost_totalMinted;
    uint256 public ghost_totalProposalsCreated;
    uint256 public ghost_totalEthReceived;
    uint256 public ghost_totalTokensReceived;

    // Tracking arrays
    uint256[] public activeProposals;

    constructor(
        StarOwner _starOwner,
        MockERC20 _paymentToken,
        address _admin1,
        address _admin2,
        address _admin3,
        address _user1,
        address _user2
    ) {
        starOwner = _starOwner;
        paymentToken = _paymentToken;
        admin1 = _admin1;
        admin2 = _admin2;
        admin3 = _admin3;
        user1 = _user1;
        user2 = _user2;

        // Initialize arrays
        admins.push(_admin1);
        users.push(_user1);
        users.push(_user2);
    }

    // ============ Handler Functions ============

    /**
     * @dev Mint NFT with ETH payment
     */
    function mintWithEth(uint256 userSeed) external {
        address user = users[bound(userSeed, 0, users.length - 1)];
        uint256 mintPrice = starOwner.mintPrice();

        vm.deal(user, mintPrice + 1 ether);
        vm.startPrank(user);

        try starOwner.mint{value: mintPrice}("ipfs://QmTestHash123") {
            ghost_totalMinted++;
            ghost_totalEthReceived += mintPrice;
        } catch {
            // Mint failed, that's okay
        }

        vm.stopPrank();
    }

    /**
     * @dev Mint NFT with ERC20 tokens
     */
    function mintWithToken(uint256 userSeed) external {
        address user = users[bound(userSeed, 0, users.length - 1)];
        uint256 tokenPrice = starOwner.tokenMintPrice();

        if (address(starOwner.paymentToken()) == address(0) || tokenPrice == 0) {
            return; // ERC20 payments not enabled
        }

        paymentToken.mint(user, tokenPrice);
        vm.startPrank(user);
        paymentToken.approve(address(starOwner), tokenPrice);

        try starOwner.mintWithToken("ipfs://QmTestHash456") {
            ghost_totalMinted++;
            ghost_totalTokensReceived += tokenPrice;
        } catch {
            // Mint failed, that's okay
        }

        vm.stopPrank();
    }

    /**
     * @dev Create add admin proposal
     */
    function createAddAdminProposal(uint256 adminSeed, uint256 newAdminSeed) external {
        if (admins.length == 0) return;

        address admin = admins[bound(adminSeed, 0, admins.length - 1)];
        address newAdmin = users[bound(newAdminSeed, 0, users.length - 1)];

        vm.startPrank(admin);

        try starOwner.createAddAdminProposal(newAdmin) returns (uint256 proposalId) {
            ghost_totalProposalsCreated++;
            activeProposals.push(proposalId);
        } catch {
            // Proposal creation failed, that's okay
        }

        vm.stopPrank();
    }

    /**
     * @dev Create remove admin proposal
     */
    function createRemoveAdminProposal(uint256 adminSeed, uint256 targetAdminSeed) external {
        if (admins.length <= 1) return; // Can't remove last admin

        address admin = admins[bound(adminSeed, 0, admins.length - 1)];
        address targetAdmin = admins[bound(targetAdminSeed, 0, admins.length - 1)];

        vm.startPrank(admin);

        try starOwner.createRemoveAdminProposal(targetAdmin) returns (uint256 proposalId) {
            ghost_totalProposalsCreated++;
            activeProposals.push(proposalId);
        } catch {
            // Proposal creation failed, that's okay
        }

        vm.stopPrank();
    }

    /**
     * @dev Create withdraw funds proposal
     */
    function createWithdrawFundsProposal(uint256 adminSeed, uint256 amount) external {
        if (admins.length == 0) return;

        address admin = admins[bound(adminSeed, 0, admins.length - 1)];
        amount = bound(amount, 0, address(starOwner).balance + 1 ether);

        vm.startPrank(admin);

        try starOwner.createWithdrawFundsProposal(admin, amount) returns (uint256 proposalId) {
            ghost_totalProposalsCreated++;
            activeProposals.push(proposalId);
        } catch {
            // Proposal creation failed, that's okay
        }

        vm.stopPrank();
    }

    /**
     * @dev Create set mint price proposal
     */
    function createSetMintPriceProposal(uint256 adminSeed, uint256 newPrice) external {
        if (admins.length == 0) return;

        address admin = admins[bound(adminSeed, 0, admins.length - 1)];
        newPrice = bound(newPrice, 0, 1 ether);

        vm.startPrank(admin);

        try starOwner.createSetMintPriceProposal(newPrice) returns (uint256 proposalId) {
            ghost_totalProposalsCreated++;
            activeProposals.push(proposalId);
        } catch {
            // Proposal creation failed, that's okay
        }

        vm.stopPrank();
    }

    /**
     * @dev Vote on active proposals
     */
    function voteOnProposal(uint256 adminSeed, uint256 proposalSeed) external {
        if (admins.length == 0 || activeProposals.length == 0) return;

        address admin = admins[bound(adminSeed, 0, admins.length - 1)];
        uint256 proposalId = activeProposals[bound(proposalSeed, 0, activeProposals.length - 1)];

        vm.startPrank(admin);

        try starOwner.voteForProposal(proposalId) {
            // Vote successful
            _updateAdminsList();
        } catch {
            // Vote failed, that's okay
        }

        vm.stopPrank();
    }

    /**
     * @dev Update token URI (admin only)
     */
    function updateTokenURI(uint256 adminSeed, uint256 tokenId) external {
        if (admins.length == 0) return;

        address admin = admins[bound(adminSeed, 0, admins.length - 1)];
        uint256 totalSupply = starOwner.totalSupply();

        if (totalSupply == 0) return;

        tokenId = bound(tokenId, 1, totalSupply);

        vm.startPrank(admin);

        try starOwner.updateTokenURI(tokenId, "ipfs://QmUpdatedHash789") {
            // URI update successful
        } catch {
            // Update failed, that's okay
        }

        vm.stopPrank();
    }

    // ============ Helper Functions ============

    /**
     * @dev Update the admins list based on current contract state
     */
    function _updateAdminsList() internal {
        address[] memory currentAdmins = starOwner.getAdmins();

        // Clear and rebuild admins array
        delete admins;
        for (uint256 i = 0; i < currentAdmins.length; i++) {
            admins.push(currentAdmins[i]);
        }
    }

    /**
     * @dev Clean up expired proposals from tracking
     */
    function cleanupProposals() external {
        uint256[] memory newActiveProposals = new uint256[](activeProposals.length);
        uint256 count = 0;

        for (uint256 i = 0; i < activeProposals.length; i++) {
            try starOwner.getProposalDetails(activeProposals[i]) returns (
                address,
                uint256,
                uint256,
                uint256 expirationTime,
                bool executed,
                StarOwner.ProposalType,
                address,
                uint256
            ) {
                if (!executed && block.timestamp <= expirationTime) {
                    newActiveProposals[count] = activeProposals[i];
                    count++;
                }
            } catch {
                // Proposal doesn't exist or is invalid, remove it
            }
        }

        // Update active proposals array
        delete activeProposals;
        for (uint256 i = 0; i < count; i++) {
            activeProposals.push(newActiveProposals[i]);
        }
    }

    // ============ Getter Functions ============

    function getAdminsCount() external view returns (uint256) {
        return admins.length;
    }

    function getUsersCount() external view returns (uint256) {
        return users.length;
    }

    function getActiveProposalsCount() external view returns (uint256) {
        return activeProposals.length;
    }
}
