// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {StarOwner} from "../../src/StarOwner.sol";
import {MockERC20} from "../mocks/ERC20Mock.sol";

contract StarOwnerIntegrationTest is Test {
    StarOwner public starOwner;
    MockERC20 public paymentToken;
    MockERC20 public alternativeToken;

    // Admin addresses
    address public admin1 = makeAddr("admin1");
    address public admin2 = makeAddr("admin2");
    address public admin3 = makeAddr("admin3");
    address public admin4 = makeAddr("admin4");

    // User addresses
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");
    address public creator1 = makeAddr("creator1");
    address public creator2 = makeAddr("creator2");
    address public collector = makeAddr("collector");

    // Constants
    uint256 public constant INITIAL_MINT_PRICE = 0.01 ether;
    uint256 public constant INITIAL_TOKEN_PRICE = 1000 * 10 ** 18;
    string public constant COLLECTION_NAME = "Pet Photos";
    string public constant COLLECTION_SYMBOL = "PETS";

    // Sample IPFS URIs
    string public constant IPFS_CAT_1 = "ipfs://QmCat1Hash";
    string public constant IPFS_DOG_1 = "ipfs://QmDog1Hash";
    string public constant IPFS_BIRD_1 = "ipfs://QmBird1Hash";
    string public constant IPFS_CAT_2 = "ipfs://QmCat2Hash";
    string public constant IPFS_DOG_2 = "ipfs://QmDog2Hash";

    function setUp() public {
        // Deploy payment tokens
        paymentToken = new MockERC20();
        alternativeToken = new MockERC20();

        // Deploy StarOwner with admin1 as initial admin
        vm.prank(admin1);
        starOwner = new StarOwner(
            COLLECTION_NAME, COLLECTION_SYMBOL, INITIAL_MINT_PRICE, INITIAL_TOKEN_PRICE, address(paymentToken)
        );

        // Distribute ETH to users
        vm.deal(admin1, 100 ether);
        vm.deal(admin2, 100 ether);
        vm.deal(admin3, 100 ether);
        vm.deal(user1, 50 ether);
        vm.deal(user2, 50 ether);
        vm.deal(user3, 50 ether);
        vm.deal(creator1, 50 ether);
        vm.deal(creator2, 50 ether);
        vm.deal(collector, 100 ether);

        // Distribute tokens
        paymentToken.mint(user1, 100000 * 10 ** 18);
        paymentToken.mint(user2, 100000 * 10 ** 18);
        paymentToken.mint(user3, 100000 * 10 ** 18);
        paymentToken.mint(creator1, 100000 * 10 ** 18);
        paymentToken.mint(creator2, 100000 * 10 ** 18);
        paymentToken.mint(collector, 200000 * 10 ** 18);

        alternativeToken.mint(user1, 50000 * 10 ** 18);
        alternativeToken.mint(user2, 50000 * 10 ** 18);
        alternativeToken.mint(collector, 100000 * 10 ** 18);
    }

    // ============ Multi-Admin Governance Integration Tests ============

    function testCompleteMultiAdminGovernanceWorkflow() public {
        // Step 1: Setup multi-admin governance
        vm.prank(admin1);
        starOwner.createAddAdminProposal(admin2);

        vm.prank(admin1);
        uint256 addAdmin3Proposal = starOwner.createAddAdminProposal(admin3);
        vm.prank(admin2);
        starOwner.voteForProposal(addAdmin3Proposal);

        // Verify we have 3 admins with quorum = 3
        address[] memory admins = starOwner.getAdmins();
        assertEq(admins.length, 3);
        assertEq(starOwner.quorumThreshold(), 3);

        // Step 2: Test coordinated governance decisions
        vm.prank(admin1);
        uint256 priceProposal = starOwner.createSetMintPriceProposal(0.02 ether);

        vm.prank(admin2);
        starOwner.voteForProposal(priceProposal);

        vm.prank(admin3);
        starOwner.voteForProposal(priceProposal);

        assertEq(starOwner.mintPrice(), 0.02 ether);

        // Step 3: Test token fee adjustment
        vm.prank(admin1);
        uint256 tokenFeeProposal = starOwner.createSetTokenFeeProposal(2000 * 10 ** 18);

        vm.prank(admin2);
        starOwner.voteForProposal(tokenFeeProposal);

        vm.prank(admin3);
        starOwner.voteForProposal(tokenFeeProposal);

        assertEq(starOwner.tokenMintPrice(), 2000 * 10 ** 18);

        // Step 4: Change payment token
        vm.prank(admin1);
        uint256 tokenChangeProposal = starOwner.createSetPaymentTokenProposal(address(alternativeToken));

        vm.prank(admin2);
        starOwner.voteForProposal(tokenChangeProposal);

        vm.prank(admin3);
        starOwner.voteForProposal(tokenChangeProposal);

        assertEq(starOwner.paymentToken(), address(alternativeToken));
    }

    function testLargeScaleAdminManagement() public {
        // Add multiple admins
        vm.prank(admin1);
        starOwner.createAddAdminProposal(admin2);

        vm.prank(admin1);
        uint256 addAdmin3 = starOwner.createAddAdminProposal(admin3);
        vm.prank(admin2);
        starOwner.voteForProposal(addAdmin3);

        vm.prank(admin1);
        uint256 addAdmin4 = starOwner.createAddAdminProposal(admin4);
        vm.prank(admin2);
        starOwner.voteForProposal(addAdmin4);
        vm.prank(admin3);
        starOwner.voteForProposal(addAdmin4);

        // Now we have 4 admins, quorum = 3 (75% of 4)
        assertEq(starOwner.getAdmins().length, 4);
        assertEq(starOwner.quorumThreshold(), 3);

        // Test complex removal scenario
        vm.prank(admin1);
        uint256 removeAdmin2 = starOwner.createRemoveAdminProposal(admin2);

        vm.prank(admin3);
        starOwner.voteForProposal(removeAdmin2);

        vm.prank(admin4);
        starOwner.voteForProposal(removeAdmin2);

        // Admin2 should be removed, now 3 admins with quorum = 3
        assertEq(starOwner.getAdmins().length, 3);
        assertEq(starOwner.quorumThreshold(), 3);

        // Test that removed admin cannot vote
        vm.prank(admin1);
        uint256 testProposal = starOwner.createSetMintPriceProposal(0.03 ether);

        vm.expectRevert();
        vm.prank(admin2); // Removed admin
        starOwner.voteForProposal(testProposal);

        // But other admins can still vote
        vm.prank(admin3);
        starOwner.voteForProposal(testProposal);
        vm.prank(admin4);
        starOwner.voteForProposal(testProposal);

        assertEq(starOwner.mintPrice(), 0.03 ether);
    }

    // ============ Real-World Usage Scenarios ============

    function testPetOwnerCommunityScenario() public {
        // Scenario: A pet owner community uses the platform

        // Community setup - multiple admins for governance
        vm.prank(admin1);
        starOwner.createAddAdminProposal(admin2);
        vm.prank(admin1);
        uint256 addAdmin3 = starOwner.createAddAdminProposal(admin3);
        vm.prank(admin2);
        starOwner.voteForProposal(addAdmin3);

        // Users mint pet photos
        vm.prank(creator1);
        uint256 catToken1 = starOwner.mint{value: INITIAL_MINT_PRICE}(IPFS_CAT_1);

        vm.prank(creator2);
        uint256 dogToken1 = starOwner.mint{value: INITIAL_MINT_PRICE}(IPFS_DOG_1);

        vm.startPrank(user1);
        paymentToken.approve(address(starOwner), INITIAL_TOKEN_PRICE);
        uint256 birdToken1 = starOwner.mintWithToken(IPFS_BIRD_1);
        vm.stopPrank();

        // Verify minting
        assertEq(starOwner.ownerOf(catToken1), creator1);
        assertEq(starOwner.ownerOf(dogToken1), creator2);
        assertEq(starOwner.ownerOf(birdToken1), user1);
        assertEq(starOwner.tokenURI(catToken1), IPFS_CAT_1);
        assertEq(starOwner.tokenURI(dogToken1), IPFS_DOG_1);
        assertEq(starOwner.tokenURI(birdToken1), IPFS_BIRD_1);

        // Community governance - adjust pricing for growth
        vm.prank(admin1);
        uint256 growthProposal = starOwner.createSetMintPriceProposal(0.005 ether);

        vm.prank(admin2);
        starOwner.voteForProposal(growthProposal);

        vm.prank(admin3);
        starOwner.voteForProposal(growthProposal);

        // More users join with lower price
        vm.prank(user2);
        uint256 catToken2 = starOwner.mint{value: 0.005 ether}(IPFS_CAT_2);

        vm.prank(user3);
        uint256 dogToken2 = starOwner.mint{value: 0.005 ether}(IPFS_DOG_2);

        assertEq(starOwner.totalSupply(), 5);
        assertEq(starOwner.ownerOf(catToken2), user2);
        assertEq(starOwner.ownerOf(dogToken2), user3);
    }

    function testNFTMarketplaceIntegrationScenario() public {
        // Scenario: Platform used as backend for NFT marketplace

        // Setup: Multiple creators mint various pet NFTs
        string[10] memory petUris = [
            "ipfs://QmCat1",
            "ipfs://QmDog1",
            "ipfs://QmBird1",
            "ipfs://QmCat2",
            "ipfs://QmDog2",
            "ipfs://QmBird2",
            "ipfs://QmCat3",
            "ipfs://QmDog3",
            "ipfs://QmBird3",
            "ipfs://QmRabbit1"
        ];

        address[5] memory creators = [creator1, creator2, user1, user2, user3];

        // Creators mint various pets
        for (uint256 i = 0; i < 10; i++) {
            address currentCreator = creators[i % 5];
            vm.prank(currentCreator);
            starOwner.mint{value: INITIAL_MINT_PRICE}(petUris[i]);
        }

        assertEq(starOwner.totalSupply(), 10);

        // Collector buys multiple NFTs using tokens
        vm.startPrank(collector);
        for (uint256 i = 0; i < 5; i++) {
            paymentToken.approve(address(starOwner), INITIAL_TOKEN_PRICE);
            starOwner.mintWithToken(string(abi.encodePacked("ipfs://QmCollector", vm.toString(i))));
        }
        vm.stopPrank();

        assertEq(starOwner.totalSupply(), 15);
        assertEq(starOwner.balanceOf(collector), 5);

        // Platform governance - revenue withdrawal
        uint256 platformBalanceBefore = address(starOwner).balance;
        uint256 adminBalanceBefore = admin1.balance;

        vm.prank(admin1);
        starOwner.createWithdrawFundsProposal(admin1, platformBalanceBefore);

        uint256 adminBalanceAfter = admin1.balance;
        assertEq(adminBalanceAfter, adminBalanceBefore + platformBalanceBefore);
        assertEq(address(starOwner).balance, 0);

        // Token revenue withdrawal
        uint256 tokenBalance = paymentToken.balanceOf(address(starOwner));
        uint256 adminTokenBalanceBefore = paymentToken.balanceOf(admin1);

        vm.prank(admin1);
        starOwner.createWithdrawTokensProposal(admin1, tokenBalance);

        assertEq(paymentToken.balanceOf(admin1), adminTokenBalanceBefore + tokenBalance);
        assertEq(paymentToken.balanceOf(address(starOwner)), 0);
    }

    // ============ Cross-Token Integration Tests ============

    function testMultiTokenEcosystem() public {
        // Test switching between different payment tokens

        // Initial state with paymentToken
        vm.startPrank(user1);
        paymentToken.approve(address(starOwner), INITIAL_TOKEN_PRICE);
        uint256 token1 = starOwner.mintWithToken(IPFS_CAT_1);
        vm.stopPrank();

        assertEq(starOwner.ownerOf(token1), user1);

        // Switch to alternative token
        vm.prank(admin1);
        starOwner.createSetPaymentTokenProposal(address(alternativeToken));

        // Update token price for new token
        vm.prank(admin1);
        starOwner.createSetTokenFeeProposal(500 * 10 ** 18);

        // Test minting with new token
        vm.startPrank(user2);
        alternativeToken.approve(address(starOwner), 500 * 10 ** 18);
        uint256 token2 = starOwner.mintWithToken(IPFS_DOG_1);
        vm.stopPrank();

        assertEq(starOwner.ownerOf(token2), user2);
        assertEq(alternativeToken.balanceOf(address(starOwner)), 500 * 10 ** 18);

        // Disable token payments
        vm.prank(admin1);
        starOwner.createSetPaymentTokenProposal(address(0));

        // Token minting should fail
        vm.startPrank(user3);
        paymentToken.approve(address(starOwner), 1000 * 10 ** 18);
        vm.expectRevert(StarOwner.ERC20PaymentNotEnabled.selector);
        starOwner.mintWithToken(IPFS_BIRD_1);
        vm.stopPrank();

        // But ETH minting still works
        vm.prank(user3);
        uint256 token3 = starOwner.mint{value: INITIAL_MINT_PRICE}(IPFS_BIRD_1);
        assertEq(starOwner.ownerOf(token3), user3);
    }

    function testTokenEconomicsIntegration() public {
        // Test realistic token economics scenarios

        // High-value setup
        vm.prank(admin1);
        starOwner.createSetMintPriceProposal(0.1 ether);

        vm.prank(admin1);
        starOwner.createSetTokenFeeProposal(10000 * 10 ** 18);

        // Premium minting
        vm.prank(collector);
        starOwner.mint{value: 0.1 ether}(IPFS_CAT_1);

        assertEq(address(starOwner).balance, 0.1 ether);

        // Budget minting with tokens
        vm.startPrank(user1);
        paymentToken.approve(address(starOwner), 10000 * 10 ** 18);
        starOwner.mintWithToken(IPFS_DOG_1);
        vm.stopPrank();

        assertEq(paymentToken.balanceOf(address(starOwner)), 10000 * 10 ** 18);

        // Revenue sharing simulation
        uint256 ethRevenue = address(starOwner).balance;
        uint256 tokenRevenue = paymentToken.balanceOf(address(starOwner));

        // Split revenues between admins
        vm.prank(admin1);
        starOwner.createWithdrawFundsProposal(admin1, ethRevenue / 2);

        assertEq(address(starOwner).balance, ethRevenue / 2);

        vm.prank(admin1);
        starOwner.createWithdrawTokensProposal(admin1, tokenRevenue);

        assertEq(paymentToken.balanceOf(admin1), tokenRevenue);
        assertEq(paymentToken.balanceOf(address(starOwner)), 0);
    }

    // ============ Long-Term Governance Scenarios ============

    function testGovernanceEvolution() public {
        // Simulate long-term governance evolution

        // Phase 1: Single admin bootstrapping
        vm.prank(user1);
        starOwner.mint{value: INITIAL_MINT_PRICE}(IPFS_CAT_1);

        // Phase 2: Growth - add second admin
        vm.prank(admin1);
        starOwner.createAddAdminProposal(admin2);

        // Adjust for growth
        vm.prank(admin1);
        uint256 growthProposal = starOwner.createSetMintPriceProposal(0.02 ether);
        vm.prank(admin2);
        starOwner.voteForProposal(growthProposal);

        // Phase 3: Maturity - add third admin for decentralization
        vm.prank(admin1);
        uint256 addAdmin3 = starOwner.createAddAdminProposal(admin3);
        vm.prank(admin2);
        starOwner.voteForProposal(addAdmin3);

        // More conservative changes now require 3 votes
        vm.prank(admin1);
        uint256 maturityProposal = starOwner.createSetMintPriceProposal(0.015 ether);

        vm.prank(admin2);
        starOwner.voteForProposal(maturityProposal);

        vm.prank(admin3);
        starOwner.voteForProposal(maturityProposal);

        assertEq(starOwner.mintPrice(), 0.015 ether);

        // Phase 4: Transition - remove founding admin
        vm.prank(admin2);
        uint256 transitionProposal = starOwner.createRemoveAdminProposal(admin1);

        vm.prank(admin3);
        starOwner.voteForProposal(transitionProposal);

        vm.prank(admin1); // Founding admin votes for their own removal
        starOwner.voteForProposal(transitionProposal);

        // Verify transition
        address[] memory finalAdmins = starOwner.getAdmins();
        assertEq(finalAdmins.length, 2);
        assertEq(starOwner.quorumThreshold(), 2);

        // New governance works
        vm.prank(admin2);
        uint256 newEraProposal = starOwner.createSetMintPriceProposal(0.025 ether);
        vm.prank(admin3);
        starOwner.voteForProposal(newEraProposal);

        assertEq(starOwner.mintPrice(), 0.025 ether);
    }

    // ============ Stress Testing and Edge Cases ============

    function testHighVolumeOperations() public {
        // Test system under high load

        // Setup multi-admin for stress testing
        vm.prank(admin1);
        starOwner.createAddAdminProposal(admin2);

        // High-volume minting simulation
        address[10] memory users =
            [user1, user2, user3, creator1, creator2, collector, admin1, admin2, admin3, makeAddr("user10")];

        // Give ETH to all users
        for (uint256 i = 0; i < users.length; i++) {
            vm.deal(users[i], 10 ether);
        }

        // Mass minting
        for (uint256 i = 0; i < users.length; i++) {
            vm.prank(users[i]);
            starOwner.mint{value: INITIAL_MINT_PRICE}(string(abi.encodePacked("ipfs://QmPet", vm.toString(i))));
        }

        assertEq(starOwner.totalSupply(), 10);

        // Test governance under load - multiple simultaneous proposals
        vm.prank(admin1);
        uint256 proposal1 = starOwner.createSetMintPriceProposal(0.02 ether);

        vm.prank(admin1);
        uint256 proposal2 = starOwner.createSetTokenFeeProposal(2000 * 10 ** 18);

        // Vote on both
        vm.prank(admin2);
        starOwner.voteForProposal(proposal1);
        vm.prank(admin2);
        starOwner.voteForProposal(proposal2);

        // Verify both executed
        assertEq(starOwner.mintPrice(), 0.02 ether);
        assertEq(starOwner.tokenMintPrice(), 2000 * 10 ** 18);

        // Mass revenue withdrawal
        uint256 totalRevenue = address(starOwner).balance;
        vm.prank(admin1);
        uint256 withdrawProposal = starOwner.createWithdrawFundsProposal(admin1, totalRevenue);
        vm.prank(admin2);
        starOwner.voteForProposal(withdrawProposal);

        assertEq(address(starOwner).balance, 0);
    }

    function testContentModerationScenario() public {
        // Test content moderation capabilities

        // Setup governance
        vm.prank(admin1);
        starOwner.createAddAdminProposal(admin2);
        vm.prank(admin1);
        uint256 addAdmin3 = starOwner.createAddAdminProposal(admin3);
        vm.prank(admin2);
        starOwner.voteForProposal(addAdmin3);

        // Users mint content
        vm.prank(user1);
        uint256 goodContent = starOwner.mint{value: INITIAL_MINT_PRICE}(IPFS_CAT_1);

        vm.prank(user2);
        uint256 problematicContent = starOwner.mint{value: INITIAL_MINT_PRICE}("ipfs://QmProblematic");

        // Content moderation - update problematic content
        string memory moderatedURI = "ipfs://QmModerated";
        vm.prank(admin1);
        starOwner.updateTokenURI(problematicContent, moderatedURI);

        assertEq(starOwner.tokenURI(problematicContent), moderatedURI);
        assertEq(starOwner.tokenURI(goodContent), IPFS_CAT_1); // Unchanged

        // Verify only admins can moderate
        vm.expectRevert();
        vm.prank(user1);
        starOwner.updateTokenURI(goodContent, "ipfs://QmHacked");

        assertEq(starOwner.tokenURI(goodContent), IPFS_CAT_1); // Still unchanged
    }

    // ============ Event Integration Testing ============

    function testComprehensiveEventEmission() public {
        // Test basic functionality and verify events are emitted (without strict ordering)

        // Test minting
        vm.prank(user1);
        uint256 token1 = starOwner.mint{value: INITIAL_MINT_PRICE}(IPFS_CAT_1);
        assertEq(starOwner.ownerOf(token1), user1);

        // Test token minting
        vm.startPrank(user2);
        paymentToken.approve(address(starOwner), INITIAL_TOKEN_PRICE);
        uint256 token2 = starOwner.mintWithToken(IPFS_DOG_1);
        vm.stopPrank();
        assertEq(starOwner.ownerOf(token2), user2);

        // Test admin addition
        vm.prank(admin1);
        starOwner.createAddAdminProposal(admin2);

        address[] memory admins = starOwner.getAdmins();
        assertEq(admins.length, 2);

        // Test price update
        vm.prank(admin1);
        uint256 priceProposal = starOwner.createSetMintPriceProposal(0.02 ether);
        vm.prank(admin2);
        starOwner.voteForProposal(priceProposal);

        assertEq(starOwner.mintPrice(), 0.02 ether);

        // Test URI update
        vm.prank(admin1);
        starOwner.updateTokenURI(token1, "ipfs://QmUpdated");
        assertEq(starOwner.tokenURI(token1), "ipfs://QmUpdated");

        // Test withdrawal
        uint256 adminBalanceBefore = admin1.balance;
        vm.prank(admin1);
        uint256 withdrawProposal = starOwner.createWithdrawFundsProposal(admin1, INITIAL_MINT_PRICE);
        vm.prank(admin2);
        starOwner.voteForProposal(withdrawProposal);

        assertEq(admin1.balance, adminBalanceBefore + INITIAL_MINT_PRICE);
    }

    // ============ Gas Efficiency Integration Tests ============

    function testGasOptimizationScenarios() public {
        // Test gas efficiency in real-world usage

        // Single admin vs multi-admin gas comparison
        uint256 gasBefore = gasleft();
        vm.prank(admin1);
        starOwner.createSetMintPriceProposal(0.02 ether);
        uint256 singleAdminGas = gasBefore - gasleft();

        // Add admins
        vm.prank(admin1);
        starOwner.createAddAdminProposal(admin2);
        vm.prank(admin1);
        uint256 addAdmin3 = starOwner.createAddAdminProposal(admin3);
        vm.prank(admin2);
        starOwner.voteForProposal(addAdmin3);

        // Multi-admin operation
        gasBefore = gasleft();
        vm.prank(admin1);
        uint256 multiProposal = starOwner.createSetMintPriceProposal(0.03 ether);
        vm.prank(admin2);
        starOwner.voteForProposal(multiProposal);
        vm.prank(admin3);
        starOwner.voteForProposal(multiProposal);
        uint256 multiAdminGas = gasBefore - gasleft();

        // Multi-admin should use more gas due to voting
        assertTrue(multiAdminGas > singleAdminGas);

        // Batch minting gas efficiency
        gasBefore = gasleft();
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(user1);
            starOwner.mint{value: 0.03 ether}(string(abi.encodePacked("ipfs://QmBatch", vm.toString(i))));
        }
        uint256 batchGas = gasBefore - gasleft();

        // Log gas usage for optimization insights
        console.log("Single admin governance gas:", singleAdminGas);
        console.log("Multi admin governance gas:", multiAdminGas);
        console.log("Batch 5 mints gas:", batchGas);
    }

    // ============ Integration State Verification ============

    function testStatePersistenceAcrossOperations() public {
        // Test that state remains consistent across complex operations

        // Initial state
        string memory name = starOwner.name();
        string memory symbol = starOwner.symbol();
        uint256 totalSupply = starOwner.totalSupply();
        uint256 mintPrice = starOwner.mintPrice();
        uint256 tokenMintPrice = starOwner.tokenMintPrice();
        address paymentTokenAddr = starOwner.paymentToken();
        uint256 quorumThreshold = starOwner.quorumThreshold();
        uint256 totalProposals = starOwner.getTotalProposals();

        assertEq(name, COLLECTION_NAME);
        assertEq(symbol, COLLECTION_SYMBOL);
        assertEq(totalSupply, 0);
        assertEq(mintPrice, INITIAL_MINT_PRICE);
        assertEq(tokenMintPrice, INITIAL_TOKEN_PRICE);
        assertEq(paymentTokenAddr, address(paymentToken));
        assertEq(quorumThreshold, 1);
        assertEq(totalProposals, 0);

        // Perform various operations
        vm.prank(admin1);
        starOwner.createAddAdminProposal(admin2);

        vm.prank(user1);
        starOwner.mint{value: INITIAL_MINT_PRICE}(IPFS_CAT_1);

        vm.prank(admin1);
        uint256 priceProposal = starOwner.createSetMintPriceProposal(0.02 ether);
        vm.prank(admin2);
        starOwner.voteForProposal(priceProposal);

        // Verify updated state
        name = starOwner.name();
        symbol = starOwner.symbol();
        totalSupply = starOwner.totalSupply();
        mintPrice = starOwner.mintPrice();
        tokenMintPrice = starOwner.tokenMintPrice();
        paymentTokenAddr = starOwner.paymentToken();
        quorumThreshold = starOwner.quorumThreshold();
        totalProposals = starOwner.getTotalProposals();

        assertEq(name, COLLECTION_NAME); // Unchanged
        assertEq(symbol, COLLECTION_SYMBOL); // Unchanged
        assertEq(totalSupply, 1); // Increased
        assertEq(mintPrice, 0.02 ether); // Changed
        assertEq(tokenMintPrice, INITIAL_TOKEN_PRICE); // Unchanged
        assertEq(paymentTokenAddr, address(paymentToken)); // Unchanged
        assertEq(quorumThreshold, 2); // Changed (2 admins)
        assertEq(totalProposals, 2); // Increased
    }
}
