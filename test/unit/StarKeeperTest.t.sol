// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {StarKeeper} from "../../src/StarKeeper.sol";
import {MockERC20} from "../mocks/ERC20Mock.sol";

contract StarKeeperTest is Test {
    StarKeeper public starKeeper;
    MockERC20 public mockToken;

    address public factory = makeAddr("factory");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");

    uint256 public constant MAX_SUPPLY = 100;
    uint256 public constant MINT_PRICE = 0.01 ether;
    uint256 public constant TOKEN_MINT_PRICE = 1000 * 10 ** 18;
    string public constant BASE_TOKEN_URI = "https://api.example.com/metadata/";
    string public constant COLLECTION_IMAGE_URI = "ipfs://collection-image";

    function setUp() public {
        mockToken = new MockERC20();

        vm.prank(factory);
        starKeeper = new StarKeeper(
            "Test Collection",
            "TEST",
            MAX_SUPPLY,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        // Give users some ETH and tokens
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        mockToken.mint(user1, 10000 * 10 ** 18);
        mockToken.mint(user2, 10000 * 10 ** 18);
        mockToken.mint(user3, 10000 * 10 ** 18);
    }

    // ============ Constructor Tests ============

    function testConstructor() public view {
        assertEq(starKeeper.name(), "Test Collection");
        assertEq(starKeeper.symbol(), "TEST");
        assertEq(starKeeper.maxSupply(), MAX_SUPPLY);
        assertEq(starKeeper.mintPrice(), MINT_PRICE);
        assertEq(starKeeper.tokenMintPrice(), TOKEN_MINT_PRICE);
        assertEq(starKeeper.paymentToken(), address(mockToken));
        assertEq(starKeeper.collectionImageURI(), COLLECTION_IMAGE_URI);
        assertEq(starKeeper.totalSupply(), 0);
        assertEq(starKeeper.getCurrentSupply(), 0);
    }

    function testConstructorRevertsZeroMaxSupply() public {
        vm.expectRevert(StarKeeper.SupplyTooLow.selector);
        vm.prank(factory);
        new StarKeeper(
            "Invalid Collection",
            "INVALID",
            0, // Zero max supply
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );
    }

    // ============ Minting Tests ============

    function testMintWithETH() public {
        vm.prank(user1);
        uint256 tokenId = starKeeper.mint{value: MINT_PRICE}();

        assertEq(tokenId, 1);
        assertEq(starKeeper.ownerOf(1), user1);
        assertEq(starKeeper.totalSupply(), 1);
        assertEq(starKeeper.getCurrentSupply(), 1);
        assertEq(address(starKeeper).balance, MINT_PRICE);
    }

    function testMintWithETHRevertsInsufficientPayment() public {
        vm.expectRevert(StarKeeper.InsufficientPayment.selector);
        vm.prank(user1);
        starKeeper.mint{value: MINT_PRICE - 1}();
    }

    function testMintWithToken() public {
        vm.startPrank(user1);
        mockToken.approve(address(starKeeper), TOKEN_MINT_PRICE);
        uint256 tokenId = starKeeper.mintWithToken();
        vm.stopPrank();

        assertEq(tokenId, 1);
        assertEq(starKeeper.ownerOf(1), user1);
        assertEq(starKeeper.totalSupply(), 1);
        assertEq(mockToken.balanceOf(address(starKeeper)), TOKEN_MINT_PRICE);
    }

    function testMintWithTokenRevertsWhenNotEnabled() public {
        // Deploy with no payment token
        vm.prank(factory);
        StarKeeper noTokenKeeper = new StarKeeper(
            "No Token",
            "NT",
            MAX_SUPPLY,
            MINT_PRICE,
            0, // No token price
            address(0), // No payment token
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        vm.expectRevert(StarKeeper.ERC20PaymentNotEnabled.selector);
        vm.prank(user1);
        noTokenKeeper.mintWithToken();
    }

    function testMintWithTokenRevertsZeroTokenPrice() public {
        // Deploy with zero token price
        vm.prank(factory);
        StarKeeper zeroTokenPriceKeeper = new StarKeeper(
            "Zero Token Price",
            "ZTP",
            MAX_SUPPLY,
            MINT_PRICE,
            0, // Zero token price
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        vm.expectRevert(StarKeeper.ERC20PaymentNotEnabled.selector);
        vm.prank(user1);
        zeroTokenPriceKeeper.mintWithToken();
    }

    function testMintMaxSupplyReached() public {
        // Create collection with max supply of 2
        vm.prank(factory);
        StarKeeper smallKeeper = new StarKeeper(
            "Small Collection",
            "SMALL",
            2,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        // Mint 2 tokens
        vm.prank(user1);
        smallKeeper.mint{value: MINT_PRICE}();
        vm.prank(user2);
        smallKeeper.mint{value: MINT_PRICE}();

        // Third mint should fail
        vm.expectRevert(StarKeeper.MaxSupplyReached.selector);
        vm.prank(user3);
        smallKeeper.mint{value: MINT_PRICE}();
    }

    function testSequentialTokenIds() public {
        vm.prank(user1);
        uint256 token1 = starKeeper.mint{value: MINT_PRICE}();

        vm.prank(user2);
        uint256 token2 = starKeeper.mint{value: MINT_PRICE}();

        vm.prank(user3);
        uint256 token3 = starKeeper.mint{value: MINT_PRICE}();

        assertEq(token1, 1);
        assertEq(token2, 2);
        assertEq(token3, 3);
        assertEq(starKeeper.totalSupply(), 3);
    }

    // ============ Factory-Only Function Tests ============

    function testMintTo() public {
        vm.prank(factory);
        uint256 tokenId = starKeeper.mintTo(user1);

        assertEq(tokenId, 1);
        assertEq(starKeeper.ownerOf(1), user1);
        assertEq(starKeeper.totalSupply(), 1);
    }

    function testMintToRevertsNonFactory() public {
        vm.expectRevert(StarKeeper.OnlyFactoryAllowed.selector);
        vm.prank(user1);
        starKeeper.mintTo(user2);
    }

    function testMintToRevertsZeroAddress() public {
        vm.expectRevert(StarKeeper.InvalidAddress.selector);
        vm.prank(factory);
        starKeeper.mintTo(address(0));
    }

    function testSetBaseURI() public {
        string memory newURI = "https://new-api.com/";

        vm.prank(factory);
        starKeeper.setBaseURI(newURI);

        // Mint a token to test the new URI
        vm.prank(user1);
        uint256 tokenId = starKeeper.mint{value: MINT_PRICE}();

        assertEq(starKeeper.tokenURI(tokenId), newURI);
    }

    function testSetBaseURIRevertsNonFactory() public {
        vm.expectRevert(StarKeeper.OnlyFactoryAllowed.selector);
        vm.prank(user1);
        starKeeper.setBaseURI("https://hacker.com/");
    }

    function testSetBaseURIRevertsEmptyString() public {
        vm.expectRevert(StarKeeper.InvalidParameters.selector);
        vm.prank(factory);
        starKeeper.setBaseURI("");
    }

    function testSetCollectionImageURI() public {
        string memory newImageURI = "ipfs://new-image";

        vm.prank(factory);
        starKeeper.setCollectionImageURI(newImageURI);

        assertEq(starKeeper.collectionImageURI(), newImageURI);
    }

    function testSetCollectionImageURIRevertsNonFactory() public {
        vm.expectRevert(StarKeeper.OnlyFactoryAllowed.selector);
        vm.prank(user1);
        starKeeper.setCollectionImageURI("ipfs://hacker");
    }

    function testSetCollectionImageURIRevertsEmptyString() public {
        vm.expectRevert(StarKeeper.InvalidParameters.selector);
        vm.prank(factory);
        starKeeper.setCollectionImageURI("");
    }

    function testSetMintPrice() public {
        uint256 newPrice = 0.02 ether;

        vm.prank(factory);
        starKeeper.setMintPrice(newPrice);

        assertEq(starKeeper.mintPrice(), newPrice);
    }

    function testSetMintPriceRevertsNonFactory() public {
        vm.expectRevert(StarKeeper.OnlyFactoryAllowed.selector);
        vm.prank(user1);
        starKeeper.setMintPrice(0.02 ether);
    }

    function testSetTokenMintPrice() public {
        uint256 newPrice = 2000 * 10 ** 18;

        vm.prank(factory);
        starKeeper.setTokenMintPrice(newPrice);

        assertEq(starKeeper.tokenMintPrice(), newPrice);
    }

    function testSetTokenMintPriceRevertsNonFactory() public {
        vm.expectRevert(StarKeeper.OnlyFactoryAllowed.selector);
        vm.prank(user1);
        starKeeper.setTokenMintPrice(2000 * 10 ** 18);
    }

    function testSetPaymentToken() public {
        address newToken = makeAddr("newToken");

        vm.prank(factory);
        starKeeper.setPaymentToken(newToken);

        assertEq(starKeeper.paymentToken(), newToken);
    }

    function testSetPaymentTokenRevertsNonFactory() public {
        vm.expectRevert(StarKeeper.OnlyFactoryAllowed.selector);
        vm.prank(user1);
        starKeeper.setPaymentToken(makeAddr("newToken"));
    }

    function testSetMaxSupply() public {
        uint256 newMaxSupply = 200;

        vm.prank(factory);
        starKeeper.setMaxSupply(newMaxSupply);

        assertEq(starKeeper.maxSupply(), newMaxSupply);
    }

    function testSetMaxSupplyRevertsNonFactory() public {
        vm.expectRevert(StarKeeper.OnlyFactoryAllowed.selector);
        vm.prank(user1);
        starKeeper.setMaxSupply(200);
    }

    function testSetMaxSupplyRevertsZeroSupply() public {
        vm.expectRevert(StarKeeper.SupplyTooLow.selector);
        vm.prank(factory);
        starKeeper.setMaxSupply(0);
    }

    function testSetMaxSupplyRevertsBelowCurrentSupply() public {
        // Mint some tokens first
        vm.prank(user1);
        starKeeper.mint{value: MINT_PRICE}();
        vm.prank(user2);
        starKeeper.mint{value: MINT_PRICE}();

        // Try to set max supply below current supply
        vm.expectRevert(StarKeeper.InvalidMaxSupply.selector);
        vm.prank(factory);
        starKeeper.setMaxSupply(1); // Current supply is 2
    }

    // ============ Withdrawal Tests ============

    function testWithdrawFunds() public {
        // Accumulate some funds
        vm.prank(user1);
        starKeeper.mint{value: MINT_PRICE}();
        vm.prank(user2);
        starKeeper.mint{value: MINT_PRICE}();

        uint256 balanceBefore = user3.balance;

        vm.prank(factory);
        starKeeper.withdrawFunds(payable(user3), MINT_PRICE);

        assertEq(user3.balance, balanceBefore + MINT_PRICE);
        assertEq(address(starKeeper).balance, MINT_PRICE);
    }

    function testWithdrawFundsRevertsNonFactory() public {
        vm.prank(user1);
        starKeeper.mint{value: MINT_PRICE}();

        vm.expectRevert(StarKeeper.OnlyFactoryAllowed.selector);
        vm.prank(user1);
        starKeeper.withdrawFunds(payable(user1), MINT_PRICE);
    }

    function testWithdrawFundsRevertsZeroAddress() public {
        vm.prank(user1);
        starKeeper.mint{value: MINT_PRICE}();

        vm.expectRevert(StarKeeper.InvalidAddress.selector);
        vm.prank(factory);
        starKeeper.withdrawFunds(payable(address(0)), MINT_PRICE);
    }

    function testWithdrawFundsRevertsZeroAmount() public {
        vm.prank(user1);
        starKeeper.mint{value: MINT_PRICE}();

        vm.expectRevert(StarKeeper.InvalidParameters.selector);
        vm.prank(factory);
        starKeeper.withdrawFunds(payable(user3), 0);
    }

    function testWithdrawFundsRevertsInsufficientBalance() public {
        vm.prank(user1);
        starKeeper.mint{value: MINT_PRICE}();

        vm.expectRevert(StarKeeper.InsufficientBalance.selector);
        vm.prank(factory);
        starKeeper.withdrawFunds(payable(user3), MINT_PRICE + 1);
    }

    function testWithdrawTokens() public {
        // Accumulate some tokens
        vm.startPrank(user1);
        mockToken.approve(address(starKeeper), TOKEN_MINT_PRICE);
        starKeeper.mintWithToken();
        vm.stopPrank();

        vm.startPrank(user2);
        mockToken.approve(address(starKeeper), TOKEN_MINT_PRICE);
        starKeeper.mintWithToken();
        vm.stopPrank();

        uint256 balanceBefore = mockToken.balanceOf(user3);

        vm.prank(factory);
        starKeeper.withdrawTokens(user3, TOKEN_MINT_PRICE);

        assertEq(mockToken.balanceOf(user3), balanceBefore + TOKEN_MINT_PRICE);
        assertEq(mockToken.balanceOf(address(starKeeper)), TOKEN_MINT_PRICE);
    }

    function testWithdrawTokensRevertsNonFactory() public {
        vm.startPrank(user1);
        mockToken.approve(address(starKeeper), TOKEN_MINT_PRICE);
        starKeeper.mintWithToken();
        vm.stopPrank();

        vm.expectRevert(StarKeeper.OnlyFactoryAllowed.selector);
        vm.prank(user1);
        starKeeper.withdrawTokens(user1, TOKEN_MINT_PRICE);
    }

    function testWithdrawTokensRevertsZeroAddress() public {
        vm.startPrank(user1);
        mockToken.approve(address(starKeeper), TOKEN_MINT_PRICE);
        starKeeper.mintWithToken();
        vm.stopPrank();

        vm.expectRevert(StarKeeper.InvalidAddress.selector);
        vm.prank(factory);
        starKeeper.withdrawTokens(address(0), TOKEN_MINT_PRICE);
    }

    function testWithdrawTokensRevertsZeroAmount() public {
        vm.startPrank(user1);
        mockToken.approve(address(starKeeper), TOKEN_MINT_PRICE);
        starKeeper.mintWithToken();
        vm.stopPrank();

        vm.expectRevert(StarKeeper.InvalidParameters.selector);
        vm.prank(factory);
        starKeeper.withdrawTokens(user3, 0);
    }

    function testWithdrawTokensRevertsNoPaymentToken() public {
        // Deploy with no payment token
        vm.prank(factory);
        StarKeeper noTokenKeeper = new StarKeeper(
            "No Token",
            "NT",
            MAX_SUPPLY,
            MINT_PRICE,
            0,
            address(0), // No payment token
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        vm.expectRevert(StarKeeper.ERC20PaymentNotEnabled.selector);
        vm.prank(factory);
        noTokenKeeper.withdrawTokens(user3, 100);
    }

    function testWithdrawTokensRevertsInsufficientBalance() public {
        vm.startPrank(user1);
        mockToken.approve(address(starKeeper), TOKEN_MINT_PRICE);
        starKeeper.mintWithToken();
        vm.stopPrank();

        vm.expectRevert(StarKeeper.InsufficientBalance.selector);
        vm.prank(factory);
        starKeeper.withdrawTokens(user3, TOKEN_MINT_PRICE + 1);
    }

    // ============ Token URI Tests ============

    function testTokenURI() public {
        vm.prank(user1);
        uint256 tokenId = starKeeper.mint{value: MINT_PRICE}();

        assertEq(starKeeper.tokenURI(tokenId), BASE_TOKEN_URI);
    }

    function testTokenURIRevertsZeroTokenId() public {
        vm.expectRevert(StarKeeper.TokenDoesNotExist.selector);
        starKeeper.tokenURI(0);
    }

    function testTokenURIRevertsNonExistentToken() public {
        vm.expectRevert(StarKeeper.TokenDoesNotExist.selector);
        starKeeper.tokenURI(999);
    }

    function testTokenURIAfterBaseURIUpdate() public {
        vm.prank(user1);
        uint256 tokenId = starKeeper.mint{value: MINT_PRICE}();

        string memory newURI = "https://updated-api.com/";
        vm.prank(factory);
        starKeeper.setBaseURI(newURI);

        assertEq(starKeeper.tokenURI(tokenId), newURI);
    }

    // ============ Event Tests ============

    function testMintEvent() public {
        vm.expectEmit(true, true, false, true);
        emit StarKeeper.Minted(user1, 1, "ETH");

        vm.prank(user1);
        starKeeper.mint{value: MINT_PRICE}();
    }

    function testMintWithTokenEvent() public {
        vm.startPrank(user1);
        mockToken.approve(address(starKeeper), TOKEN_MINT_PRICE);

        vm.expectEmit(true, true, false, true);
        emit StarKeeper.Minted(user1, 1, "ERC20");
        starKeeper.mintWithToken();
        vm.stopPrank();
    }

    function testMintToEvent() public {
        vm.expectEmit(true, true, false, true);
        emit StarKeeper.Minted(user1, 1, "Admin");

        vm.prank(factory);
        starKeeper.mintTo(user1);
    }

    function testBaseURIUpdatedEvent() public {
        string memory newURI = "https://new-api.com/";

        vm.expectEmit(false, false, false, true);
        emit StarKeeper.BaseURIUpdated(BASE_TOKEN_URI, newURI);

        vm.prank(factory);
        starKeeper.setBaseURI(newURI);
    }

    function testCollectionImageURIUpdatedEvent() public {
        string memory newImageURI = "ipfs://new-image";

        vm.expectEmit(false, false, false, true);
        emit StarKeeper.CollectionImageURIUpdated(COLLECTION_IMAGE_URI, newImageURI);

        vm.prank(factory);
        starKeeper.setCollectionImageURI(newImageURI);
    }

    function testMintPriceUpdatedEvent() public {
        uint256 newPrice = 0.02 ether;

        vm.expectEmit(false, false, false, true);
        emit StarKeeper.MintPriceUpdated(MINT_PRICE, newPrice);

        vm.prank(factory);
        starKeeper.setMintPrice(newPrice);
    }

    function testTokenMintPriceUpdatedEvent() public {
        uint256 newPrice = 2000 * 10 ** 18;

        vm.expectEmit(false, false, false, true);
        emit StarKeeper.TokenMintPriceUpdated(TOKEN_MINT_PRICE, newPrice);

        vm.prank(factory);
        starKeeper.setTokenMintPrice(newPrice);
    }

    function testPaymentTokenUpdatedEvent() public {
        address newToken = makeAddr("newToken");

        vm.expectEmit(true, true, false, false);
        emit StarKeeper.PaymentTokenUpdated(address(mockToken), newToken);

        vm.prank(factory);
        starKeeper.setPaymentToken(newToken);
    }

    function testMaxSupplyUpdatedEvent() public {
        uint256 newMaxSupply = 200;

        vm.expectEmit(false, false, false, true);
        emit StarKeeper.MaxSupplyUpdated(MAX_SUPPLY, newMaxSupply);

        vm.prank(factory);
        starKeeper.setMaxSupply(newMaxSupply);
    }

    function testFundsWithdrawnEvent() public {
        vm.prank(user1);
        starKeeper.mint{value: MINT_PRICE}();

        vm.expectEmit(true, false, false, true);
        emit StarKeeper.FundsWithdrawn(user3, MINT_PRICE);

        vm.prank(factory);
        starKeeper.withdrawFunds(payable(user3), MINT_PRICE);
    }

    function testTokensWithdrawnEvent() public {
        vm.startPrank(user1);
        mockToken.approve(address(starKeeper), TOKEN_MINT_PRICE);
        starKeeper.mintWithToken();
        vm.stopPrank();

        vm.expectEmit(true, false, false, true);
        emit StarKeeper.TokensWithdrawn(user3, TOKEN_MINT_PRICE);

        vm.prank(factory);
        starKeeper.withdrawTokens(user3, TOKEN_MINT_PRICE);
    }

    // ============ Receive Function Test ============

    function testReceiveETH() public {
        uint256 balanceBefore = address(starKeeper).balance;

        vm.prank(user1);
        (bool success,) = address(starKeeper).call{value: 1 ether}("");

        assertTrue(success);
        assertEq(address(starKeeper).balance, balanceBefore + 1 ether);
    }

    // ============ Edge Cases ============

    function testMintingAfterMaxSupplyIncrease() public {
        // Create collection with max supply of 2
        vm.prank(factory);
        StarKeeper smallKeeper = new StarKeeper(
            "Small Collection",
            "SMALL",
            2,
            MINT_PRICE,
            TOKEN_MINT_PRICE,
            address(mockToken),
            BASE_TOKEN_URI,
            COLLECTION_IMAGE_URI
        );

        // Mint to max supply
        vm.prank(user1);
        smallKeeper.mint{value: MINT_PRICE}();
        vm.prank(user2);
        smallKeeper.mint{value: MINT_PRICE}();

        // Increase max supply
        vm.prank(factory);
        smallKeeper.setMaxSupply(5);

        // Should be able to mint more now
        vm.prank(user3);
        uint256 tokenId = smallKeeper.mint{value: MINT_PRICE}();

        assertEq(tokenId, 3);
        assertEq(smallKeeper.totalSupply(), 3);
    }

    function testComplexScenario() public {
        // Test a complex scenario with multiple operations

        // Mint some tokens
        vm.prank(user1);
        starKeeper.mint{value: MINT_PRICE}();

        vm.startPrank(user2);
        mockToken.approve(address(starKeeper), TOKEN_MINT_PRICE);
        starKeeper.mintWithToken();
        vm.stopPrank();

        // Factory mints to user3
        vm.prank(factory);
        starKeeper.mintTo(user3);

        // Update settings
        vm.prank(factory);
        starKeeper.setMintPrice(0.02 ether);

        vm.prank(factory);
        starKeeper.setTokenMintPrice(2000 * 10 ** 18);

        // Mint with new prices
        vm.prank(user1);
        starKeeper.mint{value: 0.02 ether}();

        // Verify final state
        assertEq(starKeeper.totalSupply(), 4);
        assertEq(starKeeper.mintPrice(), 0.02 ether);
        assertEq(starKeeper.tokenMintPrice(), 2000 * 10 ** 18);
        assertEq(starKeeper.ownerOf(1), user1);
        assertEq(starKeeper.ownerOf(2), user2);
        assertEq(starKeeper.ownerOf(3), user3);
        assertEq(starKeeper.ownerOf(4), user1);
    }
}
