// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {StarOwner} from "../../src/StarOwner.sol";
import {MockERC20} from "../mocks/ERC20Mock.sol";

contract StarOwnerTest is Test {
    StarOwner public starOwner;
    MockERC20 public mockToken;

    address public owner = makeAddr("owner");
    address public admin1 = makeAddr("admin1");
    address public admin2 = makeAddr("admin2");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    uint256 public constant MINT_PRICE = 0.01 ether;
    uint256 public constant TOKEN_MINT_PRICE = 1000 * 10 ** 18;
    string public constant IPFS_URI_1 = "ipfs://QmHash1";
    string public constant IPFS_URI_2 = "ipfs://QmHash2";

    function setUp() public {
        mockToken = new MockERC20();

        vm.prank(owner);
        starOwner = new StarOwner("Pet NFT", "PET", MINT_PRICE, TOKEN_MINT_PRICE, address(mockToken));

        // Give users some ETH and tokens
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        mockToken.mint(user1, 10000 * 10 ** 18);
        mockToken.mint(user2, 10000 * 10 ** 18);
    }

    // ============ Constructor Tests ============

    function testConstructor() public view {
        assertEq(starOwner.name(), "Pet NFT");
        assertEq(starOwner.symbol(), "PET");
        assertEq(starOwner.mintPrice(), MINT_PRICE);
        assertEq(starOwner.tokenMintPrice(), TOKEN_MINT_PRICE);
        assertEq(starOwner.paymentToken(), address(mockToken));
        assertEq(starOwner.quorumThreshold(), 1);

        // Check owner has admin role
        bytes32 adminRole = keccak256("ADMIN_ROLE");
        assertTrue(starOwner.hasRole(adminRole, owner));

        address[] memory admins = starOwner.getAdmins();
        assertEq(admins.length, 1);
        assertEq(admins[0], owner);
    }

    // ============ Minting Tests ============

    function testMintWithETH() public {
        vm.prank(user1);
        uint256 tokenId = starOwner.mint{value: MINT_PRICE}(IPFS_URI_1);

        assertEq(tokenId, 1);
        assertEq(starOwner.ownerOf(1), user1);
        assertEq(starOwner.totalSupply(), 1);
        assertEq(starOwner.tokenURI(1), IPFS_URI_1);
        assertEq(address(starOwner).balance, MINT_PRICE);
    }

    function testMintWithETHRevertsInsufficientPayment() public {
        vm.expectRevert(StarOwner.InsufficientPayment.selector);
        vm.prank(user1);
        starOwner.mint{value: MINT_PRICE - 1}(IPFS_URI_1);
    }

    function testMintWithETHRevertsEmptyURI() public {
        vm.expectRevert(StarOwner.InvalidParameters.selector);
        vm.prank(user1);
        starOwner.mint{value: MINT_PRICE}("");
    }

    function testMintWithToken() public {
        vm.startPrank(user1);
        mockToken.approve(address(starOwner), TOKEN_MINT_PRICE);
        uint256 tokenId = starOwner.mintWithToken(IPFS_URI_1);
        vm.stopPrank();

        assertEq(tokenId, 1);
        assertEq(starOwner.ownerOf(1), user1);
        assertEq(starOwner.totalSupply(), 1);
        assertEq(starOwner.tokenURI(1), IPFS_URI_1);
        assertEq(mockToken.balanceOf(address(starOwner)), TOKEN_MINT_PRICE);
    }

    function testMintWithTokenRevertsWhenNotEnabled() public {
        // Deploy with no payment token
        vm.prank(owner);
        StarOwner noTokenContract = new StarOwner(
            "No Token",
            "NT",
            MINT_PRICE,
            0, // No token price
            address(0) // No payment token
        );

        vm.expectRevert(StarOwner.ERC20PaymentNotEnabled.selector);
        vm.prank(user1);
        noTokenContract.mintWithToken(IPFS_URI_1);
    }

    function testMultipleMints() public {
        vm.prank(user1);
        uint256 token1 = starOwner.mint{value: MINT_PRICE}(IPFS_URI_1);

        vm.prank(user2);
        uint256 token2 = starOwner.mint{value: MINT_PRICE}(IPFS_URI_2);

        assertEq(token1, 1);
        assertEq(token2, 2);
        assertEq(starOwner.totalSupply(), 2);
        assertEq(starOwner.tokenURI(1), IPFS_URI_1);
        assertEq(starOwner.tokenURI(2), IPFS_URI_2);
    }

    // ============ Admin Management Tests ============

    function testCreateAddAdminProposal() public {
        vm.prank(owner);
        uint256 proposalId = starOwner.createAddAdminProposal(admin1);

        assertEq(proposalId, 1);

        // Check proposal details
        (
            address proposer,
            uint256 createdAt,
            uint256 approvalCount,
            uint256 expirationTime,
            bool executed,
            StarOwner.ProposalType proposalType,
            address targetAddress,
            uint256 value
        ) = starOwner.getProposalDetails(proposalId);

        assertEq(proposer, owner);
        assertTrue(createdAt > 0);
        assertEq(approvalCount, 1);
        assertTrue(expirationTime > createdAt);
        assertTrue(executed); // Auto-executed since single admin
        assertEq(uint256(proposalType), uint256(StarOwner.ProposalType.AddAdmin));
        assertEq(targetAddress, admin1);
        assertEq(value, 0);

        // Check admin was added
        bytes32 adminRole = keccak256("ADMIN_ROLE");
        assertTrue(starOwner.hasRole(adminRole, admin1));

        address[] memory admins = starOwner.getAdmins();
        assertEq(admins.length, 2);
        assertEq(starOwner.quorumThreshold(), 2); // 75% of 2 = 2
    }

    function testCreateAddAdminProposalRevertsExistingAdmin() public {
        vm.expectRevert(StarOwner.AdminAlreadyExists.selector);
        vm.prank(owner);
        starOwner.createAddAdminProposal(owner);
    }

    function testCreateRemoveAdminProposal() public {
        // First add another admin
        vm.prank(owner);
        starOwner.createAddAdminProposal(admin1);

        // Now create proposal to remove owner
        vm.prank(owner);
        uint256 proposalId = starOwner.createRemoveAdminProposal(owner);

        // Should require voting since we have 2 admins now
        (,, uint256 approvalCount,, bool executed,,,) = starOwner.getProposalDetails(proposalId);
        assertEq(approvalCount, 1);
        assertFalse(executed);

        // Admin1 votes for the proposal
        vm.prank(admin1);
        starOwner.voteForProposal(proposalId);

        // Now should be executed
        (,, approvalCount,, executed,,,) = starOwner.getProposalDetails(proposalId);
        assertEq(approvalCount, 2);
        assertTrue(executed);

        // Check owner was removed
        bytes32 adminRole = keccak256("ADMIN_ROLE");
        assertFalse(starOwner.hasRole(adminRole, owner));

        address[] memory admins = starOwner.getAdmins();
        assertEq(admins.length, 1);
        assertEq(admins[0], admin1);
    }

    function testCreateRemoveAdminProposalRevertsLastAdmin() public {
        vm.expectRevert(StarOwner.LastAdminCannotBeRemoved.selector);
        vm.prank(owner);
        starOwner.createRemoveAdminProposal(owner);
    }

    function testCreateRemoveAdminProposalRevertsNonExistentAdmin() public {
        vm.expectRevert(StarOwner.AdminDoesNotExist.selector);
        vm.prank(owner);
        starOwner.createRemoveAdminProposal(admin1);
    }

    // ============ Financial Proposal Tests ============

    function testCreateWithdrawFundsProposal() public {
        // First accumulate some funds
        vm.prank(user1);
        starOwner.mint{value: MINT_PRICE}(IPFS_URI_1);

        vm.prank(owner);
        uint256 proposalId = starOwner.createWithdrawFundsProposal(admin1, MINT_PRICE / 2);

        // Check proposal executed (single admin)
        (,,,, bool executed,,,) = starOwner.getProposalDetails(proposalId);
        assertTrue(executed);

        // Check funds were withdrawn
        assertEq(admin1.balance, MINT_PRICE / 2);
        assertEq(address(starOwner).balance, MINT_PRICE / 2);
    }

    function testCreateWithdrawTokensProposal() public {
        // First accumulate some tokens
        vm.startPrank(user1);
        mockToken.approve(address(starOwner), TOKEN_MINT_PRICE);
        starOwner.mintWithToken(IPFS_URI_1);
        vm.stopPrank();

        vm.prank(owner);
        uint256 proposalId = starOwner.createWithdrawTokensProposal(admin1);

        // Check proposal executed
        (,,,, bool executed,,,) = starOwner.getProposalDetails(proposalId);
        assertTrue(executed);

        // Check tokens were withdrawn
        assertEq(mockToken.balanceOf(admin1), TOKEN_MINT_PRICE);
        assertEq(mockToken.balanceOf(address(starOwner)), 0);
    }

    function testCreateSetMintPriceProposal() public {
        uint256 newPrice = 0.02 ether;

        vm.prank(owner);
        uint256 proposalId = starOwner.createSetMintPriceProposal(newPrice);

        // Check proposal executed
        (,,,, bool executed,,,) = starOwner.getProposalDetails(proposalId);
        assertTrue(executed);

        // Check price was updated
        assertEq(starOwner.mintPrice(), newPrice);
    }

    function testCreateSetTokenFeeProposal() public {
        uint256 newFee = 2000 * 10 ** 18;

        vm.prank(owner);
        uint256 proposalId = starOwner.createSetTokenFeeProposal(newFee);

        // Check proposal executed
        (,,,, bool executed,,,) = starOwner.getProposalDetails(proposalId);
        assertTrue(executed);

        // Check fee was updated
        assertEq(starOwner.tokenMintPrice(), newFee);
    }

    function testCreateSetPaymentTokenProposal() public {
        address newToken = makeAddr("newToken");

        vm.prank(owner);
        uint256 proposalId = starOwner.createSetPaymentTokenProposal(newToken);

        // Check proposal executed
        (,,,, bool executed,,,) = starOwner.getProposalDetails(proposalId);
        assertTrue(executed);

        // Check token was updated
        assertEq(starOwner.paymentToken(), newToken);
    }

    // ============ Voting Tests ============

    function testVotingWithMultipleAdmins() public {
        // Add two more admins
        vm.prank(owner);
        starOwner.createAddAdminProposal(admin1);

        vm.prank(owner);
        uint256 addAdmin2Proposal = starOwner.createAddAdminProposal(admin2);

        // Need to vote for second admin since we now have 2 admins (quorum = 2)
        vm.prank(admin1);
        starOwner.voteForProposal(addAdmin2Proposal);

        // Now we have 3 admins, quorum should be 3 (75% of 3 = 2.25 -> 3)
        assertEq(starOwner.quorumThreshold(), 3);

        // Create a proposal that requires voting
        vm.prank(owner);
        uint256 proposalId = starOwner.createSetMintPriceProposal(0.02 ether);

        // Should not be executed yet
        (,, uint256 approvalCount,, bool executed,,,) = starOwner.getProposalDetails(proposalId);
        assertEq(approvalCount, 1);
        assertFalse(executed);

        // Admin1 votes
        vm.prank(admin1);
        starOwner.voteForProposal(proposalId);

        // Still not executed
        (,, approvalCount,, executed,,,) = starOwner.getProposalDetails(proposalId);
        assertEq(approvalCount, 2);
        assertFalse(executed);

        // Admin2 votes
        vm.prank(admin2);
        starOwner.voteForProposal(proposalId);

        // Now should be executed
        (,, approvalCount,, executed,,,) = starOwner.getProposalDetails(proposalId);
        assertEq(approvalCount, 3);
        assertTrue(executed);
        assertEq(starOwner.mintPrice(), 0.02 ether);
    }

    function testVotingReverts() public {
        // Add another admin to enable voting
        vm.prank(owner);
        starOwner.createAddAdminProposal(admin1);

        vm.prank(owner);
        uint256 proposalId = starOwner.createSetMintPriceProposal(0.02 ether);

        // Test already voted
        vm.expectRevert(StarOwner.AlreadyVoted.selector);
        vm.prank(owner);
        starOwner.voteForProposal(proposalId);

        // Test non-admin voting
        vm.expectRevert();
        vm.prank(user1);
        starOwner.voteForProposal(proposalId);

        // Test invalid proposal
        vm.expectRevert(StarOwner.ProposalNotFound.selector);
        vm.prank(admin1);
        starOwner.voteForProposal(999);
    }

    function testExpiredProposal() public {
        // Add another admin to enable voting
        vm.prank(owner);
        starOwner.createAddAdminProposal(admin1);

        vm.prank(owner);
        uint256 proposalId = starOwner.createSetMintPriceProposal(0.02 ether);

        // Fast forward past expiration (7 days + 1 second)
        vm.warp(block.timestamp + 7 days + 1);

        vm.expectRevert(StarOwner.ProposalExpired.selector);
        vm.prank(admin1);
        starOwner.voteForProposal(proposalId);
    }

    // ============ Token URI Management Tests ============

    function testUpdateTokenURI() public {
        // First mint a token
        vm.prank(user1);
        starOwner.mint{value: MINT_PRICE}(IPFS_URI_1);

        // Update URI as admin
        string memory newURI = "ipfs://QmNewHash";
        vm.prank(owner);
        starOwner.updateTokenURI(1, newURI);

        assertEq(starOwner.tokenURI(1), newURI);
    }

    function testUpdateTokenURIOnlyAdmin() public {
        vm.prank(user1);
        starOwner.mint{value: MINT_PRICE}(IPFS_URI_1);

        vm.expectRevert();
        vm.prank(user1);
        starOwner.updateTokenURI(1, "ipfs://QmNewHash");
    }

    function testUpdateTokenURIInvalidToken() public {
        vm.expectRevert(StarOwner.InvalidParameters.selector);
        vm.prank(owner);
        starOwner.updateTokenURI(999, "ipfs://QmNewHash");
    }

    function testTokenURIRevertsForInvalidToken() public {
        vm.expectRevert(StarOwner.InvalidParameters.selector);
        starOwner.tokenURI(999);

        vm.expectRevert(StarOwner.InvalidParameters.selector);
        starOwner.tokenURI(0);
    }

    // ============ View Functions Tests ============

    function testGetContractInfo() public view {
        (
            string memory name_,
            string memory symbol_,
            uint256 totalSupply_,
            uint256 mintPrice_,
            uint256 tokenMintPrice_,
            address paymentToken_,
            uint256 quorumThreshold_,
            uint256 totalProposals_
        ) = starOwner.getContractInfo();

        assertEq(name_, "Pet NFT");
        assertEq(symbol_, "PET");
        assertEq(totalSupply_, 0);
        assertEq(mintPrice_, MINT_PRICE);
        assertEq(tokenMintPrice_, TOKEN_MINT_PRICE);
        assertEq(paymentToken_, address(mockToken));
        assertEq(quorumThreshold_, 1);
        assertEq(totalProposals_, 0);
    }

    function testGetTotalProposals() public {
        assertEq(starOwner.getTotalProposals(), 0);

        vm.prank(owner);
        starOwner.createAddAdminProposal(admin1);

        assertEq(starOwner.getTotalProposals(), 1);
    }

    function testHasVotedForProposal() public {
        vm.prank(owner);
        starOwner.createAddAdminProposal(admin1);

        vm.prank(owner);
        uint256 proposalId = starOwner.createSetMintPriceProposal(0.02 ether);

        assertTrue(starOwner.hasVotedForProposal(proposalId, owner));
        assertFalse(starOwner.hasVotedForProposal(proposalId, admin1));
    }

    // ============ Events Tests ============

    function testMintEvent() public {
        vm.expectEmit(true, true, false, true);
        emit StarOwner.TokenMinted(user1, 1, "ETH");

        vm.prank(user1);
        starOwner.mint{value: MINT_PRICE}(IPFS_URI_1);
    }

    function testMintWithTokenEvent() public {
        vm.startPrank(user1);
        mockToken.approve(address(starOwner), TOKEN_MINT_PRICE);

        vm.expectEmit(true, true, false, true);
        emit StarOwner.TokenMinted(user1, 1, "ERC20");
        starOwner.mintWithToken(IPFS_URI_1);
        vm.stopPrank();
    }

    function testProposalEvents() public {
        vm.expectEmit(true, false, false, true);
        emit StarOwner.ProposalCreated(1, StarOwner.ProposalType.AddAdmin, owner);

        vm.prank(owner);
        starOwner.createAddAdminProposal(admin1);
    }

    // ============ Edge Cases Tests ============

    function testProposalExpiration() public {
        vm.prank(owner);
        starOwner.createAddAdminProposal(admin1);

        vm.prank(owner);
        uint256 proposalId = starOwner.createSetMintPriceProposal(0.02 ether);

        (, uint256 createdAt,, uint256 expirationTime,,,,) = starOwner.getProposalDetails(proposalId);
        assertEq(expirationTime, createdAt + 7 days);
    }

    function testQuorumCalculation() public {
        // 1 admin: quorum = 1
        assertEq(starOwner.quorumThreshold(), 1);

        // 2 admins: 75% of 2 = 1.5 -> 2
        vm.prank(owner);
        starOwner.createAddAdminProposal(admin1);
        assertEq(starOwner.quorumThreshold(), 2);

        // 3 admins: 75% of 3 = 2.25 -> 3
        vm.prank(owner);
        uint256 proposalId = starOwner.createAddAdminProposal(admin2);

        // Need to vote since we now have 2 admins (quorum = 2)
        vm.prank(admin1);
        starOwner.voteForProposal(proposalId);

        assertEq(starOwner.quorumThreshold(), 3);
    }

    function testInvalidAddressReverts() public {
        vm.expectRevert(StarOwner.InvalidAddress.selector);
        vm.prank(owner);
        starOwner.createAddAdminProposal(address(0));

        vm.expectRevert(StarOwner.InvalidAddress.selector);
        vm.prank(owner);
        starOwner.createRemoveAdminProposal(address(0));

        vm.expectRevert(StarOwner.InvalidAddress.selector);
        vm.prank(owner);
        starOwner.createWithdrawFundsProposal(address(0), 100);
    }
}
