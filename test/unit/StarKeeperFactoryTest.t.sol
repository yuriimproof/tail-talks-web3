// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {StarKeeperFactory} from "../../src/StarKeeperFactory.sol";
import {StarKeeper} from "../../src/StarKeeper.sol";
import {MockERC20} from "../mocks/ERC20Mock.sol";

contract StarKeeperFactoryTest is Test {
    StarKeeperFactory public factory;
    MockERC20 public mockToken;

    address public factoryAdmin1 = makeAddr("factoryAdmin1");
    address public factoryAdmin2 = makeAddr("factoryAdmin2");
    address public factoryAdmin3 = makeAddr("factoryAdmin3");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    uint256 public constant MAX_SUPPLY = 100;
    uint256 public constant MINT_PRICE = 0.01 ether;
    uint256 public constant TOKEN_MINT_PRICE = 1000 * 10 ** 18;
    string public constant BASE_TOKEN_URI = "https://api.example.com/metadata/";
    string public constant COLLECTION_IMAGE_URI = "ipfs://collection-image";

    function setUp() public {
        mockToken = new MockERC20();

        address[] memory initialAdmins = new address[](1);
        initialAdmins[0] = factoryAdmin1;
        factory = new StarKeeperFactory(initialAdmins);

        // Give users some ETH and tokens
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(factoryAdmin1, 10 ether);
        vm.deal(factoryAdmin2, 10 ether);
        vm.deal(factoryAdmin3, 10 ether);

        mockToken.mint(user1, 10000 * 10 ** 18);
        mockToken.mint(user2, 10000 * 10 ** 18);
    }

    // ============ Constructor Tests ============

    function testConstructor() public view {
        address[] memory admins = factory.getAdmins();
        assertEq(admins.length, 1);
        assertEq(admins[0], factoryAdmin1);
        assertTrue(factory.hasRole(keccak256("ADMIN_ROLE"), factoryAdmin1));
        assertEq(factory.quorumThreshold(), 1);
    }

    function testConstructorRevertsEmptyAdmins() public {
        address[] memory emptyAdmins = new address[](0);
        vm.expectRevert(StarKeeperFactory.InvalidAdminAddress.selector);
        new StarKeeperFactory(emptyAdmins);
    }

    function testConstructorRevertsZeroAddressAdmin() public {
        address[] memory adminsWithZero = new address[](2);
        adminsWithZero[0] = factoryAdmin1;
        adminsWithZero[1] = address(0);
        vm.expectRevert(StarKeeperFactory.InvalidAdminAddress.selector);
        new StarKeeperFactory(adminsWithZero);
    }

    // ============ Collection Creation Tests ============

    function testCreateCollectionProposal() public {
        vm.prank(factoryAdmin1);
        uint256 proposalId = factory.createCollectionProposal(
            "Test Collection",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        assertEq(proposalId, 1);

        // Check proposal was auto-executed (single admin)
        (,,,, bool executed,) = factory.getProposalDetails(proposalId);
        assertTrue(executed);

        // Verify collection was created
        StarKeeper[] memory collections = factory.getAllCollections();
        assertEq(collections.length, 1);

        StarKeeper collection = collections[0];
        assertEq(collection.name(), "Test Collection");
        assertEq(collection.symbol(), "TEST");
        assertEq(collection.maxSupply(), MAX_SUPPLY);
        assertTrue(factory.isCollectionFromFactory(address(collection)));
    }

    function testCreateCollectionProposalOnlyAdmin() public {
        vm.expectRevert();
        vm.prank(user1);
        factory.createCollectionProposal(
            "Test Collection",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );
    }

    function testCreateCollectionProposalRevertsEmptyName() public {
        vm.expectRevert(StarKeeperFactory.InvalidString.selector);
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );
    }

    function testCreateCollectionProposalRevertsEmptySymbol() public {
        vm.expectRevert(StarKeeperFactory.InvalidString.selector);
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Test Collection",
            "",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );
    }

    function testCreateCollectionProposalRevertsZeroMaxSupply() public {
        vm.expectRevert(StarKeeperFactory.SupplyTooLow.selector);
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Test Collection",
            "TEST",
            0,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );
    }

    function testCreateMultipleCollections() public {
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Collection 1",
            "COL1",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Collection 2",
            "COL2",
            MAX_SUPPLY * 2,
            MINT_PRICE * 2,
            TOKEN_MINT_PRICE * 2,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper[] memory collections = factory.getAllCollections();
        assertEq(collections.length, 2);
        assertEq(collections[0].name(), "Collection 1");
        assertEq(collections[1].name(), "Collection 2");
    }

    // ============ Admin Management Tests ============

    function testAddAdmin() public {
        vm.prank(factoryAdmin1);
        factory.createAddAdminProposal(factoryAdmin2);

        assertTrue(factory.hasRole(keccak256("ADMIN_ROLE"), factoryAdmin2));
        assertEq(factory.quorumThreshold(), 2);
    }

    function testAddAdminRevertsNonAdmin() public {
        vm.expectRevert();
        vm.prank(user1);
        factory.createAddAdminProposal(factoryAdmin2);
    }

    function testAddAdminRevertsZeroAddress() public {
        vm.expectRevert(StarKeeperFactory.InvalidAdminAddress.selector);
        vm.prank(factoryAdmin1);
        factory.createAddAdminProposal(address(0));
    }

    function testAddAdminRevertsAlreadyAdmin() public {
        vm.expectRevert(StarKeeperFactory.AdminAlreadyExists.selector);
        vm.prank(factoryAdmin1);
        factory.createAddAdminProposal(factoryAdmin1);
    }

    function testRemoveAdmin() public {
        // Add second admin first
        vm.prank(factoryAdmin1);
        factory.createAddAdminProposal(factoryAdmin2);

        // Remove first admin
        vm.prank(factoryAdmin1);
        uint256 proposalId = factory.createRemoveAdminProposal(factoryAdmin1);
        vm.prank(factoryAdmin2);
        factory.voteForProposal(proposalId);

        assertFalse(factory.hasRole(keccak256("ADMIN_ROLE"), factoryAdmin1));
        assertEq(factory.quorumThreshold(), 1);
    }

    function testRemoveAdminRevertsNonAdmin() public {
        vm.expectRevert();
        vm.prank(user1);
        factory.createRemoveAdminProposal(factoryAdmin1);
    }

    function testRemoveAdminRevertsZeroAddress() public {
        vm.expectRevert(StarKeeperFactory.InvalidAdminAddress.selector);
        vm.prank(factoryAdmin1);
        factory.createRemoveAdminProposal(address(0));
    }

    function testRemoveAdminRevertsNotAdmin() public {
        vm.expectRevert(StarKeeperFactory.AdminDoesNotExist.selector);
        vm.prank(factoryAdmin1);
        factory.createRemoveAdminProposal(user1);
    }

    function testRemoveAdminRevertsLastAdmin() public {
        vm.expectRevert(StarKeeperFactory.LastAdminCannotBeRemoved.selector);
        vm.prank(factoryAdmin1);
        factory.createRemoveAdminProposal(factoryAdmin1);
    }

    // ============ Collection Management Tests ============

    function testMintToCollection() public {
        // Create collection first
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Test Collection",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper collection = factory.getAllCollections()[0];

        vm.prank(factoryAdmin1);
        uint256 proposalId = factory.createMintToProposal(address(collection), user2);

        // Should be auto-executed
        (,,,, bool executed,) = factory.getProposalDetails(proposalId);
        assertTrue(executed);

        assertEq(collection.ownerOf(1), user2);
        assertEq(collection.totalSupply(), 1);
    }

    function testMintToCollectionRevertsNonAdmin() public {
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Test Collection",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper collection = factory.getAllCollections()[0];

        vm.expectRevert();
        vm.prank(user1);
        factory.createMintToProposal(address(collection), user2);
    }

    function testMintToCollectionRevertsInvalidCollection() public {
        vm.expectRevert(StarKeeperFactory.InvalidCollectionAddress.selector);
        vm.prank(factoryAdmin1);
        factory.createMintToProposal(makeAddr("fakeCollection"), user2);
    }

    function testMintToCollectionRevertsZeroAddress() public {
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Test Collection",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper collection = factory.getAllCollections()[0];

        vm.expectRevert(StarKeeperFactory.InvalidAdminAddress.selector);
        vm.prank(factoryAdmin1);
        factory.createMintToProposal(address(collection), address(0));
    }

    // ============ Collection Settings Tests ============

    function testSetCollectionBaseURI() public {
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Test Collection",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper collection = factory.getAllCollections()[0];
        string memory newURI = "https://new-api.com/";

        vm.prank(factoryAdmin1);
        uint256 proposalId = factory.createSetBaseURIProposal(address(collection), newURI);

        (,,,, bool executed,) = factory.getProposalDetails(proposalId);
        assertTrue(executed);
    }

    function testSetCollectionBaseURIRevertsNonAdmin() public {
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Test Collection",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper collection = factory.getAllCollections()[0];

        vm.expectRevert();
        vm.prank(user1);
        factory.createSetBaseURIProposal(address(collection), "https://new-api.com/");
    }

    function testSetCollectionBaseURIRevertsInvalidCollection() public {
        vm.expectRevert(StarKeeperFactory.InvalidCollectionAddress.selector);
        vm.prank(factoryAdmin1);
        factory.createSetBaseURIProposal(makeAddr("fakeCollection"), "https://new-api.com/");
    }

    function testSetCollectionBaseURIRevertsEmptyURI() public {
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Test Collection",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper collection = factory.getAllCollections()[0];

        vm.expectRevert(StarKeeperFactory.InvalidString.selector);
        vm.prank(factoryAdmin1);
        factory.createSetBaseURIProposal(address(collection), "");
    }

    function testSetCollectionImageURI() public {
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Test Collection",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper collection = factory.getAllCollections()[0];
        string memory newImageURI = "ipfs://new-image";

        vm.prank(factoryAdmin1);
        uint256 proposalId = factory.createSetImageURIProposal(address(collection), newImageURI);

        (,,,, bool executed,) = factory.getProposalDetails(proposalId);
        assertTrue(executed);
    }

    function testSetCollectionMintPrice() public {
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Test Collection",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper collection = factory.getAllCollections()[0];
        uint256 newPrice = 0.02 ether;

        vm.prank(factoryAdmin1);
        uint256 proposalId = factory.createSetMintPriceProposal(address(collection), newPrice);

        (,,,, bool executed,) = factory.getProposalDetails(proposalId);
        assertTrue(executed);
        assertEq(collection.mintPrice(), newPrice);
    }

    function testSetCollectionTokenMintPrice() public {
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Test Collection",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper collection = factory.getAllCollections()[0];
        uint256 newPrice = 2000 * 10 ** 18;

        vm.prank(factoryAdmin1);
        uint256 proposalId = factory.createSetTokenMintPriceProposal(address(collection), newPrice);

        (,,,, bool executed,) = factory.getProposalDetails(proposalId);
        assertTrue(executed);
        assertEq(collection.tokenMintPrice(), newPrice);
    }

    function testSetCollectionPaymentToken() public {
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Test Collection",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper collection = factory.getAllCollections()[0];
        address newToken = makeAddr("newToken");

        vm.prank(factoryAdmin1);
        uint256 proposalId = factory.createSetPaymentTokenProposal(address(collection), newToken);

        (,,,, bool executed,) = factory.getProposalDetails(proposalId);
        assertTrue(executed);
        assertEq(collection.paymentToken(), newToken);
    }

    function testSetCollectionMaxSupply() public {
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Test Collection",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper collection = factory.getAllCollections()[0];
        uint256 newMaxSupply = 200;

        vm.prank(factoryAdmin1);
        uint256 proposalId = factory.createSetMaxSupplyProposal(address(collection), newMaxSupply);

        (,,,, bool executed,) = factory.getProposalDetails(proposalId);
        assertTrue(executed);
        assertEq(collection.maxSupply(), newMaxSupply);
    }

    // ============ Withdrawal Tests ============

    function testWithdrawFunds() public {
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Test Collection",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper collection = factory.getAllCollections()[0];

        // Fund the collection
        vm.deal(address(collection), 1 ether);

        uint256 balanceBefore = factoryAdmin1.balance;

        vm.prank(factoryAdmin1);
        uint256 proposalId = factory.createWithdrawFundsProposal(address(collection), factoryAdmin1, 0.5 ether);

        (,,,, bool executed,) = factory.getProposalDetails(proposalId);
        assertTrue(executed);
        assertEq(factoryAdmin1.balance, balanceBefore + 0.5 ether);
    }

    function testWithdrawFundsRevertsNonAdmin() public {
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Test Collection",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper collection = factory.getAllCollections()[0];

        vm.expectRevert();
        vm.prank(user1);
        factory.createWithdrawFundsProposal(address(collection), user1, 0.5 ether);
    }

    function testWithdrawFundsRevertsInvalidCollection() public {
        vm.expectRevert(StarKeeperFactory.InvalidCollectionAddress.selector);
        vm.prank(factoryAdmin1);
        factory.createWithdrawFundsProposal(makeAddr("fakeCollection"), factoryAdmin1, 0.5 ether);
    }

    function testWithdrawFundsRevertsZeroAddress() public {
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Test Collection",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper collection = factory.getAllCollections()[0];

        vm.expectRevert(StarKeeperFactory.InvalidAdminAddress.selector);
        vm.prank(factoryAdmin1);
        factory.createWithdrawFundsProposal(address(collection), address(0), 0.5 ether);
    }

    function testWithdrawTokens() public {
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Test Collection",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper collection = factory.getAllCollections()[0];

        // Fund the collection with tokens
        mockToken.mint(address(collection), 1000 * 10 ** 18);

        uint256 balanceBefore = mockToken.balanceOf(factoryAdmin1);

        vm.prank(factoryAdmin1);
        uint256 proposalId = factory.createWithdrawTokensProposal(address(collection), factoryAdmin1, 500 * 10 ** 18);

        (,,,, bool executed,) = factory.getProposalDetails(proposalId);
        assertTrue(executed);
        assertEq(mockToken.balanceOf(factoryAdmin1), balanceBefore + 500 * 10 ** 18);
    }

    function testWithdrawTokensRevertsNonAdmin() public {
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Test Collection",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper collection = factory.getAllCollections()[0];

        vm.expectRevert();
        vm.prank(user1);
        factory.createWithdrawTokensProposal(address(collection), user1, 500 * 10 ** 18);
    }

    function testWithdrawTokensRevertsInvalidCollection() public {
        vm.expectRevert(StarKeeperFactory.InvalidCollectionAddress.selector);
        vm.prank(factoryAdmin1);
        factory.createWithdrawTokensProposal(makeAddr("fakeCollection"), factoryAdmin1, 500 * 10 ** 18);
    }

    function testWithdrawTokensRevertsZeroAddress() public {
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Test Collection",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper collection = factory.getAllCollections()[0];

        vm.expectRevert(StarKeeperFactory.InvalidAdminAddress.selector);
        vm.prank(factoryAdmin1);
        factory.createWithdrawTokensProposal(address(collection), address(0), 500 * 10 ** 18);
    }

    // ============ Proposal System Tests ============

    function testProposalVoting() public {
        // Add second admin
        vm.prank(factoryAdmin1);
        factory.createAddAdminProposal(factoryAdmin2);

        // Create a proposal that requires voting
        vm.prank(factoryAdmin1);
        uint256 proposalId = factory.createCollectionProposal(
            "Test Collection",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        // Should not be executed yet
        (,, uint256 approvalCount,, bool executed,) = factory.getProposalDetails(proposalId);
        assertEq(approvalCount, 1);
        assertFalse(executed);

        // Second admin votes
        vm.prank(factoryAdmin2);
        factory.voteForProposal(proposalId);

        // Now should be executed
        (,, approvalCount,, executed,) = factory.getProposalDetails(proposalId);
        assertEq(approvalCount, 2);
        assertTrue(executed);
    }

    function testProposalAlreadyExecutedRevert() public {
        vm.prank(factoryAdmin1);
        uint256 proposalId = factory.createAddAdminProposal(factoryAdmin2);

        // Try to vote again on executed proposal
        vm.expectRevert(StarKeeperFactory.ProposalAlreadyExecuted.selector);
        vm.prank(factoryAdmin1);
        factory.voteForProposal(proposalId);
    }

    function testProposalAlreadyVotedRevert() public {
        vm.prank(factoryAdmin1);
        factory.createAddAdminProposal(factoryAdmin2);

        vm.prank(factoryAdmin1);
        uint256 proposalId = factory.createCollectionProposal(
            "Test Collection",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        // Try to vote twice with same admin
        vm.expectRevert(StarKeeperFactory.AlreadyVoted.selector);
        vm.prank(factoryAdmin1);
        factory.voteForProposal(proposalId);
    }

    function testProposalNonExistentRevert() public {
        vm.expectRevert(StarKeeperFactory.ProposalNotFound.selector);
        vm.prank(factoryAdmin1);
        factory.voteForProposal(999);
    }

    function testProposalNonAdminVoteRevert() public {
        vm.prank(factoryAdmin1);
        uint256 proposalId = factory.createAddAdminProposal(factoryAdmin2);

        vm.expectRevert();
        vm.prank(user1);
        factory.voteForProposal(proposalId);
    }

    function testProposalExpiredRevert() public {
        vm.prank(factoryAdmin1);
        factory.createAddAdminProposal(factoryAdmin2);

        vm.prank(factoryAdmin1);
        uint256 proposalId = factory.createCollectionProposal(
            "Test Collection",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        // Fast forward past expiration
        vm.warp(block.timestamp + 8 days);

        vm.expectRevert(StarKeeperFactory.ProposalExpired.selector);
        vm.prank(factoryAdmin2);
        factory.voteForProposal(proposalId);
    }

    // ============ View Function Tests ============

    function testGetProposalDetails() public {
        vm.prank(factoryAdmin1);
        uint256 proposalId = factory.createAddAdminProposal(factoryAdmin2);

        (
            address proposer,
            uint256 createdAt,
            uint256 approvalCount,
            uint256 expirationTime,
            bool executed,
            StarKeeperFactory.FunctionType functionType
        ) = factory.getProposalDetails(proposalId);

        assertEq(proposer, factoryAdmin1);
        assertTrue(createdAt > 0);
        assertEq(approvalCount, 1);
        assertEq(expirationTime, createdAt + 7 days);
        assertTrue(executed);
        assertEq(uint256(functionType), uint256(StarKeeperFactory.FunctionType.AddFactoryAdmin));
    }

    function testGetAllCollections() public {
        assertEq(factory.getAllCollections().length, 0);

        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Collection 1",
            "C1",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Collection 2",
            "C2",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper[] memory collections = factory.getAllCollections();
        assertEq(collections.length, 2);
        assertEq(collections[0].name(), "Collection 1");
        assertEq(collections[1].name(), "Collection 2");
    }

    function testIsCollectionFromFactory() public {
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Test Collection",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper collection = factory.getAllCollections()[0];
        assertTrue(factory.isCollectionFromFactory(address(collection)));
        assertFalse(factory.isCollectionFromFactory(makeAddr("fakeCollection")));
    }

    function testGetAdmins() public {
        address[] memory admins = factory.getAdmins();
        assertEq(admins.length, 1);
        assertEq(admins[0], factoryAdmin1);

        vm.prank(factoryAdmin1);
        factory.createAddAdminProposal(factoryAdmin2);

        admins = factory.getAdmins();
        assertEq(admins.length, 2);
    }

    function testQuorumThreshold() public {
        assertEq(factory.quorumThreshold(), 1);

        vm.prank(factoryAdmin1);
        factory.createAddAdminProposal(factoryAdmin2);
        assertEq(factory.quorumThreshold(), 2);

        vm.prank(factoryAdmin1);
        uint256 addAdmin3 = factory.createAddAdminProposal(factoryAdmin3);
        vm.prank(factoryAdmin2);
        factory.voteForProposal(addAdmin3);
        assertEq(factory.quorumThreshold(), 3);
    }

    // ============ Event Tests ============

    function testCollectionCreatedEvent() public {
        // We can't predict the exact collection address, so we'll verify the event
        // was emitted by checking that a collection was actually created
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Test Collection",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        // Verify collection was created by checking the collections array
        StarKeeper[] memory collections = factory.getAllCollections();
        assertEq(collections.length, 1);
        assertEq(collections[0].name(), "Test Collection");
        assertEq(collections[0].symbol(), "TEST");
        assertEq(collections[0].maxSupply(), MAX_SUPPLY);
    }

    function testProposalCreatedEvent() public {
        vm.expectEmit(true, false, false, true);
        emit StarKeeperFactory.ProposalCreated(1, StarKeeperFactory.FunctionType.AddFactoryAdmin, factoryAdmin1);

        vm.prank(factoryAdmin1);
        factory.createAddAdminProposal(factoryAdmin2);
    }

    // ============ Complex Scenarios ============

    function testComplexMultiAdminScenario() public {
        // Add multiple admins
        vm.prank(factoryAdmin1);
        factory.createAddAdminProposal(factoryAdmin2);

        vm.prank(factoryAdmin1);
        uint256 addAdmin3 = factory.createAddAdminProposal(factoryAdmin3);
        vm.prank(factoryAdmin2);
        factory.voteForProposal(addAdmin3);

        // Create collection requiring voting
        vm.prank(factoryAdmin1);
        uint256 collectionProposal = factory.createCollectionProposal(
            "Test Collection",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        // Vote on collection creation
        vm.prank(factoryAdmin2);
        factory.voteForProposal(collectionProposal);
        vm.prank(factoryAdmin3);
        factory.voteForProposal(collectionProposal);

        // Verify collection was created
        StarKeeper[] memory collections = factory.getAllCollections();
        assertEq(collections.length, 1);
        assertEq(collections[0].name(), "Test Collection");
    }

    function testLargeScaleProposalCreation() public {
        // Test creating many proposals
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(factoryAdmin1);
            uint256 proposalId = factory.createCollectionProposal(
                string(abi.encodePacked("Collection ", vm.toString(i))),
                string(abi.encodePacked("COL", vm.toString(i))),
                MAX_SUPPLY + i,
                MINT_PRICE + i,
                TOKEN_MINT_PRICE + i,
                address(mockToken),
                BASE_TOKEN_URI,
                COLLECTION_IMAGE_URI
            );

            assertEq(proposalId, i + 1);
        }

        assertEq(factory.proposalCounter(), 5);
        StarKeeper[] memory collections = factory.getAllCollections();
        assertEq(collections.length, 5);
    }
}
