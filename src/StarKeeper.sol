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
    uint256 private tokenIdCounter;
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
     * @param _name Collection name
     * @param _symbol Collection symbol
     * @param _maxSupply Maximum number of NFTs in the collection
     * @param _mintPrice Price in native tokens to mint one NFT
     * @param _tokenMintPrice Price in ERC20 tokens to mint one NFT
     * @param _paymentToken Address of ERC20 token for payments (address(0) if not using ERC20)
     * @param _baseTokenURI Base URI for token metadata
     * @param _collectionImageURI IPFS URI of the collection image
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        uint256 _mintPrice,
        uint256 _tokenMintPrice,
        address _paymentToken,
        string memory _baseTokenURI,
        string memory _collectionImageURI
    ) ERC721(_name, _symbol) validSupply(_maxSupply) {
        factory = msg.sender;
        maxSupply = _maxSupply;
        baseTokenURI = _baseTokenURI;
        tokenIdCounter = 1;
        mintPrice = _mintPrice;
        tokenMintPrice = _tokenMintPrice;
        paymentToken = _paymentToken;
        collectionImageURI = _collectionImageURI;
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
     * @param _to Address to mint to
     * @return tokenId The ID of the minted token
     */
    function mintTo(address _to) external onlyFactory validAddress(_to) returns (uint256) {
        uint256 tokenId = _mintToken(_to);
        emit Minted(_to, tokenId, "Admin");
        return tokenId;
    }

    /**
     * @dev Set the base URI (factory-only)
     * @param _newBaseURI New base URI for token metadata
     */
    function setBaseURI(string calldata _newBaseURI) external onlyFactory validURI(_newBaseURI) {
        string memory oldURI = baseTokenURI;
        baseTokenURI = _newBaseURI;
        emit BaseURIUpdated(oldURI, _newBaseURI);
    }

    /**
     * @dev Set the collection image URI (factory-only)
     * @param _newImageURI New IPFS URI for the collection image
     */
    function setCollectionImageURI(string calldata _newImageURI) external onlyFactory validURI(_newImageURI) {
        string memory oldURI = collectionImageURI;
        collectionImageURI = _newImageURI;
        emit CollectionImageURIUpdated(oldURI, _newImageURI);
    }

    /**
     * @dev Set the mint price (factory-only)
     * @param _newPrice New price in native tokens
     */
    function setMintPrice(uint256 _newPrice) external onlyFactory {
        uint256 oldPrice = mintPrice;
        mintPrice = _newPrice;
        emit MintPriceUpdated(oldPrice, _newPrice);
    }

    /**
     * @dev Set the ERC20 token mint price (factory-only)
     * @param _newPrice New price in ERC20 tokens
     */
    function setTokenMintPrice(uint256 _newPrice) external onlyFactory {
        uint256 oldPrice = tokenMintPrice;
        tokenMintPrice = _newPrice;
        emit TokenMintPriceUpdated(oldPrice, _newPrice);
    }

    /**
     * @dev Set the payment token (factory-only)
     * @param _newToken New ERC20 token address
     */
    function setPaymentToken(address _newToken) external onlyFactory {
        address oldToken = paymentToken;
        paymentToken = _newToken;
        emit PaymentTokenUpdated(oldToken, _newToken);
    }

    /**
     * @dev Set maximum supply (factory-only)
     * @param _newMaxSupply New maximum supply (cannot be less than current totalSupply)
     */
    function setMaxSupply(uint256 _newMaxSupply) external onlyFactory validSupply(_newMaxSupply) {
        if (_newMaxSupply < totalSupply()) revert InvalidMaxSupply();
        uint256 oldMaxSupply = maxSupply;
        maxSupply = _newMaxSupply;
        emit MaxSupplyUpdated(oldMaxSupply, _newMaxSupply);
    }

    /**
     * @dev Withdraw native tokens (factory-only)
     * @param _to Address to withdraw to
     * @param _amount Amount to withdraw
     */
    function withdrawFunds(address payable _to, uint256 _amount)
        external
        onlyFactory
        validAddress(_to)
        validAmount(_amount)
    {
        uint256 balance = address(this).balance;
        if (balance < _amount) revert InsufficientBalance();

        (bool success,) = _to.call{value: _amount}("");
        if (!success) revert WithdrawalFailed();
        emit FundsWithdrawn(_to, _amount);
    }

    /**
     * @dev Withdraw ERC20 tokens (factory-only)
     * @param _to Address to withdraw to
     * @param _amount Amount to withdraw
     */
    function withdrawTokens(address _to, uint256 _amount) external onlyFactory validAddress(_to) validAmount(_amount) {
        if (paymentToken == address(0)) revert ERC20PaymentNotEnabled();

        IERC20 token = IERC20(paymentToken);
        uint256 balance = token.balanceOf(address(this));

        if (balance < _amount) revert InsufficientBalance();

        token.safeTransfer(_to, _amount);
        emit TokensWithdrawn(_to, _amount);
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
     * @param _to Address to mint to
     * @return tokenId The ID of the minted token
     */
    function _mintToken(address _to) internal returns (uint256) {
        if (totalSupply() >= maxSupply) revert MaxSupplyReached();

        uint256 tokenId = tokenIdCounter;
        unchecked {
            ++tokenIdCounter;
        }
        _safeMint(_to, tokenId);
        return tokenId;
    }

    /**
     * @dev Override tokenURI to use baseTokenURI with enhanced validation
     * @param tokenId Token ID to get URI for
     * @return The complete token URI
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (tokenId == 0 || tokenId >= tokenIdCounter) revert TokenDoesNotExist();
        return baseTokenURI;
    }

    // ============ Receive Function ============

    /**
     * @dev Allow contract to receive ETH
     */
    receive() external payable {}
}
