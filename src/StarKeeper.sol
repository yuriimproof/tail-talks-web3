// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title StarKeeper
 * @dev NFT collection with admin governance controlled by factory
 */
contract StarKeeper is ERC721Enumerable {
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
    event MintPriceUpdated(uint256 newPrice);
    event TokenMintPriceUpdated(uint256 newPrice);
    event PaymentTokenUpdated(address newToken);
    event BaseURIUpdated(string newURI);
    event MaxSupplyUpdated(uint256 newMaxSupply);
    event CollectionImageURIUpdated(string newURI);

    // ============ Custom Errors ============

    error InvalidMaxSupply();
    error MaxSupplyReached();
    error InsufficientPayment();
    error WithdrawalFailed();
    error TokenTransferFailed();
    error ERC20PaymentNotEnabled();
    error OnlyFactoryAllowed();
    error InvalidAddress();
    error TokenDoesNotExist();

    // ============ Modifiers ============

    modifier onlyFactory() {
        if (msg.sender != factory) revert OnlyFactoryAllowed();
        _;
    }

    modifier validAddress(address _address) {
        if (_address == address(0)) revert InvalidAddress();
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
    ) ERC721(_name, _symbol) {
        if (_maxSupply == 0) revert InvalidMaxSupply();

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
        if (!token.transferFrom(msg.sender, address(this), tokenMintPrice)) {
            revert TokenTransferFailed();
        }

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
    function setBaseURI(string calldata _newBaseURI) external onlyFactory {
        baseTokenURI = _newBaseURI;
        emit BaseURIUpdated(_newBaseURI);
    }

    /**
     * @dev Set the collection image URI (factory-only)
     * @param _newImageURI New IPFS URI for the collection image
     */
    function setCollectionImageURI(string calldata _newImageURI) external onlyFactory {
        collectionImageURI = _newImageURI;
        emit CollectionImageURIUpdated(_newImageURI);
    }

    /**
     * @dev Set the mint price (factory-only)
     * @param _newPrice New price in native tokens
     */
    function setMintPrice(uint256 _newPrice) external onlyFactory {
        mintPrice = _newPrice;
        emit MintPriceUpdated(_newPrice);
    }

    /**
     * @dev Set the ERC20 token mint price (factory-only)
     * @param _newPrice New price in ERC20 tokens
     */
    function setTokenMintPrice(uint256 _newPrice) external onlyFactory {
        tokenMintPrice = _newPrice;
        emit TokenMintPriceUpdated(_newPrice);
    }

    /**
     * @dev Set the payment token (factory-only)
     * @param _newToken New ERC20 token address
     */
    function setPaymentToken(address _newToken) external onlyFactory {
        paymentToken = _newToken;
        emit PaymentTokenUpdated(_newToken);
    }

    /**
     * @dev Set maximum supply (factory-only)
     * @param _newMaxSupply New maximum supply (cannot be less than current totalSupply)
     */
    function setMaxSupply(uint256 _newMaxSupply) external onlyFactory {
        if (_newMaxSupply < totalSupply()) revert InvalidMaxSupply();
        maxSupply = _newMaxSupply;
        emit MaxSupplyUpdated(_newMaxSupply);
    }

    /**
     * @dev Withdraw native tokens (factory-only)
     * @param _to Address to withdraw to
     * @param _amount Amount to withdraw (0 for all)
     */
    function withdrawFunds(address payable _to, uint256 _amount) external onlyFactory validAddress(_to) {
        uint256 balance = address(this).balance;
        uint256 withdrawAmount = _amount == 0 ? balance : _amount;

        if (withdrawAmount > balance) {
            withdrawAmount = balance;
        }

        (bool success,) = _to.call{value: withdrawAmount}("");
        if (!success) revert WithdrawalFailed();

        emit FundsWithdrawn(_to, withdrawAmount);
    }

    /**
     * @dev Withdraw ERC20 tokens (factory-only)
     * @param _to Address to withdraw to
     */
    function withdrawTokens(address _to) external onlyFactory validAddress(_to) {
        if (paymentToken == address(0)) revert ERC20PaymentNotEnabled();

        IERC20 token = IERC20(paymentToken);
        uint256 balance = token.balanceOf(address(this));
        if (!token.transfer(_to, balance)) revert TokenTransferFailed();

        emit TokensWithdrawn(_to, balance);
    }

    // ============ View Functions ============

    /**
     * @dev Get the current number of tokens that have been minted
     * @return The current total supply of minted tokens
     */
    function getCurrentSupply() external view returns (uint256) {
        return totalSupply();
    }

    /**
     * @dev Get collection information in one call
     * @return name_ Collection name
     * @return symbol_ Collection symbol
     * @return totalSupply_ Current total supply
     * @return maxSupply_ Maximum supply
     * @return mintPrice_ Price in native tokens
     * @return tokenMintPrice_ Price in ERC20 tokens
     * @return paymentToken_ ERC20 payment token address
     */
    function getCollectionInfo()
        external
        view
        returns (
            string memory name_,
            string memory symbol_,
            uint256 totalSupply_,
            uint256 maxSupply_,
            uint256 mintPrice_,
            uint256 tokenMintPrice_,
            address paymentToken_
        )
    {
        return (name(), symbol(), totalSupply(), maxSupply, mintPrice, tokenMintPrice, paymentToken);
    }

    // ============ Internal Functions ============

    /**
     * @dev Internal minting logic
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
     * @dev Override tokenURI to use baseTokenURI
     * @param tokenId Token ID to get URI for
     * @return The complete token URI
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (tokenId == 0 || tokenId >= tokenIdCounter) revert TokenDoesNotExist();
        return baseTokenURI;
    }
}
