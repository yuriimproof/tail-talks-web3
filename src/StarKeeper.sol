// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title StarKeeper
 * @dev NFT collection with admin governance controlled by factory
 * @notice This contract represents a themed pet collection with fixed supply and factory governance
 * @author Yuri Improof (@yuriimproof) for TailTalks Team
 */
contract StarKeeper is ERC721Enumerable {
    using SafeERC20 for IERC20;

    // ============ State Variables ============

    // Core collection settings
    uint256 public maxSupply;
    uint256 private _tokenIdCounter;
    string public baseTokenURI;
    address public immutable factory;

    // Pricing
    uint256 public mintPrice;
    uint256 public tokenMintPrice;
    address public paymentToken;

    // Collection metadata
    string public collectionImageURI;

    // ============ Events ============

    event Minted(address indexed to, uint256 indexed tokenId, string paymentMethod);
    event FundsWithdrawn(address indexed to, uint256 amount);
    event TokensWithdrawn(address indexed to, uint256 amount);
    event MintPriceUpdated(uint256 oldPrice, uint256 newPrice);
    event TokenMintPriceUpdated(uint256 oldPrice, uint256 newPrice);
    event PaymentTokenUpdated(address indexed oldToken, address indexed newToken);
    event BaseURIUpdated(string oldURI, string newURI);
    event MaxSupplyUpdated(uint256 oldMaxSupply, uint256 newMaxSupply);
    event CollectionImageURIUpdated(string oldURI, string newURI);

    // ============ Custom Errors ============

    error InvalidMaxSupply();
    error MaxSupplyReached();
    error InsufficientPayment();
    error InsufficientBalance();
    error WithdrawalFailed();
    error TokenTransferFailed();
    error ERC20PaymentNotEnabled();
    error OnlyFactoryAllowed();
    error InvalidAddress();
    error TokenDoesNotExist();
    error InvalidParameters();
    error SupplyTooLow();
    error InvalidBaseURI();
    error InvalidImageURI();

    // ============ Modifiers ============

    modifier onlyFactory() {
        if (msg.sender != factory) revert OnlyFactoryAllowed();
        _;
    }

    modifier validAddress(address _address) {
        if (_address == address(0)) revert InvalidAddress();
        _;
    }

    modifier validSupply(uint256 _supply) {
        if (_supply <= 0) revert SupplyTooLow();
        _;
    }

    modifier validURI(string memory _uri) {
        if (bytes(_uri).length == 0) revert InvalidParameters();
        _;
    }

    modifier validAmount(uint256 _amount) {
        if (_amount <= 0) revert InvalidParameters();
        _;
    }

    // ============ Constructor ============

    /**
     * @dev Constructor for creating a new memorable collection
     * @param name_ Collection name
     * @param symbol_ Collection symbol
     * @param maxSupply_ Maximum number of NFTs in the collection
     * @param mintPrice_ Price in native tokens to mint one NFT
     * @param tokenMintPrice_ Price in ERC20 tokens to mint one NFT
     * @param paymentToken_ Address of ERC20 token for payments (address(0) if not using ERC20)
     * @param baseTokenURI_ Base URI for token metadata
     * @param collectionImageURI_ IPFS URI of the collection image
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_,
        uint256 mintPrice_,
        uint256 tokenMintPrice_,
        address paymentToken_,
        string memory baseTokenURI_,
        string memory collectionImageURI_
    ) ERC721(name_, symbol_) validSupply(maxSupply_) {
        factory = msg.sender;
        maxSupply = maxSupply_;
        baseTokenURI = baseTokenURI_;
        _tokenIdCounter = 1;
        mintPrice = mintPrice_;
        tokenMintPrice = tokenMintPrice_;
        paymentToken = paymentToken_;
        collectionImageURI = collectionImageURI_;
    }

    // ============ Public Minting Functions ============

    /**
     * @dev Mint a new token in the collection with native currency
     * @return tokenId The ID of the minted token
     */
    function mint() external payable returns (uint256) {
        if (msg.value < mintPrice) revert InsufficientPayment();

        uint256 tokenId = _mintToken(msg.sender);
        emit Minted(msg.sender, tokenId, "ETH");
        return tokenId;
    }

    /**
     * @dev Mint a new token in the collection using ERC20 tokens
     * @return tokenId The ID of the minted token
     */
    function mintWithToken() external returns (uint256) {
        if (paymentToken == address(0) || tokenMintPrice == 0) revert ERC20PaymentNotEnabled();

        IERC20 token = IERC20(paymentToken);
        token.safeTransferFrom(msg.sender, address(this), tokenMintPrice);

        uint256 tokenId = _mintToken(msg.sender);
        emit Minted(msg.sender, tokenId, "ERC20");
        return tokenId;
    }

    // ============ Factory-Only Functions ============

    /**
     * @dev Mint a token to a specific address (factory-only)
     * @param to_ Address to mint to
     * @return tokenId The ID of the minted token
     */
    function mintTo(address to_) external onlyFactory validAddress(to_) returns (uint256) {
        uint256 tokenId = _mintToken(to_);
        emit Minted(to_, tokenId, "Admin");
        return tokenId;
    }

    /**
     * @dev Set the base URI (factory-only)
     * @param newBaseURI_ New base URI for token metadata
     */
    function setBaseURI(string calldata newBaseURI_) external onlyFactory validURI(newBaseURI_) {
        string memory oldURI = baseTokenURI;
        baseTokenURI = newBaseURI_;
        emit BaseURIUpdated(oldURI, newBaseURI_);
    }

    /**
     * @dev Set the collection image URI (factory-only)
     * @param newImageURI_ New IPFS URI for the collection image
     */
    function setCollectionImageURI(string calldata newImageURI_) external onlyFactory validURI(newImageURI_) {
        string memory oldURI = collectionImageURI;
        collectionImageURI = newImageURI_;
        emit CollectionImageURIUpdated(oldURI, newImageURI_);
    }

    /**
     * @dev Set the mint price (factory-only)
     * @param newPrice_ New price in native tokens
     */
    function setMintPrice(uint256 newPrice_) external onlyFactory {
        uint256 oldPrice = mintPrice;
        mintPrice = newPrice_;
        emit MintPriceUpdated(oldPrice, newPrice_);
    }

    /**
     * @dev Set the ERC20 token mint price (factory-only)
     * @param newPrice_ New price in ERC20 tokens
     */
    function setTokenMintPrice(uint256 newPrice_) external onlyFactory {
        uint256 oldPrice = tokenMintPrice;
        tokenMintPrice = newPrice_;
        emit TokenMintPriceUpdated(oldPrice, newPrice_);
    }

    /**
     * @dev Set the payment token (factory-only)
     * @param newToken_ New ERC20 token address
     */
    function setPaymentToken(address newToken_) external onlyFactory {
        address oldToken = paymentToken;
        paymentToken = newToken_;
        emit PaymentTokenUpdated(oldToken, newToken_);
    }

    /**
     * @dev Set maximum supply (factory-only)
     * @param newMaxSupply_ New maximum supply (cannot be less than current totalSupply)
     */
    function setMaxSupply(uint256 newMaxSupply_) external onlyFactory validSupply(newMaxSupply_) {
        if (newMaxSupply_ < totalSupply()) revert InvalidMaxSupply();
        uint256 oldMaxSupply = maxSupply;
        maxSupply = newMaxSupply_;
        emit MaxSupplyUpdated(oldMaxSupply, newMaxSupply_);
    }

    /**
     * @dev Withdraw native tokens (factory-only)
     * @param to_ Address to withdraw to
     * @param amount_ Amount to withdraw
     */
    function withdrawFunds(address payable to_, uint256 amount_)
        external
        onlyFactory
        validAddress(to_)
        validAmount(amount_)
    {
        uint256 balance = address(this).balance;
        if (balance < amount_) revert InsufficientBalance();

        (bool success,) = to_.call{value: amount_}("");
        if (!success) revert WithdrawalFailed();
        emit FundsWithdrawn(to_, amount_);
    }

    /**
     * @dev Withdraw ERC20 tokens (factory-only)
     * @param to_ Address to withdraw to
     * @param amount_ Amount to withdraw
     */
    function withdrawTokens(address to_, uint256 amount_) external onlyFactory validAddress(to_) validAmount(amount_) {
        if (paymentToken == address(0)) revert ERC20PaymentNotEnabled();

        IERC20 token = IERC20(paymentToken);

        if (token.balanceOf(address(this)) < amount_) revert InsufficientBalance();

        token.safeTransfer(to_, amount_);
        emit TokensWithdrawn(to_, amount_);
    }

    // ============ View Functions ============

    /**
     * @dev Get the current number of tokens that have been minted
     * @return The current total supply of minted tokens
     */
    function getCurrentSupply() external view returns (uint256) {
        return totalSupply();
    }

    // ============ Internal Functions ============

    /**
     * @dev Internal minting logic with enhanced checks
     * @param to_ Address to mint to
     * @return tokenId The ID of the minted token
     */
    function _mintToken(address to_) internal returns (uint256) {
        if (totalSupply() >= maxSupply) revert MaxSupplyReached();

        uint256 tokenId = _tokenIdCounter;
        unchecked {
            ++_tokenIdCounter;
        }
        _safeMint(to_, tokenId);
        return tokenId;
    }

    /**
     * @dev Override tokenURI to use baseTokenURI with enhanced validation
     * @param tokenId_ Token ID to get URI for
     * @return The complete token URI
     */
    function tokenURI(uint256 tokenId_) public view virtual override returns (string memory) {
        if (tokenId_ == 0 || tokenId_ >= _tokenIdCounter) revert TokenDoesNotExist();
        return baseTokenURI;
    }

    // ============ Receive Function ============

    /**
     * @dev Allow contract to receive ETH
     */
    receive() external payable {}
}
