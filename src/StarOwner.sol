// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title StarOwner
 * @dev NFT contract for pet images with multi-admin governance
 */
contract StarOwner is ERC721Enumerable, AccessControl {
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
    uint256 private tokenIdCounter = 1;
    mapping(uint256 tokenId => string ipfsURI) private tokenURIs; // Individual IPFS URIs for each token

    // Pricing
    uint256 public mintPrice;
    uint256 public tokenMintPrice;
    address public paymentToken;

    // Governance
    address[] private admins;
    uint256 public quorumThreshold;

    // Proposals
    uint256 private proposalCounter;
    mapping(uint256 => Proposal) private proposals;

    // ============ Events ============

    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
    event QuorumUpdated(uint256 newThreshold);

    event ProposalCreated(uint256 indexed proposalId, ProposalType proposalType, address indexed proposer);
    event ProposalVoted(uint256 indexed proposalId, address indexed voter);
    event ProposalExecuted(uint256 indexed proposalId, ProposalType proposalType);

    event FundsWithdrawn(address indexed to, uint256 amount);
    event TokensWithdrawn(address indexed to, uint256 amount);
    event MintPriceUpdated(uint256 newPrice);
    event TokenMintPriceUpdated(uint256 newPrice);
    event PaymentTokenUpdated(address newToken);
    event TokenMinted(address indexed to, uint256 indexed tokenId, string paymentMethod);

    event TokenURIUpdated(uint256 tokenId, string newURI);

    // ============ Custom Errors ============

    error InvalidAddress();
    error InvalidParameters();
    error InsufficientPayment();
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

    modifier validAddress(address _address) {
        if (_address == address(0)) revert InvalidAddress();
        _;
    }

    modifier proposalExists(uint256 _proposalId) {
        if (proposals[_proposalId].id == 0) revert ProposalNotFound();
        _;
    }

    // ============ Constructor ============

    /**
     * @dev Constructor sets up collection
     * @param _name Collection name
     * @param _symbol Collection symbol
     * @param _mintPrice Price in native tokens to mint one NFT
     * @param _tokenMintPrice Price in ERC20 tokens to mint one NFT
     * @param _paymentToken Address of ERC20 token for payments (address(0) if not using ERC20)
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _mintPrice,
        uint256 _tokenMintPrice,
        address _paymentToken
    ) ERC721(_name, _symbol) {
        mintPrice = _mintPrice;
        tokenMintPrice = _tokenMintPrice;
        paymentToken = _paymentToken;

        // Initialize admin system
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        admins.push(msg.sender);
        quorumThreshold = 1;

        emit AdminAdded(msg.sender);
    }

    // ============ Public Minting Functions ============

    /**
     * @dev Mint NFT with native currency payment and custom photo
     * @param ipfsURI IPFS URI for the pet photo (ipfs://...)
     * @return tokenId The ID of the minted token
     */
    function mint(string calldata ipfsURI) external payable returns (uint256) {
        if (bytes(ipfsURI).length == 0) revert InvalidParameters();
        if (msg.value < mintPrice) revert InsufficientPayment();

        uint256 tokenId = tokenIdCounter;
        unchecked {
            ++tokenIdCounter;
        }

        // Store individual IPFS URI for this token
        tokenURIs[tokenId] = ipfsURI;

        _safeMint(msg.sender, tokenId);
        emit TokenMinted(msg.sender, tokenId, "ETH");
        return tokenId;
    }

    /**
     * @dev Mint NFT with ERC20 token payment and custom photo
     * @param ipfsURI IPFS URI for the pet photo (ipfs://...)
     * @return tokenId The ID of the minted token
     */
    function mintWithToken(string calldata ipfsURI) external returns (uint256) {
        if (bytes(ipfsURI).length == 0) revert InvalidParameters();
        if (paymentToken == address(0) || tokenMintPrice == 0) revert ERC20PaymentNotEnabled();

        IERC20 token = IERC20(paymentToken);
        if (!token.transferFrom(msg.sender, address(this), tokenMintPrice)) {
            revert TokenTransferFailed();
        }

        uint256 tokenId = tokenIdCounter;
        unchecked {
            ++tokenIdCounter;
        }

        // Store individual IPFS URI for this token
        tokenURIs[tokenId] = ipfsURI;

        _safeMint(msg.sender, tokenId);
        emit TokenMinted(msg.sender, tokenId, "ERC20");
        return tokenId;
    }

    // ============ Proposal Creation Functions ============

    /**
     * @dev Create proposal to add admin
     */
    function createAddAdminProposal(address _admin)
        external
        onlyRole(ADMIN_ROLE)
        validAddress(_admin)
        returns (uint256)
    {
        if (hasRole(ADMIN_ROLE, _admin)) revert AdminAlreadyExists();
        return _createProposal(ProposalType.AddAdmin, _admin, 0);
    }

    /**
     * @dev Create proposal to remove admin
     */
    function createRemoveAdminProposal(address _admin)
        external
        onlyRole(ADMIN_ROLE)
        validAddress(_admin)
        returns (uint256)
    {
        if (!hasRole(ADMIN_ROLE, _admin)) revert AdminDoesNotExist();
        if (admins.length <= 1) revert LastAdminCannotBeRemoved();
        return _createProposal(ProposalType.RemoveAdmin, _admin, 0);
    }

    /**
     * @dev Create proposal to withdraw native tokens
     */
    function createWithdrawFundsProposal(address _to, uint256 _amount)
        external
        onlyRole(ADMIN_ROLE)
        validAddress(_to)
        returns (uint256)
    {
        return _createProposal(ProposalType.WithdrawFunds, _to, _amount);
    }

    /**
     * @dev Create proposal to withdraw ERC20 tokens
     */
    function createWithdrawTokensProposal(address _to)
        external
        onlyRole(ADMIN_ROLE)
        validAddress(_to)
        returns (uint256)
    {
        return _createProposal(ProposalType.WithdrawTokens, _to, 0);
    }

    /**
     * @dev Create proposal to set mint price
     */
    function createSetMintPriceProposal(uint256 _newPrice) external onlyRole(ADMIN_ROLE) returns (uint256) {
        return _createProposal(ProposalType.SetMintPrice, address(0), _newPrice);
    }

    /**
     * @dev Create proposal to set token mint price
     */
    function createSetTokenFeeProposal(uint256 _newFee) external onlyRole(ADMIN_ROLE) returns (uint256) {
        return _createProposal(ProposalType.SetTokenFee, address(0), _newFee);
    }

    /**
     * @dev Create proposal to set payment token
     */
    function createSetPaymentTokenProposal(address _newToken) external onlyRole(ADMIN_ROLE) returns (uint256) {
        return _createProposal(ProposalType.SetPaymentToken, _newToken, 0);
    }

    /**
     * @dev Update individual token URI (admin only, for moderation)
     * @param tokenId Token ID to update
     * @param newURI New IPFS URI for the token
     */
    function updateTokenURI(uint256 tokenId, string calldata newURI) external onlyRole(ADMIN_ROLE) {
        if (tokenId == 0 || tokenId >= tokenIdCounter) revert InvalidParameters();
        tokenURIs[tokenId] = newURI;
        emit TokenURIUpdated(tokenId, newURI);
    }

    // ============ Voting Functions ============

    /**
     * @dev Vote for existing proposal
     */
    function voteForProposal(uint256 _proposalId) external onlyRole(ADMIN_ROLE) proposalExists(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];

        if (proposal.executed) revert ProposalAlreadyExecuted();
        if (block.timestamp > proposal.expirationTime) revert ProposalExpired();
        if (proposal.hasVoted[msg.sender]) revert AlreadyVoted();

        // Record vote
        proposal.hasVoted[msg.sender] = true;
        unchecked {
            ++proposal.approvalCount;
        }

        emit ProposalVoted(_proposalId, msg.sender);

        // Execute if quorum reached
        if (proposal.approvalCount >= quorumThreshold) {
            proposal.executed = true;
            _executeProposal(proposal.proposalType, proposal.targetAddress, proposal.value);
            emit ProposalExecuted(_proposalId, proposal.proposalType);
        }
    }

    // ============ View Functions ============

    /**
     * @dev Get proposal details
     */
    function getProposalDetails(uint256 _proposalId)
        external
        view
        proposalExists(_proposalId)
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
        Proposal storage proposal = proposals[_proposalId];
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
    function hasVotedForProposal(uint256 _proposalId, address _admin)
        external
        view
        proposalExists(_proposalId)
        returns (bool)
    {
        return proposals[_proposalId].hasVoted[_admin];
    }

    /**
     * @dev Get current admin addresses
     */
    function getAdmins() external view returns (address[] memory) {
        return admins;
    }

    /**
     * @dev Get contract information in one call
     */
    function getContractInfo()
        external
        view
        returns (
            string memory name_,
            string memory symbol_,
            uint256 totalSupply_,
            uint256 mintPrice_,
            uint256 tokenMintPrice_,
            address paymentToken_,
            uint256 quorumThreshold_,
            uint256 totalProposals_
        )
    {
        return
            (name(), symbol(), totalSupply(), mintPrice, tokenMintPrice, paymentToken, quorumThreshold, proposalCounter);
    }

    /**
     * @dev Get total number of proposals created
     */
    function getTotalProposals() external view returns (uint256) {
        return proposalCounter;
    }

    // ============ Override Functions ============

    /**
     * @dev Override tokenURI to return individual IPFS URIs
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (tokenId == 0 || tokenId >= tokenIdCounter) revert InvalidParameters();

        string memory individualURI = tokenURIs[tokenId];
        if (bytes(individualURI).length == 0) revert InvalidParameters();

        return individualURI;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // ============ Internal Functions ============

    /**
     * @dev Create new proposal with auto-approval from creator
     */
    function _createProposal(ProposalType _proposalType, address _targetAddress, uint256 _value)
        internal
        returns (uint256)
    {
        unchecked {
            ++proposalCounter;
        }
        uint256 proposalId = proposalCounter;

        Proposal storage proposal = proposals[proposalId];
        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.createdAt = block.timestamp;
        proposal.expirationTime = block.timestamp + PROPOSAL_DURATION;
        proposal.proposalType = _proposalType;
        proposal.targetAddress = _targetAddress;
        proposal.value = _value;
        proposal.hasVoted[msg.sender] = true;
        proposal.approvalCount = 1;

        emit ProposalCreated(proposalId, _proposalType, msg.sender);

        // Auto-execute if single admin or quorum = 1
        if (quorumThreshold == 1) {
            proposal.executed = true;
            _executeProposal(_proposalType, _targetAddress, _value);
            emit ProposalExecuted(proposalId, _proposalType);
        }

        return proposalId;
    }

    /**
     * @dev Execute approved proposal
     */
    function _executeProposal(ProposalType _proposalType, address _targetAddress, uint256 _value) internal {
        if (_proposalType == ProposalType.AddAdmin) {
            _executeAddAdmin(_targetAddress);
        } else if (_proposalType == ProposalType.RemoveAdmin) {
            _executeRemoveAdmin(_targetAddress);
        } else if (_proposalType == ProposalType.WithdrawFunds) {
            _executeWithdrawFunds(_targetAddress, _value);
        } else if (_proposalType == ProposalType.WithdrawTokens) {
            _executeWithdrawTokens(_targetAddress);
        } else if (_proposalType == ProposalType.SetMintPrice) {
            _executeSetMintPrice(_value);
        } else if (_proposalType == ProposalType.SetTokenFee) {
            _executeSetTokenFee(_value);
        } else if (_proposalType == ProposalType.SetPaymentToken) {
            _executeSetPaymentToken(_targetAddress);
        }
    }

    /**
     * @dev Update quorum threshold based on admin count
     */
    function _updateQuorumThreshold() internal {
        uint256 adminCount = admins.length;
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

    function _executeAddAdmin(address _admin) internal {
        _grantRole(ADMIN_ROLE, _admin);
        admins.push(_admin);
        _updateQuorumThreshold();
        emit AdminAdded(_admin);
    }

    function _executeRemoveAdmin(address _admin) internal {
        // Remove from admins array
        for (uint256 i = 0; i < admins.length; i++) {
            if (admins[i] == _admin) {
                admins[i] = admins[admins.length - 1];
                admins.pop();
                break;
            }
        }

        _revokeRole(ADMIN_ROLE, _admin);
        _updateQuorumThreshold();
        emit AdminRemoved(_admin);
    }

    function _executeWithdrawFunds(address _to, uint256 _amount) internal {
        uint256 balance = address(this).balance;
        uint256 withdrawAmount = _amount == 0 ? balance : _amount;

        if (withdrawAmount > balance) {
            withdrawAmount = balance;
        }

        (bool success,) = _to.call{value: withdrawAmount}("");
        if (!success) revert WithdrawalFailed();

        emit FundsWithdrawn(_to, withdrawAmount);
    }

    function _executeWithdrawTokens(address _to) internal {
        if (paymentToken == address(0)) revert ERC20PaymentNotEnabled();

        IERC20 token = IERC20(paymentToken);
        uint256 balance = token.balanceOf(address(this));
        if (!token.transfer(_to, balance)) revert TokenTransferFailed();

        emit TokensWithdrawn(_to, balance);
    }

    function _executeSetMintPrice(uint256 _newPrice) internal {
        mintPrice = _newPrice;
        emit MintPriceUpdated(_newPrice);
    }

    function _executeSetTokenFee(uint256 _newFee) internal {
        tokenMintPrice = _newFee;
        emit TokenMintPriceUpdated(_newFee);
    }

    function _executeSetPaymentToken(address _newToken) internal {
        paymentToken = _newToken;
        emit PaymentTokenUpdated(_newToken);
    }
}
