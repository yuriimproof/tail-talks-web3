// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {StarKeeperFactory} from "../../src/StarKeeperFactory.sol";
import {StarKeeper} from "../../src/StarKeeper.sol";
import {StarOwner} from "../../src/StarOwner.sol";
import {MockERC20} from "../mocks/ERC20Mock.sol";

contract StarKeeperFactoryIntegrationTest is Test {
    StarKeeperFactory public factory;
    StarOwner public starOwner;
    MockERC20 public mockToken;

    address public factoryAdmin1 = makeAddr("factoryAdmin1");
    address public factoryAdmin2 = makeAddr("factoryAdmin2");
    address public factoryAdmin3 = makeAddr("factoryAdmin3");

    address public starOwnerAdmin = makeAddr("starOwnerAdmin");
    address public creator = makeAddr("creator");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");

    uint256 public constant MAX_SUPPLY = 100;
    uint256 public constant MINT_PRICE = 0.01 ether;
    uint256 public constant TOKEN_MINT_PRICE = 1000 * 10 ** 18;
    string public constant BASE_TOKEN_URI = "https://api.example.com/metadata/";
    string public constant COLLECTION_IMAGE_URI = "ipfs://collection-image";

    string public constant IPFS_URI_1 = "ipfs://QmHash1";
    string public constant IPFS_URI_2 = "ipfs://QmHash2";

    function setUp() public {
        mockToken = new MockERC20();

        // Setup factory with initial admin
        address[] memory initialAdmins = new address[](1);
        initialAdmins[0] = factoryAdmin1;
        factory = new StarKeeperFactory(initialAdmins);

        // Setup standalone StarOwner contract
        vm.prank(starOwnerAdmin);
        starOwner = new StarOwner("Pet Collection", "PETS", MINT_PRICE, TOKEN_MINT_PRICE, address(mockToken));

        // Give users some ETH and tokens
        vm.deal(creator, 10 ether);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);

        mockToken.mint(user1, 10000 * 10 ** 18);
        mockToken.mint(user2, 10000 * 10 ** 18);
        mockToken.mint(user3, 10000 * 10 ** 18);
    }

    // ============ Factory Collection Creation Workflow ============

    function testCompleteFactoryCollectionWorkflow() public {
        // Step 1: Factory admin creates collection
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

        // Check proposal was auto-executed (single admin)
        (,,,, bool executed,) = factory.getProposalDetails(proposalId);
        assertTrue(executed);

        // Step 2: Verify collection was created
        StarKeeper[] memory collections = factory.getAllCollections();
        assertEq(collections.length, 1);

        StarKeeper collection = collections[0];
        assertTrue(factory.isCollectionFromFactory(address(collection)));

        // Step 3: Users mint NFTs from the collection
        vm.prank(user1);
        uint256 tokenId1 = collection.mint{value: MINT_PRICE}();

        vm.startPrank(user2);
        mockToken.approve(address(collection), TOKEN_MINT_PRICE);
        uint256 tokenId2 = collection.mintWithToken();
        vm.stopPrank();

        assertEq(tokenId1, 1);
        assertEq(tokenId2, 2);
        assertEq(collection.totalSupply(), 2);
        assertEq(collection.ownerOf(1), user1);
        assertEq(collection.ownerOf(2), user2);

        // Step 4: Factory admin manages collection
        vm.prank(factoryAdmin1);
        factory.createSetMintPriceProposal(address(collection), 0.02 ether);

        // Check price was updated
        assertEq(collection.mintPrice(), 0.02 ether);

        // Step 5: Admin mints to specific address
        vm.prank(factoryAdmin1);
        factory.createMintToProposal(address(collection), user3);

        assertEq(collection.totalSupply(), 3);
        assertEq(collection.ownerOf(3), user3);
    }

    // ============ StarKeeper Functionality Tests Through Factory ============

    function testStarKeeperMintingThroughFactory() public {
        // Create collection via factory
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Minting Test",
            "MINT",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper collection = factory.getAllCollections()[0];

        // Test ETH minting
        vm.prank(user1);
        uint256 tokenId1 = collection.mint{value: MINT_PRICE}();
        assertEq(tokenId1, 1);
        assertEq(collection.ownerOf(1), user1);
        assertEq(address(collection).balance, MINT_PRICE);

        // Test token minting
        vm.startPrank(user2);
        mockToken.approve(address(collection), TOKEN_MINT_PRICE);
        uint256 tokenId2 = collection.mintWithToken();
        vm.stopPrank();
        assertEq(tokenId2, 2);
        assertEq(collection.ownerOf(2), user2);
        assertEq(mockToken.balanceOf(address(collection)), TOKEN_MINT_PRICE);

        // Test admin minting
        vm.prank(factoryAdmin1);
        factory.createMintToProposal(address(collection), user3);
        assertEq(collection.totalSupply(), 3);
        assertEq(collection.ownerOf(3), user3);

        // Test sequential token IDs
        vm.prank(user1);
        uint256 tokenId4 = collection.mint{value: MINT_PRICE}();
        assertEq(tokenId4, 4);
    }

    function testStarKeeperCollectionManagement() public {
        // Create collection
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Management Test",
            "MGT",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper collection = factory.getAllCollections()[0];

        // Test price updates
        vm.prank(factoryAdmin1);
        factory.createSetMintPriceProposal(address(collection), 0.02 ether);
        assertEq(collection.mintPrice(), 0.02 ether);

        vm.prank(factoryAdmin1);
        factory.createSetTokenMintPriceProposal(address(collection), 2000 * 10 ** 18);
        assertEq(collection.tokenMintPrice(), 2000 * 10 ** 18);

        // Test payment token update
        address newToken = makeAddr("newToken");
        vm.prank(factoryAdmin1);
        factory.createSetPaymentTokenProposal(address(collection), newToken);
        assertEq(collection.paymentToken(), newToken);

        // Test max supply update
        vm.prank(factoryAdmin1);
        factory.createSetMaxSupplyProposal(address(collection), 200);
        assertEq(collection.maxSupply(), 200);

        // Test base URI update
        string memory newURI = "https://new-api.com/";
        vm.prank(factoryAdmin1);
        factory.createSetBaseURIProposal(address(collection), newURI);

        // Test collection image URI update
        string memory newImageURI = "ipfs://new-image";
        vm.prank(factoryAdmin1);
        factory.createSetImageURIProposal(address(collection), newImageURI);
        assertEq(collection.collectionImageURI(), newImageURI);
    }

    function testStarKeeperWithdrawals() public {
        // Create collection and accumulate funds
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Withdrawal Test",
            "WDL",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper collection = factory.getAllCollections()[0];

        // Users mint to accumulate funds
        vm.prank(user1);
        collection.mint{value: MINT_PRICE}();
        vm.prank(user2);
        collection.mint{value: MINT_PRICE}();

        vm.startPrank(user3);
        mockToken.approve(address(collection), TOKEN_MINT_PRICE);
        collection.mintWithToken();
        vm.stopPrank();

        // Test ETH withdrawal
        uint256 adminBalanceBefore = factoryAdmin1.balance;
        vm.prank(factoryAdmin1);
        factory.createWithdrawFundsProposal(address(collection), factoryAdmin1, 0); // 0 means all

        assertEq(factoryAdmin1.balance, adminBalanceBefore + (2 * MINT_PRICE));
        assertEq(address(collection).balance, 0);

        // Test token withdrawal
        uint256 adminTokenBalanceBefore = mockToken.balanceOf(factoryAdmin1);
        vm.prank(factoryAdmin1);
        factory.createWithdrawTokensProposal(address(collection), factoryAdmin1);

        assertEq(mockToken.balanceOf(factoryAdmin1), adminTokenBalanceBefore + TOKEN_MINT_PRICE);
        assertEq(mockToken.balanceOf(address(collection)), 0);
    }

    function testStarKeeperErrorCases() public {
        // Create collection
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Error Test",
            "ERR",
            2,
            MINT_PRICE,
            TOKEN_MINT_PRICE, // Small max supply
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper collection = factory.getAllCollections()[0];

        // Test max supply reached
        vm.prank(user1);
        collection.mint{value: MINT_PRICE}();
        vm.prank(user2);
        collection.mint{value: MINT_PRICE}();

        // Third mint should fail
        vm.expectRevert(StarKeeper.MaxSupplyReached.selector);
        vm.prank(user3);
        collection.mint{value: MINT_PRICE}();

        // Test insufficient payment
        vm.expectRevert(StarKeeper.InsufficientPayment.selector);
        vm.prank(user3);
        collection.mint{value: MINT_PRICE - 1}();

        // Test admin can increase max supply to fix the issue
        vm.prank(factoryAdmin1);
        factory.createSetMaxSupplyProposal(address(collection), 5);

        // Now minting should work
        vm.prank(user3);
        collection.mint{value: MINT_PRICE}();
        assertEq(collection.totalSupply(), 3);
    }

    function testStarKeeperViewFunctions() public {
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "View Test",
            "VIEW",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper collection = factory.getAllCollections()[0];

        // Test initial state
        assertEq(collection.getCurrentSupply(), 0);

        // Test after minting
        vm.prank(user1);
        collection.mint{value: MINT_PRICE}();

        assertEq(collection.getCurrentSupply(), 1);
        assertEq(collection.totalSupply(), 1);

        // Test collection info
        (
            string memory name_,
            string memory symbol_,
            uint256 totalSupply_,
            uint256 maxSupply_,
            uint256 mintPrice_,
            uint256 tokenMintPrice_,
            address paymentToken_
        ) = collection.getCollectionInfo();

        assertEq(name_, "View Test");
        assertEq(symbol_, "VIEW");
        assertEq(totalSupply_, 1);
        assertEq(maxSupply_, MAX_SUPPLY);
        assertEq(mintPrice_, MINT_PRICE);
        assertEq(tokenMintPrice_, TOKEN_MINT_PRICE);
        assertEq(paymentToken_, address(mockToken));

        // Test token URI
        string memory tokenURI = collection.tokenURI(1);
        assertEq(tokenURI, BASE_TOKEN_URI);

        // Test invalid token URI
        vm.expectRevert(StarKeeper.TokenDoesNotExist.selector);
        collection.tokenURI(999);
    }

    // ============ Multi-Admin Factory Governance ============

    function testMultiAdminFactoryGovernance() public {
        // Add more admins to factory
        vm.prank(factoryAdmin1);
        factory.createAddAdminProposal(factoryAdmin2);

        vm.prank(factoryAdmin1);
        uint256 addAdmin3Proposal = factory.createAddAdminProposal(factoryAdmin3);

        // Vote for adding admin3
        vm.prank(factoryAdmin2);
        factory.voteForProposal(addAdmin3Proposal);

        // Verify we now have 3 admins with quorum = 3
        address[] memory admins = factory.getAdmins();
        assertEq(admins.length, 3);
        assertEq(factory.quorumThreshold(), 3);

        // Create collection proposal requiring votes
        vm.prank(factoryAdmin1);
        uint256 proposalId = factory.createCollectionProposal(
            "Multi Admin Collection",
            "MAC",
            50,
            0.005 ether,
            500 * 10 ** 18,
            address(mockToken),
            "https://multi-admin.com/",
            "ipfs://multi-admin-image"
        );

        // Should not be executed yet
        (,, uint256 approvalCount,, bool executed,) = factory.getProposalDetails(proposalId);
        assertEq(approvalCount, 1);
        assertFalse(executed);

        // Other admins vote
        vm.prank(factoryAdmin2);
        factory.voteForProposal(proposalId);

        (,, approvalCount,, executed,) = factory.getProposalDetails(proposalId);
        assertEq(approvalCount, 2);
        assertFalse(executed);

        vm.prank(factoryAdmin3);
        factory.voteForProposal(proposalId);

        // Now should be executed
        (,, approvalCount,, executed,) = factory.getProposalDetails(proposalId);
        assertEq(approvalCount, 3);
        assertTrue(executed);

        // Verify collection was created
        StarKeeper[] memory collections = factory.getAllCollections();
        assertEq(collections.length, 1);
        assertEq(collections[0].name(), "Multi Admin Collection");
    }

    function testComplexMultiAdminScenarios() public {
        // Setup multi-admin factory
        vm.prank(factoryAdmin1);
        factory.createAddAdminProposal(factoryAdmin2);
        vm.prank(factoryAdmin1);
        uint256 addAdmin3 = factory.createAddAdminProposal(factoryAdmin3);
        vm.prank(factoryAdmin2);
        factory.voteForProposal(addAdmin3);

        // Create multiple collections
        vm.prank(factoryAdmin1);
        uint256 proposal1 = factory.createCollectionProposal(
            "Collection 1", "C1", 50, 0.01 ether, 1000 * 10 ** 18, address(mockToken), "https://c1.com/", "ipfs://c1"
        );
        vm.prank(factoryAdmin2);
        factory.voteForProposal(proposal1);
        vm.prank(factoryAdmin3);
        factory.voteForProposal(proposal1);

        vm.prank(factoryAdmin1);
        uint256 proposal2 = factory.createCollectionProposal(
            "Collection 2", "C2", 75, 0.015 ether, 1500 * 10 ** 18, address(mockToken), "https://c2.com/", "ipfs://c2"
        );
        vm.prank(factoryAdmin2);
        factory.voteForProposal(proposal2);
        vm.prank(factoryAdmin3);
        factory.voteForProposal(proposal2);

        StarKeeper[] memory collections = factory.getAllCollections();
        assertEq(collections.length, 2);

        StarKeeper collection1 = collections[0];
        StarKeeper collection2 = collections[1];

        // Users interact with different collections
        vm.prank(user1);
        collection1.mint{value: 0.01 ether}();

        vm.prank(user2);
        collection2.mint{value: 0.015 ether}();

        vm.startPrank(user3);
        mockToken.approve(address(collection1), 1000 * 10 ** 18);
        collection1.mintWithToken();
        vm.stopPrank();

        // Verify states
        assertEq(collection1.totalSupply(), 2);
        assertEq(collection2.totalSupply(), 1);
        assertEq(collection1.ownerOf(1), user1);
        assertEq(collection1.ownerOf(2), user3);
        assertEq(collection2.ownerOf(1), user2);

        // Simultaneous governance proposals
        vm.prank(factoryAdmin1);
        uint256 priceProposal1 = factory.createSetMintPriceProposal(address(collection1), 0.02 ether);

        vm.prank(factoryAdmin2);
        uint256 priceProposal2 = factory.createSetMintPriceProposal(address(collection2), 0.025 ether);

        // Vote on different proposals
        vm.prank(factoryAdmin2);
        factory.voteForProposal(priceProposal1);
        vm.prank(factoryAdmin1);
        factory.voteForProposal(priceProposal2);

        vm.prank(factoryAdmin3);
        factory.voteForProposal(priceProposal1);
        vm.prank(factoryAdmin3);
        factory.voteForProposal(priceProposal2);

        // Verify both executed
        assertEq(collection1.mintPrice(), 0.02 ether);
        assertEq(collection2.mintPrice(), 0.025 ether);
    }

    // ============ Factory and StarOwner Integration ============

    function testFactoryAndStarOwnerCoexistence() public {
        // Create factory collection
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Factory Collection",
            "FC",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper[] memory collections = factory.getAllCollections();
        StarKeeper factoryCollection = collections[0];

        // Mint from both factory collection and standalone StarOwner
        vm.prank(user1);
        uint256 factoryTokenId = factoryCollection.mint{value: MINT_PRICE}();

        vm.prank(user2);
        uint256 starOwnerTokenId = starOwner.mint{value: MINT_PRICE}(IPFS_URI_1);

        // Verify both work independently
        assertEq(factoryTokenId, 1);
        assertEq(starOwnerTokenId, 1);
        assertEq(factoryCollection.ownerOf(1), user1);
        assertEq(starOwner.ownerOf(1), user2);

        // Different token URIs
        assertEq(factoryCollection.tokenURI(1), BASE_TOKEN_URI);
        assertEq(starOwner.tokenURI(1), IPFS_URI_1);

        // Both have different admin systems
        bytes32 adminRole = keccak256("ADMIN_ROLE");
        assertTrue(factory.hasRole(adminRole, factoryAdmin1));
        assertTrue(starOwner.hasRole(adminRole, starOwnerAdmin));

        // Factory manages factory collection
        vm.prank(factoryAdmin1);
        factory.createSetMintPriceProposal(address(factoryCollection), 0.02 ether);
        assertEq(factoryCollection.mintPrice(), 0.02 ether);
        assertEq(starOwner.mintPrice(), MINT_PRICE); // Unchanged

        // StarOwner manages itself
        vm.prank(starOwnerAdmin);
        starOwner.createSetMintPriceProposal(0.03 ether);
        assertEq(starOwner.mintPrice(), 0.03 ether);
        assertEq(factoryCollection.mintPrice(), 0.02 ether); // Unchanged
    }

    function testCrossContractWorkflows() public {
        // Factory admin creates a collection for art pieces
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Art Collection",
            "ART",
            50,
            0.05 ether,
            5000 * 10 ** 18,
            address(mockToken),
            "https://art.api/",
            "ipfs://art-image"
        );

        StarKeeper artCollection = factory.getAllCollections()[0];

        // Users mint from both platforms
        vm.prank(user1);
        uint256 artTokenId = artCollection.mint{value: 0.05 ether}();

        vm.prank(user1);
        uint256 petTokenId = starOwner.mint{value: MINT_PRICE}(IPFS_URI_1);

        // User can own NFTs from both systems
        assertEq(artCollection.ownerOf(artTokenId), user1);
        assertEq(starOwner.ownerOf(petTokenId), user1);

        // Different pricing and features
        assertEq(artCollection.mintPrice(), 0.05 ether);
        assertEq(starOwner.mintPrice(), MINT_PRICE);

        // Factory can create multiple specialized collections
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Music Collection",
            "MUSIC",
            100,
            0.02 ether,
            2000 * 10 ** 18,
            address(mockToken),
            "https://music.api/",
            "ipfs://music-image"
        );

        StarKeeper musicCollection = factory.getAllCollections()[1];

        // Different collections have different properties
        assertEq(artCollection.maxSupply(), 50);
        assertEq(musicCollection.maxSupply(), 100);
        assertEq(artCollection.mintPrice(), 0.05 ether);
        assertEq(musicCollection.mintPrice(), 0.02 ether);
    }

    // ============ Event Testing ============

    function testComprehensiveEventEmission() public {
        // Test factory events
        vm.expectEmit(true, false, false, true);
        emit StarKeeperFactory.ProposalCreated(1, StarKeeperFactory.FunctionType.CreateCollection, factoryAdmin1);

        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Event Test",
            "EVT",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper collection = factory.getAllCollections()[0];

        // Test collection events
        vm.expectEmit(true, true, false, true);
        emit StarKeeper.Minted(user1, 1, "ETH");

        vm.prank(user1);
        collection.mint{value: MINT_PRICE}();

        // Test StarOwner events
        vm.expectEmit(true, true, false, true);
        emit StarOwner.TokenMinted(user2, 1, "ETH");

        vm.prank(user2);
        starOwner.mint{value: MINT_PRICE}(IPFS_URI_1);
    }

    // ============ Gas Optimization Tests ============

    function testGasEfficiencyComparison() public {
        // Single admin factory operations (auto-execute)
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Gas Test",
            "GAS",
            10,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        // Store collection address for later use
        StarKeeper[] memory collections = factory.getAllCollections();
        address collectionAddress = address(collections[0]);

        // Add more admins
        vm.prank(factoryAdmin1);
        factory.createAddAdminProposal(factoryAdmin2);
        vm.prank(factoryAdmin1);
        uint256 addAdmin3 = factory.createAddAdminProposal(factoryAdmin3);
        vm.prank(factoryAdmin2);
        factory.voteForProposal(addAdmin3);

        // Verify we have 3 admins now
        assertEq(factory.getAdmins().length, 3);
        assertEq(factory.quorumThreshold(), 3);

        // Debug: Check admin status before making the call
        assertTrue(factory.hasRole(keccak256("ADMIN_ROLE"), factoryAdmin1));
        assertTrue(factory.hasRole(keccak256("ADMIN_ROLE"), factoryAdmin2));
        assertTrue(factory.hasRole(keccak256("ADMIN_ROLE"), factoryAdmin3));

        // Test multi-admin operations (requires voting)
        vm.prank(factoryAdmin1);
        uint256 proposalId = factory.createSetMintPriceProposal(collectionAddress, 0.02 ether);

        // Check proposal was created but not executed yet
        (,, uint256 approvalCount,, bool executed,) = factory.getProposalDetails(proposalId);
        assertEq(approvalCount, 1);
        assertFalse(executed);

        vm.prank(factoryAdmin2);
        factory.voteForProposal(proposalId);

        // Still not executed
        (,, approvalCount,, executed,) = factory.getProposalDetails(proposalId);
        assertEq(approvalCount, 2);
        assertFalse(executed);

        vm.prank(factoryAdmin3);
        factory.voteForProposal(proposalId);

        // Now should be executed
        (,, approvalCount,, executed,) = factory.getProposalDetails(proposalId);
        assertEq(approvalCount, 3);
        assertTrue(executed);

        // Verify the price was updated
        assertEq(StarKeeper(collectionAddress).mintPrice(), 0.02 ether);

        // Test that single admin operations are faster than multi-admin operations
        // by creating another collection with single admin vs multi-admin scenarios

        // Reset to single admin for comparison - need 3 votes for removal since we have 3 admins
        vm.prank(factoryAdmin1);
        uint256 removeAdmin2 = factory.createRemoveAdminProposal(factoryAdmin2);
        vm.prank(factoryAdmin2);
        factory.voteForProposal(removeAdmin2);
        vm.prank(factoryAdmin3);
        factory.voteForProposal(removeAdmin2);

        // Now we have 2 admins with quorum threshold 2
        assertEq(factory.getAdmins().length, 2);
        assertEq(factory.quorumThreshold(), 2);

        vm.prank(factoryAdmin1);
        uint256 removeAdmin3 = factory.createRemoveAdminProposal(factoryAdmin3);
        vm.prank(factoryAdmin3);
        factory.voteForProposal(removeAdmin3);

        // Now back to single admin - operations should auto-execute
        assertEq(factory.getAdmins().length, 1);
        assertEq(factory.quorumThreshold(), 1);

        // Single admin operation should auto-execute
        vm.prank(factoryAdmin1);
        factory.createSetMintPriceProposal(collectionAddress, 0.03 ether);

        // Should be updated immediately
        assertEq(StarKeeper(collectionAddress).mintPrice(), 0.03 ether);
    }

    // ============ Edge Cases and Recovery Scenarios ============

    function testRecoveryFromMaxSupplyReached() public {
        // Create collection with small max supply
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Small Collection",
            "SMALL",
            2,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper collection = factory.getAllCollections()[0];

        // Reach max supply
        vm.prank(factoryAdmin1);
        factory.createMintToProposal(address(collection), user1);
        vm.prank(factoryAdmin1);
        factory.createMintToProposal(address(collection), user2);

        assertEq(collection.totalSupply(), 2);

        // Try to mint more - should fail
        vm.expectRevert(StarKeeper.MaxSupplyReached.selector);
        vm.prank(user3);
        collection.mint{value: MINT_PRICE}();

        // Admin can increase max supply
        vm.prank(factoryAdmin1);
        factory.createSetMaxSupplyProposal(address(collection), 5);

        assertEq(collection.maxSupply(), 5);

        // Now minting should work again
        vm.prank(user3);
        collection.mint{value: MINT_PRICE}();

        assertEq(collection.totalSupply(), 3);
        assertEq(collection.ownerOf(3), user3);
    }

    function testProposalExpirationScenarios() public {
        // Add another admin to enable voting
        vm.prank(factoryAdmin1);
        factory.createAddAdminProposal(factoryAdmin2);

        // Create collection - this will require voting since we have 2 admins now
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

        // Vote for collection creation
        vm.prank(factoryAdmin2);
        factory.voteForProposal(collectionProposal);

        StarKeeper collection = factory.getAllCollections()[0];

        // Create proposal that will expire
        vm.prank(factoryAdmin1);
        uint256 proposalId = factory.createSetMintPriceProposal(address(collection), 0.02 ether);

        // Fast forward past expiration
        vm.warp(block.timestamp + 8 days);

        // Voting should fail
        vm.expectRevert(StarKeeperFactory.ProposalExpired.selector);
        vm.prank(factoryAdmin2);
        factory.voteForProposal(proposalId);

        // But proposal details should still be readable
        (address proposer,,,, bool executed, StarKeeperFactory.FunctionType funcType) =
            factory.getProposalDetails(proposalId);
        assertEq(proposer, factoryAdmin1);
        assertEq(uint256(funcType), uint256(StarKeeperFactory.FunctionType.SetMintPrice));
        assertFalse(executed);

        // Collection price should remain unchanged
        assertEq(collection.mintPrice(), MINT_PRICE);
    }

    // ============ Comprehensive Integration Scenarios ============

    function testFullPlatformWorkflow() public {
        // Step 1: Setup multi-admin factory
        vm.prank(factoryAdmin1);
        factory.createAddAdminProposal(factoryAdmin2);

        // Step 2: Create different types of collections
        vm.prank(factoryAdmin1);
        uint256 artProposal = factory.createCollectionProposal(
            "Digital Art", "ART", 100, 0.1 ether, 10000 * 10 ** 18, address(mockToken), "https://art.api/", "ipfs://art"
        );

        vm.prank(factoryAdmin2);
        factory.voteForProposal(artProposal);

        vm.prank(factoryAdmin1);
        uint256 gameProposal = factory.createCollectionProposal(
            "Game Items",
            "GAME",
            1000,
            0.01 ether,
            1000 * 10 ** 18,
            address(mockToken),
            "https://game.api/",
            "ipfs://game"
        );

        vm.prank(factoryAdmin2);
        factory.voteForProposal(gameProposal);

        StarKeeper[] memory collections = factory.getAllCollections();
        StarKeeper artCollection = collections[0];
        StarKeeper gameCollection = collections[1];

        // Step 3: Users interact with different platforms
        // High-value art minting
        vm.prank(user1);
        artCollection.mint{value: 0.1 ether}();

        // Game items minting
        vm.prank(user1);
        gameCollection.mint{value: 0.01 ether}();

        // Pet photos on StarOwner
        vm.prank(user1);
        starOwner.mint{value: MINT_PRICE}(IPFS_URI_1);

        // Step 4: Verify user owns different types of NFTs
        assertEq(artCollection.ownerOf(1), user1);
        assertEq(gameCollection.ownerOf(1), user1);
        assertEq(starOwner.ownerOf(1), user1);

        // Step 5: Different governance for different platforms
        // Factory manages collections
        vm.prank(factoryAdmin1);
        uint256 artPriceUpdate = factory.createSetMintPriceProposal(address(artCollection), 0.15 ether);
        vm.prank(factoryAdmin2);
        factory.voteForProposal(artPriceUpdate);

        // StarOwner self-governs
        vm.prank(starOwnerAdmin);
        starOwner.createSetMintPriceProposal(0.02 ether);

        // Step 6: Verify different platforms maintain independence
        assertEq(artCollection.mintPrice(), 0.15 ether);
        assertEq(gameCollection.mintPrice(), 0.01 ether); // Unchanged
        assertEq(starOwner.mintPrice(), 0.02 ether);
    }

    // ============ Access Control and Security Tests ============

    function testFactoryAccessControl() public {
        // Non-admin cannot create proposals
        vm.expectRevert();
        vm.prank(user1);
        factory.createCollectionProposal(
            "Unauthorized",
            "UNAUTH",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        // Create collection with admin
        vm.prank(factoryAdmin1);
        factory.createCollectionProposal(
            "Authorized",
            "AUTH",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        StarKeeper collection = factory.getAllCollections()[0];

        // Users can mint from collection (no access control for minting)
        vm.prank(user1);
        collection.mint{value: MINT_PRICE}();

        // But users cannot directly call factory-only functions on collection
        vm.expectRevert(StarKeeper.OnlyFactoryAllowed.selector);
        vm.prank(user1);
        collection.setMintPrice(0.02 ether);

        // Only factory can call these functions
        vm.prank(factoryAdmin1);
        factory.createSetMintPriceProposal(address(collection), 0.02 ether);
        assertEq(collection.mintPrice(), 0.02 ether);
    }
}
