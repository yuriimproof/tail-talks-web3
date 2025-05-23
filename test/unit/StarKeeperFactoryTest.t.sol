// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {StarKeeperFactory} from "../../src/StarKeeperFactory.sol";
import {StarKeeper} from "../../src/StarKeeper.sol";
import {MockERC20} from "../mocks/ERC20Mock.sol";

contract StarKeeperFactoryTest is Test {
    StarKeeperFactory public factory;
    MockERC20 public mockToken;

    address public admin1 = makeAddr("admin1");
    address public admin2 = makeAddr("admin2");
    address public admin3 = makeAddr("admin3");
    address public nonAdmin = makeAddr("nonAdmin");

    uint256 public constant MAX_SUPPLY = 100;
    uint256 public constant MINT_PRICE = 0.01 ether;
    uint256 public constant TOKEN_MINT_PRICE = 1000 * 10 ** 18;
    string public constant BASE_TOKEN_URI = "https://api.example.com/metadata/";
    string public constant COLLECTION_IMAGE_URI = "ipfs://collection-image";

    function setUp() public {
        mockToken = new MockERC20();

        // Setup factory with single admin initially
        address[] memory initialAdmins = new address[](1);
        initialAdmins[0] = admin1;
        factory = new StarKeeperFactory(initialAdmins);
    }

    // ============ Constructor Tests ============

    function testConstructor() public view {
        address[] memory admins = factory.getAdmins();
        assertEq(admins.length, 1);
        assertEq(admins[0], admin1);
        assertEq(factory.quorumThreshold(), 1);

        bytes32 adminRole = keccak256("ADMIN_ROLE");
        assertTrue(factory.hasRole(adminRole, admin1));
    }

    function testConstructorWithMultipleAdmins() public {
        address[] memory initialAdmins = new address[](3);
        initialAdmins[0] = admin1;
        initialAdmins[1] = admin2;
        initialAdmins[2] = admin3;

        StarKeeperFactory newFactory = new StarKeeperFactory(initialAdmins);

        address[] memory admins = newFactory.getAdmins();
        assertEq(admins.length, 3);
        assertEq(newFactory.quorumThreshold(), 3); // 75% of 3 = 2.25 -> 3

        bytes32 adminRole = keccak256("ADMIN_ROLE");
        assertTrue(newFactory.hasRole(adminRole, admin1));
        assertTrue(newFactory.hasRole(adminRole, admin2));
        assertTrue(newFactory.hasRole(adminRole, admin3));
    }

    function testConstructorRevertsEmptyAdmins() public {
        address[] memory emptyAdmins = new address[](0);

        vm.expectRevert(StarKeeperFactory.InvalidAdminAddress.selector);
        new StarKeeperFactory(emptyAdmins);
    }

    function testConstructorRevertsZeroAddressAdmin() public {
        address[] memory adminsWithZero = new address[](2);
        adminsWithZero[0] = admin1;
        adminsWithZero[1] = address(0);

        vm.expectRevert(StarKeeperFactory.InvalidAdminAddress.selector);
        new StarKeeperFactory(adminsWithZero);
    }

    // ============ Collection Creation Tests ============

    function testCreateCollectionProposal() public {
        vm.prank(admin1);
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
        assertEq(collection.factory(), address(factory));
        assertTrue(factory.isCollectionFromFactory(address(collection)));
    }

    function testCreateCollectionProposalOnlyAdmin() public {
        vm.expectRevert();
        vm.prank(nonAdmin);
        factory.createCollectionProposal(
            "Test",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );
    }

    function testCreateCollectionProposalRevertsZeroMaxSupply() public {
        vm.expectRevert(StarKeeperFactory.InvalidMaxSupply.selector);
        vm.prank(admin1);
        factory.createCollectionProposal(
            "Test",
            "TEST",
            0, // Invalid max supply
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );
    }

    // ============ Admin Management Tests ============

    function testCreateAddAdminProposal() public {
        vm.prank(admin1);
        uint256 proposalId = factory.createAddAdminProposal(admin2);

        assertEq(proposalId, 1);

        // Check proposal was auto-executed
        (,,,, bool executed,) = factory.getProposalDetails(proposalId);
        assertTrue(executed);

        // Verify admin was added
        address[] memory admins = factory.getAdmins();
        assertEq(admins.length, 2);
        assertEq(factory.quorumThreshold(), 2); // 75% of 2 = 1.5 -> 2

        bytes32 adminRole = keccak256("ADMIN_ROLE");
        assertTrue(factory.hasRole(adminRole, admin2));
    }

    function testCreateAddAdminProposalRevertsExistingAdmin() public {
        vm.expectRevert(StarKeeperFactory.AdminAlreadyExists.selector);
        vm.prank(admin1);
        factory.createAddAdminProposal(admin1);
    }

    function testCreateAddAdminProposalRevertsZeroAddress() public {
        vm.expectRevert(StarKeeperFactory.InvalidAdminAddress.selector);
        vm.prank(admin1);
        factory.createAddAdminProposal(address(0));
    }

    function testCreateRemoveAdminProposal() public {
        // First add another admin
        vm.prank(admin1);
        factory.createAddAdminProposal(admin2);

        // Now create proposal to remove admin1
        vm.prank(admin1);
        uint256 proposalId = factory.createRemoveAdminProposal(admin1);

        // Should require voting since we have 2 admins now
        (,, uint256 approvalCount,, bool executed,) = factory.getProposalDetails(proposalId);
        assertEq(approvalCount, 1);
        assertFalse(executed);

        // Admin2 votes for the proposal
        vm.prank(admin2);
        factory.voteForProposal(proposalId);

        // Now should be executed
        (,, approvalCount,, executed,) = factory.getProposalDetails(proposalId);
        assertEq(approvalCount, 2);
        assertTrue(executed);

        // Check admin1 was removed
        bytes32 adminRole = keccak256("ADMIN_ROLE");
        assertFalse(factory.hasRole(adminRole, admin1));

        address[] memory admins = factory.getAdmins();
        assertEq(admins.length, 1);
        assertEq(admins[0], admin2);
    }

    function testCreateRemoveAdminProposalRevertsLastAdmin() public {
        vm.expectRevert(StarKeeperFactory.LastAdminCannotBeRemoved.selector);
        vm.prank(admin1);
        factory.createRemoveAdminProposal(admin1);
    }

    function testCreateRemoveAdminProposalRevertsNonExistentAdmin() public {
        vm.expectRevert(StarKeeperFactory.AdminDoesNotExist.selector);
        vm.prank(admin1);
        factory.createRemoveAdminProposal(admin2);
    }

    // ============ Collection Management Proposal Tests ============

    function testCreateSetBaseURIProposal() public {
        // First create a collection
        vm.prank(admin1);
        factory.createCollectionProposal(
            "Test",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper[] memory collections = factory.getAllCollections();
        address collectionAddress = address(collections[0]);

        string memory newURI = "https://new-api.com/";
        vm.prank(admin1);
        uint256 proposalId = factory.createSetBaseURIProposal(collectionAddress, newURI);

        // Should be auto-executed
        (,,,, bool executed,) = factory.getProposalDetails(proposalId);
        assertTrue(executed);
    }

    function testCreateSetMintPriceProposal() public {
        // Create collection first
        vm.prank(admin1);
        factory.createCollectionProposal(
            "Test",
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

        vm.prank(admin1);
        uint256 proposalId = factory.createSetMintPriceProposal(address(collection), newPrice);

        (,,,, bool executed,) = factory.getProposalDetails(proposalId);
        assertTrue(executed);
        assertEq(collection.mintPrice(), newPrice);
    }

    function testCreateSetTokenMintPriceProposal() public {
        vm.prank(admin1);
        factory.createCollectionProposal(
            "Test",
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

        vm.prank(admin1);
        uint256 proposalId = factory.createSetTokenMintPriceProposal(address(collection), newPrice);

        (,,,, bool executed,) = factory.getProposalDetails(proposalId);
        assertTrue(executed);
        assertEq(collection.tokenMintPrice(), newPrice);
    }

    function testCreateSetPaymentTokenProposal() public {
        vm.prank(admin1);
        factory.createCollectionProposal(
            "Test",
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

        vm.prank(admin1);
        uint256 proposalId = factory.createSetPaymentTokenProposal(address(collection), newToken);

        (,,,, bool executed,) = factory.getProposalDetails(proposalId);
        assertTrue(executed);
        assertEq(collection.paymentToken(), newToken);
    }

    function testCreateSetImageURIProposal() public {
        vm.prank(admin1);
        factory.createCollectionProposal(
            "Test",
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

        vm.prank(admin1);
        uint256 proposalId = factory.createSetImageURIProposal(address(collection), newImageURI);

        (,,,, bool executed,) = factory.getProposalDetails(proposalId);
        assertTrue(executed);
        assertEq(collection.collectionImageURI(), newImageURI);
    }

    function testCreateSetMaxSupplyProposal() public {
        vm.prank(admin1);
        factory.createCollectionProposal(
            "Test",
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

        vm.prank(admin1);
        uint256 proposalId = factory.createSetMaxSupplyProposal(address(collection), newMaxSupply);

        (,,,, bool executed,) = factory.getProposalDetails(proposalId);
        assertTrue(executed);
        assertEq(collection.maxSupply(), newMaxSupply);
    }

    function testCreateMintToProposal() public {
        vm.prank(admin1);
        factory.createCollectionProposal(
            "Test",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper collection = factory.getAllCollections()[0];
        address recipient = makeAddr("recipient");

        vm.prank(admin1);
        uint256 proposalId = factory.createMintToProposal(address(collection), recipient);

        (,,,, bool executed,) = factory.getProposalDetails(proposalId);
        assertTrue(executed);
        assertEq(collection.totalSupply(), 1);
        assertEq(collection.ownerOf(1), recipient);
    }

    function testCreateWithdrawFundsProposal() public {
        vm.prank(admin1);
        factory.createCollectionProposal(
            "Test",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper collection = factory.getAllCollections()[0];

        // Fund the collection by sending ETH directly
        vm.deal(address(collection), 1 ether);

        address recipient = makeAddr("recipient");
        uint256 recipientBalanceBefore = recipient.balance;

        vm.prank(admin1);
        uint256 proposalId = factory.createWithdrawFundsProposal(address(collection), recipient, 0.5 ether);

        (,,,, bool executed,) = factory.getProposalDetails(proposalId);
        assertTrue(executed);
        assertEq(recipient.balance, recipientBalanceBefore + 0.5 ether);
    }

    function testCreateWithdrawTokensProposal() public {
        vm.prank(admin1);
        factory.createCollectionProposal(
            "Test",
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

        address recipient = makeAddr("recipient");
        uint256 recipientBalanceBefore = mockToken.balanceOf(recipient);

        vm.prank(admin1);
        uint256 proposalId = factory.createWithdrawTokensProposal(address(collection), recipient);

        (,,,, bool executed,) = factory.getProposalDetails(proposalId);
        assertTrue(executed);
        assertEq(mockToken.balanceOf(recipient), recipientBalanceBefore + 1000 * 10 ** 18);
    }

    function testProposalRevertsInvalidCollection() public {
        address fakeCollection = makeAddr("fakeCollection");

        vm.expectRevert(StarKeeperFactory.InvalidCollectionAddress.selector);
        vm.prank(admin1);
        factory.createSetMintPriceProposal(fakeCollection, 0.02 ether);
    }

    // ============ Voting Tests ============

    function testVotingWithMultipleAdmins() public {
        // Add more admins
        vm.prank(admin1);
        factory.createAddAdminProposal(admin2);
        vm.prank(admin1);
        uint256 addAdmin3Proposal = factory.createAddAdminProposal(admin3);

        // Vote for adding admin3
        vm.prank(admin2);
        factory.voteForProposal(addAdmin3Proposal);

        // Now we have 3 admins, create a collection proposal that requires voting
        vm.prank(admin1);
        uint256 collectionProposal = factory.createCollectionProposal(
            "Test",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        // Vote for collection creation (requires all 3 admins)
        vm.prank(admin2);
        factory.voteForProposal(collectionProposal);
        vm.prank(admin3);
        factory.voteForProposal(collectionProposal);

        StarKeeper collection = factory.getAllCollections()[0];

        vm.prank(admin1);
        uint256 proposalId = factory.createSetMintPriceProposal(address(collection), 0.02 ether);

        // Should not be executed yet (quorum = 3)
        (,, uint256 approvalCount,, bool executed,) = factory.getProposalDetails(proposalId);
        assertEq(approvalCount, 1);
        assertFalse(executed);

        // Admin2 votes
        vm.prank(admin2);
        factory.voteForProposal(proposalId);

        // Still not executed
        (,, approvalCount,, executed,) = factory.getProposalDetails(proposalId);
        assertEq(approvalCount, 2);
        assertFalse(executed);

        // Admin3 votes
        vm.prank(admin3);
        factory.voteForProposal(proposalId);

        // Now should be executed
        (,, approvalCount,, executed,) = factory.getProposalDetails(proposalId);
        assertEq(approvalCount, 3);
        assertTrue(executed);
        assertEq(collection.mintPrice(), 0.02 ether);
    }

    function testVotingRevertsAlreadyVoted() public {
        vm.prank(admin1);
        factory.createAddAdminProposal(admin2);

        // Create a collection first - this will require voting since we have 2 admins now
        vm.prank(admin1);
        uint256 collectionProposal = factory.createCollectionProposal(
            "Test",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        // Vote for collection creation
        vm.prank(admin2);
        factory.voteForProposal(collectionProposal);

        StarKeeper collection = factory.getAllCollections()[0];

        vm.prank(admin1);
        uint256 proposalId = factory.createSetMintPriceProposal(address(collection), 0.02 ether);

        vm.expectRevert(StarKeeperFactory.AlreadyVoted.selector);
        vm.prank(admin1);
        factory.voteForProposal(proposalId);
    }

    function testVotingRevertsNonAdmin() public {
        vm.prank(admin1);
        uint256 proposalId = factory.createAddAdminProposal(admin2);

        vm.expectRevert();
        vm.prank(nonAdmin);
        factory.voteForProposal(proposalId);
    }

    function testVotingRevertsInvalidProposal() public {
        vm.expectRevert(StarKeeperFactory.ProposalNotFound.selector);
        vm.prank(admin1);
        factory.voteForProposal(999);
    }

    function testVotingRevertsExpiredProposal() public {
        vm.prank(admin1);
        factory.createAddAdminProposal(admin2);

        // Create a collection first - this will require voting since we have 2 admins now
        vm.prank(admin1);
        uint256 collectionProposal = factory.createCollectionProposal(
            "Test",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        // Vote for collection creation
        vm.prank(admin2);
        factory.voteForProposal(collectionProposal);

        StarKeeper collection = factory.getAllCollections()[0];

        vm.prank(admin1);
        uint256 proposalId = factory.createSetMintPriceProposal(address(collection), 0.02 ether);

        // Fast forward past expiration
        vm.warp(block.timestamp + 8 days);

        vm.expectRevert(StarKeeperFactory.ProposalExpired.selector);
        vm.prank(admin2);
        factory.voteForProposal(proposalId);
    }

    function testVotingRevertsAlreadyExecuted() public {
        vm.prank(admin1);
        uint256 proposalId = factory.createAddAdminProposal(admin2);

        // Proposal was auto-executed, try to vote again
        vm.expectRevert(StarKeeperFactory.ProposalAlreadyExecuted.selector);
        vm.prank(admin1);
        factory.voteForProposal(proposalId);
    }

    // ============ View Functions Tests ============

    function testGetProposalDetails() public {
        vm.prank(admin1);
        uint256 proposalId = factory.createAddAdminProposal(admin2);

        (
            address proposer,
            uint256 createdAt,
            uint256 approvalCount,
            uint256 expirationTime,
            bool executed,
            StarKeeperFactory.FunctionType functionType
        ) = factory.getProposalDetails(proposalId);

        assertEq(proposer, admin1);
        assertTrue(createdAt > 0);
        assertEq(approvalCount, 1);
        assertEq(expirationTime, createdAt + 7 days);
        assertTrue(executed);
        assertEq(uint256(functionType), uint256(StarKeeperFactory.FunctionType.AddFactoryAdmin));
    }

    function testHasVotedForProposal() public {
        vm.prank(admin1);
        factory.createAddAdminProposal(admin2);

        // Create a collection first - this will require voting since we have 2 admins now
        vm.prank(admin1);
        uint256 collectionProposal = factory.createCollectionProposal(
            "Test",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        // Vote for collection creation
        vm.prank(admin2);
        factory.voteForProposal(collectionProposal);

        StarKeeper collection = factory.getAllCollections()[0];

        vm.prank(admin1);
        uint256 proposalId = factory.createSetMintPriceProposal(address(collection), 0.02 ether);

        assertTrue(factory.hasVotedForProposal(proposalId, admin1));
        assertFalse(factory.hasVotedForProposal(proposalId, admin2));
    }

    function testGetProposalFunctionData() public {
        vm.prank(admin1);
        uint256 proposalId = factory.createAddAdminProposal(admin2);

        bytes memory functionData = factory.getProposalFunctionData(proposalId);
        address decodedAdmin = abi.decode(functionData, (address));
        assertEq(decodedAdmin, admin2);
    }

    function testGetAllCollections() public {
        assertEq(factory.getAllCollections().length, 0);

        vm.prank(admin1);
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

        vm.prank(admin1);
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

    function testGetCreatorCollections() public {
        vm.prank(admin1);
        factory.createCollectionProposal(
            "Admin1 Collection",
            "A1C",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper[] memory admin1Collections = factory.getCreatorCollections(admin1);
        assertEq(admin1Collections.length, 1);
        assertEq(admin1Collections[0].name(), "Admin1 Collection");

        StarKeeper[] memory admin2Collections = factory.getCreatorCollections(admin2);
        assertEq(admin2Collections.length, 0);
    }

    function testIsCollectionFromFactory() public {
        vm.prank(admin1);
        factory.createCollectionProposal(
            "Test",
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
        assertEq(admins[0], admin1);

        vm.prank(admin1);
        factory.createAddAdminProposal(admin2);

        admins = factory.getAdmins();
        assertEq(admins.length, 2);
    }

    // ============ Events Tests ============

    function testCollectionCreatedEvent() public {
        vm.recordLogs();

        vm.prank(admin1);
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

        // Check that CollectionCreated event was emitted
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool foundEvent = false;

        for (uint256 i = 0; i < entries.length; i++) {
            if (
                entries[i].topics[0]
                    == keccak256("CollectionCreated(address,address,string,uint256,uint256,address,uint256,string)")
            ) {
                foundEvent = true;
                break;
            }
        }

        assertTrue(foundEvent, "CollectionCreated event should be emitted");
    }

    function testProposalCreatedEvent() public {
        vm.expectEmit(true, false, false, true);
        emit StarKeeperFactory.ProposalCreated(1, StarKeeperFactory.FunctionType.AddFactoryAdmin, admin1);

        vm.prank(admin1);
        factory.createAddAdminProposal(admin2);
    }

    function testProposalVotedEvent() public {
        vm.prank(admin1);
        factory.createAddAdminProposal(admin2);

        // Create a collection first - this will require voting since we have 2 admins now
        vm.prank(admin1);
        uint256 collectionProposal = factory.createCollectionProposal(
            "Test",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        // Vote for collection creation
        vm.prank(admin2);
        factory.voteForProposal(collectionProposal);

        StarKeeper collection = factory.getAllCollections()[0];

        vm.prank(admin1);
        uint256 proposalId = factory.createSetMintPriceProposal(address(collection), 0.02 ether);

        vm.expectEmit(true, true, false, true);
        emit StarKeeperFactory.ProposalVoted(proposalId, admin2);

        vm.prank(admin2);
        factory.voteForProposal(proposalId);
    }

    function testProposalExecutedEvent() public {
        vm.expectEmit(true, false, false, true);
        emit StarKeeperFactory.ProposalExecuted(1, StarKeeperFactory.FunctionType.AddFactoryAdmin);

        vm.prank(admin1);
        factory.createAddAdminProposal(admin2);
    }

    // ============ Quorum Threshold Tests ============

    function testQuorumThresholdCalculation() public {
        // 1 admin: quorum = 1
        assertEq(factory.quorumThreshold(), 1);

        // 2 admins: 75% of 2 = 1.5 -> 2
        vm.prank(admin1);
        factory.createAddAdminProposal(admin2);
        assertEq(factory.quorumThreshold(), 2);

        // 3 admins: 75% of 3 = 2.25 -> 3
        vm.prank(admin1);
        uint256 proposalId = factory.createAddAdminProposal(admin3);
        vm.prank(admin2);
        factory.voteForProposal(proposalId);
        assertEq(factory.quorumThreshold(), 3);

        // 4 admins: 75% of 4 = 3
        address admin4 = makeAddr("admin4");
        vm.prank(admin1);
        proposalId = factory.createAddAdminProposal(admin4);
        vm.prank(admin2);
        factory.voteForProposal(proposalId);
        vm.prank(admin3);
        factory.voteForProposal(proposalId);
        assertEq(factory.quorumThreshold(), 3);
    }

    // ============ Edge Cases Tests ============

    function testProposalCounter() public {
        assertEq(factory.proposalCounter(), 0);

        vm.prank(admin1);
        factory.createAddAdminProposal(admin2);
        assertEq(factory.proposalCounter(), 1);

        vm.prank(admin1);
        factory.createAddAdminProposal(admin3);
        assertEq(factory.proposalCounter(), 2);
    }

    function testMultipleProposalsSequential() public {
        vm.prank(admin1);
        uint256 proposal1 = factory.createAddAdminProposal(admin2);

        vm.prank(admin1);
        uint256 proposal2 = factory.createAddAdminProposal(admin3);

        assertEq(proposal1, 1);
        assertEq(proposal2, 2);

        // Both should be executed
        (,,,, bool executed1,) = factory.getProposalDetails(proposal1);
        (,,,, bool executed2,) = factory.getProposalDetails(proposal2);
        assertTrue(executed1);
        assertFalse(executed2); // Second proposal requires voting since we now have 2 admins

        // Vote for second proposal
        vm.prank(admin2);
        factory.voteForProposal(proposal2);
        (,,,, executed2,) = factory.getProposalDetails(proposal2);
        assertTrue(executed2);
    }
}
