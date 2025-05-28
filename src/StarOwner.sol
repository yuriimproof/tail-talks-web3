// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title StarOwner
 * @dev NFT contract for pet images with multi-admin governance
 * @notice This contract allows minting of pet NFTs with custom IPFS URIs and implements
 *         a 75% quorum governance system for administrative operations
 * @author Yuri Improof (@yuriimproof) for TailTalks Team
 */
contract StarOwner is ERC721, AccessControl {
    using SafeERC20 for IERC20;

    // ============ Constants ============

    bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint256 private constant QUORUM_PERCENTAGE = 75; // 75%
    uint256 private constant PROPOSAL_DURATION = 7 days; // Fixed proposal duration

    // ============ Structs & Enums ============

    struct Proposal {
        uint256 id;
        address proposer;
        uint256 createdAt;
        uint256 approvalCount;
        uint256 expirationTime;
        bool executed;
        ProposalType proposalType;
        address targetAddress;
        uint256 value;
        mapping(address => bool) hasVoted;
    }

    enum ProposalType {
        AddAdmin,
        RemoveAdmin,
        WithdrawFunds,
        WithdrawTokens,
        SetMintPrice,
        SetTokenFee,
        SetPaymentToken
    }

    // ============ State Variables ============

    // Core NFT settings
    uint256 private _tokenIdCounter = 1;
    mapping(uint256 tokenId => string ipfsURI) private _tokenURIs; // Individual IPFS URIs for each token

    // Pricing
    uint256 public mintPrice;
    uint256 public tokenMintPrice;
    address public paymentToken;

    // Governance
    address[] private _admins;
    uint256 public quorumThreshold;

    // Proposals
    uint256 private _proposalCounter;
    mapping(uint256 => Proposal) private _proposals;

    // ============ Events ============

    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
    event QuorumUpdated(uint256 newThreshold);

    event ProposalCreated(uint256 indexed proposalId, ProposalType proposalType, address indexed proposer);
    event ProposalVoted(uint256 indexed proposalId, address indexed voter);
    event ProposalExecuted(uint256 indexed proposalId, ProposalType proposalType);

    event FundsWithdrawn(address indexed to, uint256 amount);
    event TokensWithdrawn(address indexed to, uint256 amount);
    event MintPriceUpdated(uint256 oldPrice, uint256 newPrice);
    event TokenMintPriceUpdated(uint256 oldPrice, uint256 newPrice);
    event PaymentTokenUpdated(address indexed oldToken, address indexed newToken);
    event TokenMinted(address indexed to, uint256 indexed tokenId, string paymentMethod);

    event TokenURIUpdated(uint256 indexed tokenId, string newURI);

    // ============ Custom Errors ============

    error InvalidAddress();
    error InvalidParameters();
    error InsufficientBalance();
    error WithdrawalFailed();
    error TokenTransferFailed();
    error ERC20PaymentNotEnabled();
    error ProposalNotFound();
    error ProposalExpired();
    error ProposalAlreadyExecuted();
    error AlreadyVoted();
    error QuorumNotReached();
    error AdminAlreadyExists();
    error AdminDoesNotExist();
    error LastAdminCannotBeRemoved();

    // ============ Modifiers ============

    modifier validAddress(address address_) {
        if (address_ == address(0)) revert InvalidAddress();
        _;
    }

    modifier proposalExists(uint256 proposalId_) {
        if (_proposals[proposalId_].id == 0) revert ProposalNotFound();
        _;
    }

    modifier validAmount(uint256 amount_) {
        if (amount_ <= 0) revert InvalidParameters();
        _;
    }

    // ============ Constructor ============

    /**
     * @dev Constructor sets up collection
     * @param name_ Collection name
     * @param symbol_ Collection symbol
     * @param mintPrice_ Price in native tokens to mint one NFT
     * @param tokenMintPrice_ Price in ERC20 tokens to mint one NFT
     * @param paymentToken_ Address of ERC20 token for payments (address(0) if not using ERC20)
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 mintPrice_,
        uint256 tokenMintPrice_,
        address paymentToken_
    ) ERC721(name_, symbol_) {
        mintPrice = mintPrice_;
        tokenMintPrice = tokenMintPrice_;
        paymentToken = paymentToken_;

        // Initialize admin system
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _admins.push(msg.sender);
        quorumThreshold = 1;

        emit AdminAdded(msg.sender);
    }

    // ============ Public Minting Functions ============

    /**
     * @dev Mint NFT with native currency payment and custom photo
     * @param ipfsURI_ IPFS URI for the pet photo (ipfs://...)
     * @return tokenId The ID of the minted token
     */
    function mint(string calldata ipfsURI_) external payable returns (uint256) {
        if (bytes(ipfsURI_).length == 0) revert InvalidParameters();
        if (msg.value < mintPrice) revert InsufficientBalance();

        uint256 tokenId = _tokenIdCounter;
        unchecked {
            ++_tokenIdCounter;
        }

        // Store individual IPFS URI for this token
        _tokenURIs[tokenId] = ipfsURI_;

        _safeMint(msg.sender, tokenId);
        emit TokenMinted(msg.sender, tokenId, "ETH");
        return tokenId;
    }

    /**
     * @dev Mint NFT with ERC20 token payment and custom photo
     * @param ipfsURI_ IPFS URI for the pet photo (ipfs://...)
     * @return tokenId The ID of the minted token
     */
    function mintWithToken(string calldata ipfsURI_) external returns (uint256) {
        if (bytes(ipfsURI_).length == 0) revert InvalidParameters();
        if (paymentToken == address(0) || tokenMintPrice == 0) revert ERC20PaymentNotEnabled();

        IERC20 token = IERC20(paymentToken);
        token.safeTransferFrom(msg.sender, address(this), tokenMintPrice);

        uint256 tokenId = _tokenIdCounter;
        unchecked {
            ++_tokenIdCounter;
        }

        // Store individual IPFS URI for this token
        _tokenURIs[tokenId] = ipfsURI_;

        _safeMint(msg.sender, tokenId);
        emit TokenMinted(msg.sender, tokenId, "ERC20");
        return tokenId;
    }

    // ============ Proposal Creation Functions ============

    /**
     * @dev Create proposal to add admin
     */
    function createAddAdminProposal(address admin_)
        external
        onlyRole(ADMIN_ROLE)
        validAddress(admin_)
        returns (uint256)
    {
        if (hasRole(ADMIN_ROLE, admin_)) revert AdminAlreadyExists();
        return _createProposal(ProposalType.AddAdmin, admin_, 0);
    }

    /**
     * @dev Create proposal to remove admin
     */
    function createRemoveAdminProposal(address admin_)
        external
        onlyRole(ADMIN_ROLE)
        validAddress(admin_)
        returns (uint256)
    {
        if (!hasRole(ADMIN_ROLE, admin_)) revert AdminDoesNotExist();
        if (_admins.length <= 1) revert LastAdminCannotBeRemoved();
        return _createProposal(ProposalType.RemoveAdmin, admin_, 0);
    }

    /**
     * @dev Create proposal to withdraw native tokens
     */
    function createWithdrawFundsProposal(address to_, uint256 amount_)
        external
        onlyRole(ADMIN_ROLE)
        validAddress(to_)
        returns (uint256)
    {
        return _createProposal(ProposalType.WithdrawFunds, to_, amount_);
    }

    /**
     * @dev Create proposal to withdraw ERC20 tokens
     */
    function createWithdrawTokensProposal(address to_, uint256 amount_)
        external
        onlyRole(ADMIN_ROLE)
        validAddress(to_)
        returns (uint256)
    {
        return _createProposal(ProposalType.WithdrawTokens, to_, amount_);
    }

    /**
     * @dev Create proposal to set mint price
     */
    function createSetMintPriceProposal(uint256 newPrice_) external onlyRole(ADMIN_ROLE) returns (uint256) {
        return _createProposal(ProposalType.SetMintPrice, address(0), newPrice_);
    }

    /**
     * @dev Create proposal to set token mint price
     */
    function createSetTokenFeeProposal(uint256 newFee_) external onlyRole(ADMIN_ROLE) returns (uint256) {
        return _createProposal(ProposalType.SetTokenFee, address(0), newFee_);
    }

    /**
     * @dev Create proposal to set payment token
     */
    function createSetPaymentTokenProposal(address newToken_) external onlyRole(ADMIN_ROLE) returns (uint256) {
        return _createProposal(ProposalType.SetPaymentToken, newToken_, 0);
    }

    /**
     * @dev Update individual token URI (admin only, for moderation)
     * @param tokenId_ Token ID to update
     * @param newURI_ New IPFS URI for the token
     */
    function updateTokenURI(uint256 tokenId_, string calldata newURI_) external onlyRole(ADMIN_ROLE) {
        if (tokenId_ == 0 || tokenId_ >= _tokenIdCounter) revert InvalidParameters();
        if (bytes(newURI_).length == 0) revert InvalidParameters();
        _tokenURIs[tokenId_] = newURI_;
        emit TokenURIUpdated(tokenId_, newURI_);
    }

    // ============ Voting Functions ============

    /**
     * @dev Vote for existing proposal
     */
    function voteForProposal(uint256 proposalId_) external onlyRole(ADMIN_ROLE) proposalExists(proposalId_) {
        Proposal storage proposal = _proposals[proposalId_];

        if (proposal.executed) revert ProposalAlreadyExecuted();
        if (block.timestamp > proposal.expirationTime) revert ProposalExpired();
        if (proposal.hasVoted[msg.sender]) revert AlreadyVoted();

        // Record vote
        proposal.hasVoted[msg.sender] = true;
        unchecked {
            ++proposal.approvalCount;
        }

        emit ProposalVoted(proposalId_, msg.sender);

        // Execute if quorum reached
        if (proposal.approvalCount >= quorumThreshold) {
            proposal.executed = true;
            _executeProposal(proposal.proposalType, proposal.targetAddress, proposal.value);
            emit ProposalExecuted(proposalId_, proposal.proposalType);
        }
    }

    // ============ View Functions ============

    /**
     * @dev Get proposal details
     */
    function getProposalDetails(uint256 proposalId_)
        external
        view
        proposalExists(proposalId_)
        returns (
            address proposer,
            uint256 createdAt,
            uint256 approvalCount,
            uint256 expirationTime,
            bool executed,
            ProposalType proposalType,
            address targetAddress,
            uint256 value
        )
    {
        Proposal storage proposal = _proposals[proposalId_];
        return (
            proposal.proposer,
            proposal.createdAt,
            proposal.approvalCount,
            proposal.expirationTime,
            proposal.executed,
            proposal.proposalType,
            proposal.targetAddress,
            proposal.value
        );
    }

    /**
     * @dev Check if admin has voted for proposal
     */
    function hasVotedForProposal(uint256 proposalId_, address admin_)
        external
        view
        proposalExists(proposalId_)
        returns (bool)
    {
        return _proposals[proposalId_].hasVoted[admin_];
    }

    /**
     * @dev Get current admin addresses
     */
    function getAdmins() external view returns (address[] memory) {
        return _admins;
    }

    /**
     * @dev Get total number of proposals created
     */
    function getTotalProposals() external view returns (uint256) {
        return _proposalCounter;
    }

    /**
     * @dev Get total supply of minted tokens
     */
    function totalSupply() public view returns (uint256) {
        return _tokenIdCounter - 1;
    }

    // ============ Override Functions ============

    /**
     * @dev Override tokenURI to return individual IPFS URIs
     */
    function tokenURI(uint256 tokenId_) public view override returns (string memory) {
        if (tokenId_ == 0 || tokenId_ >= _tokenIdCounter) revert InvalidParameters();

        string memory individualURI = _tokenURIs[tokenId_];
        if (bytes(individualURI).length == 0) revert InvalidParameters();

        return individualURI;
    }

    function supportsInterface(bytes4 interfaceId_) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId_);
    }

    // ============ Internal Functions ============

    /**
     * @dev Create new proposal with auto-approval from creator
     */
    function _createProposal(ProposalType proposalType_, address targetAddress_, uint256 value_)
        internal
        returns (uint256)
    {
        unchecked {
            ++_proposalCounter;
        }
        uint256 proposalId = _proposalCounter;

        Proposal storage proposal = _proposals[proposalId];
        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.createdAt = block.timestamp;
        proposal.expirationTime = block.timestamp + PROPOSAL_DURATION;
        proposal.proposalType = proposalType_;
        proposal.targetAddress = targetAddress_;
        proposal.value = value_;
        proposal.hasVoted[msg.sender] = true;
        proposal.approvalCount = 1;

        emit ProposalCreated(proposalId, proposalType_, msg.sender);

        // Auto-execute if single admin or quorum = 1
        if (quorumThreshold == 1) {
            proposal.executed = true;
            _executeProposal(proposalType_, targetAddress_, value_);
            emit ProposalExecuted(proposalId, proposalType_);
        }

        return proposalId;
    }

    /**
     * @dev Execute approved proposal
     */
    function _executeProposal(ProposalType proposalType_, address targetAddress_, uint256 value_) internal {
        if (proposalType_ == ProposalType.AddAdmin) {
            _executeAddAdmin(targetAddress_);
        } else if (proposalType_ == ProposalType.RemoveAdmin) {
            _executeRemoveAdmin(targetAddress_);
        } else if (proposalType_ == ProposalType.WithdrawFunds) {
            _executeWithdrawFunds(targetAddress_, value_);
        } else if (proposalType_ == ProposalType.WithdrawTokens) {
            _executeWithdrawTokens(targetAddress_, value_);
        } else if (proposalType_ == ProposalType.SetMintPrice) {
            _executeSetMintPrice(value_);
        } else if (proposalType_ == ProposalType.SetTokenFee) {
            _executeSetTokenFee(value_);
        } else if (proposalType_ == ProposalType.SetPaymentToken) {
            _executeSetPaymentToken(targetAddress_);
        }
    }

    /**
     * @dev Update quorum threshold based on admin count
     */
    function _updateQuorumThreshold() internal {
        uint256 adminCount = _admins.length;
        uint256 threshold;

        if (adminCount <= 1) {
            threshold = 1;
        } else {
            // Calculate 75% using ceiling division
            threshold = Math.ceilDiv(adminCount * QUORUM_PERCENTAGE, 100);
        }

        quorumThreshold = threshold;
        emit QuorumUpdated(threshold);
    }

    // ============ Execution Functions ============

    function _executeAddAdmin(address admin_) internal {
        _grantRole(ADMIN_ROLE, admin_);
        _admins.push(admin_);
        _updateQuorumThreshold();
        emit AdminAdded(admin_);
    }

    function _executeRemoveAdmin(address admin_) internal {
        // Remove from admins array
        for (uint256 i = 0; i < _admins.length; i++) {
            if (_admins[i] == admin_) {
                _admins[i] = _admins[_admins.length - 1];
                _admins.pop();
                break;
            }
        }

        _revokeRole(ADMIN_ROLE, admin_);
        _updateQuorumThreshold();
        emit AdminRemoved(admin_);
    }

    function _executeWithdrawFunds(address to_, uint256 amount_) internal validAddress(to_) validAmount(amount_) {
        uint256 balance = address(this).balance;
        if (balance < amount_) revert InsufficientBalance();

        (bool success,) = payable(to_).call{value: amount_}("");
        if (!success) revert WithdrawalFailed();
        emit FundsWithdrawn(to_, amount_);
    }

    function _executeWithdrawTokens(address to_, uint256 amount_) internal validAddress(to_) validAmount(amount_) {
        if (paymentToken == address(0)) revert ERC20PaymentNotEnabled();

        IERC20 token = IERC20(paymentToken);
        uint256 balance = token.balanceOf(address(this));

        if (balance < amount_) revert InsufficientBalance();

        token.safeTransfer(to_, amount_);
        emit TokensWithdrawn(to_, amount_);
    }

    function _executeSetMintPrice(uint256 newPrice_) internal {
        uint256 oldPrice = mintPrice;
        mintPrice = newPrice_;
        emit MintPriceUpdated(oldPrice, newPrice_);
    }

    function _executeSetTokenFee(uint256 newFee_) internal {
        uint256 oldPrice = tokenMintPrice;
        tokenMintPrice = newFee_;
        emit TokenMintPriceUpdated(oldPrice, newFee_);
    }

    function _executeSetPaymentToken(address newToken_) internal {
        address oldToken = paymentToken;
        paymentToken = newToken_;
        emit PaymentTokenUpdated(oldToken, newToken_);
    }

    // ============ Receive Function ============

    /**
     * @dev Allow contract to receive ETH
     */
    receive() external payable {
        // Allow contract to receive ETH for minting and other operations
    }
}
