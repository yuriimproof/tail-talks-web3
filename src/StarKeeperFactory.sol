// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {StarKeeper} from "./StarKeeper.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title StarKeeperFactory
 * @dev Factory contract for creating and managing StarKeeper collections
 * Implements 75% quorum governance for all admin operations
 */
contract StarKeeperFactory is AccessControl {
    // ============ Constants ============

    bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint256 private constant PROPOSAL_DURATION = 7 days;
    uint256 private constant QUORUM_PERCENTAGE = 75; // 75%

    // ============ Structs & Enums ============

    struct Proposal {
        uint256 id;
        address proposer;
        uint256 createdAt;
        uint256 approvalCount;
        uint256 expirationTime;
        bool executed;
        FunctionType functionType;
        bytes functionData;
        mapping(address => bool) hasVoted;
    }

    enum FunctionType {
        CreateCollection,
        AddFactoryAdmin,
        RemoveFactoryAdmin,
        SetBaseURI,
        SetMintPrice,
        SetTokenMintPrice,
        SetPaymentToken,
        SetCollectionImageURI,
        WithdrawFunds,
        WithdrawTokens,
        SetMaxSupply,
        MintToAddress
    }

    // ============ State Variables ============

    // Collections tracking
    StarKeeper[] private collections;
    mapping(address => StarKeeper[]) private creatorCollections;
    mapping(address => bool) private validCollections;

    // Governance
    address[] private admins;
    uint256 public quorumThreshold;

    // Proposals
    uint256 public proposalCounter;
    mapping(uint256 => Proposal) private proposals;

    // ============ Events ============

    event CollectionCreated(
        address indexed creator,
        address indexed collectionAddress,
        string name,
        uint256 maxSupply,
        uint256 mintPrice,
        address paymentToken,
        uint256 tokenMintPrice,
        string collectionImageURI
    );

    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
    event QuorumUpdated(uint256 newThreshold);
    event AdminsInitialized(uint256 adminCount, uint256 quorumThreshold);

    event ProposalCreated(uint256 indexed proposalId, FunctionType functionType, address indexed proposer);
    event ProposalVoted(uint256 indexed proposalId, address indexed voter);
    event ProposalExecuted(uint256 indexed proposalId, FunctionType functionType);

    event BaseURIUpdated(address indexed collection, string newURI);
    event MintPriceUpdated(address indexed collection, uint256 newPrice);
    event TokenMintPriceUpdated(address indexed collection, uint256 newPrice);
    event PaymentTokenUpdated(address indexed collection, address newToken);
    event CollectionImageURIUpdated(address indexed collection, string newURI);
    event MaxSupplyUpdated(address indexed collection, uint256 newMaxSupply);
    event TokenMinted(address indexed collection, address indexed to, uint256 tokenId);
    event FundsWithdrawn(address indexed collection, address indexed to, uint256 amount);
    event TokensWithdrawn(address indexed collection, address indexed to);

    // ============ Custom Errors ============

    error InvalidAdminAddress();
    error InvalidMaxSupply();
    error InvalidCollectionAddress();
    error LastAdminCannotBeRemoved();
    error AdminAlreadyExists();
    error AdminDoesNotExist();
    error ProposalNotFound();
    error ProposalAlreadyExecuted();
    error ProposalExpired();
    error AlreadyVoted();
    error CollectionOperationFailed();

    // ============ Modifiers ============

    modifier validAddress(address _address) {
        if (_address == address(0)) revert InvalidAdminAddress();
        _;
    }

    modifier validCollection(address _collection) {
        if (!validCollections[_collection]) revert InvalidCollectionAddress();
        _;
    }

    modifier proposalExists(uint256 _proposalId) {
        if (proposals[_proposalId].id == 0) revert ProposalNotFound();
        _;
    }

    // ============ Constructor ============

    /**
     * @dev Initialize factory with admin governance
     * @param _admins Initial admin addresses
     */
    constructor(address[] memory _admins) {
        if (_admins.length == 0) revert InvalidAdminAddress();

        for (uint256 i = 0; i < _admins.length; i++) {
            if (_admins[i] == address(0)) revert InvalidAdminAddress();
            _grantRole(ADMIN_ROLE, _admins[i]);
            admins.push(_admins[i]);
        }

        _updateQuorumThreshold();
        emit AdminsInitialized(_admins.length, quorumThreshold);
    }

    // ============ Proposal Creation Functions ============

    /**
     * @dev Create proposal to deploy new collection
     */
    function createCollectionProposal(
        string calldata _name,
        string calldata _symbol,
        uint256 _maxSupply,
        uint256 _mintPrice,
        uint256 _tokenMintPrice,
        address _paymentToken,
        string calldata _baseTokenURI,
        string calldata _collectionImageURI
    ) external onlyRole(ADMIN_ROLE) returns (uint256) {
        if (_maxSupply == 0) revert InvalidMaxSupply();

        bytes memory functionData = abi.encode(
            _name, _symbol, _maxSupply, _mintPrice, _tokenMintPrice, _paymentToken, _baseTokenURI, _collectionImageURI
        );

        return _createProposal(FunctionType.CreateCollection, functionData);
    }

    /**
     * @dev Create proposal to add factory admin
     */
    function createAddAdminProposal(address _admin)
        external
        onlyRole(ADMIN_ROLE)
        validAddress(_admin)
        returns (uint256)
    {
        if (hasRole(ADMIN_ROLE, _admin)) revert AdminAlreadyExists();

        return _createProposal(FunctionType.AddFactoryAdmin, abi.encode(_admin));
    }

    /**
     * @dev Create proposal to remove factory admin
     */
    function createRemoveAdminProposal(address _admin)
        external
        onlyRole(ADMIN_ROLE)
        validAddress(_admin)
        returns (uint256)
    {
        if (!hasRole(ADMIN_ROLE, _admin)) revert AdminDoesNotExist();
        if (admins.length <= 1) revert LastAdminCannotBeRemoved();

        return _createProposal(FunctionType.RemoveFactoryAdmin, abi.encode(_admin));
    }

    /**
     * @dev Create proposal to update collection base URI
     */
    function createSetBaseURIProposal(address _collection, string calldata _newBaseURI)
        external
        onlyRole(ADMIN_ROLE)
        validCollection(_collection)
        returns (uint256)
    {
        return _createProposal(FunctionType.SetBaseURI, abi.encode(_collection, _newBaseURI));
    }

    /**
     * @dev Create proposal to update collection mint price
     */
    function createSetMintPriceProposal(address _collection, uint256 _newPrice)
        external
        onlyRole(ADMIN_ROLE)
        validCollection(_collection)
        returns (uint256)
    {
        return _createProposal(FunctionType.SetMintPrice, abi.encode(_collection, _newPrice));
    }

    /**
     * @dev Create proposal to update collection token mint price
     */
    function createSetTokenMintPriceProposal(address _collection, uint256 _newPrice)
        external
        onlyRole(ADMIN_ROLE)
        validCollection(_collection)
        returns (uint256)
    {
        return _createProposal(FunctionType.SetTokenMintPrice, abi.encode(_collection, _newPrice));
    }

    /**
     * @dev Create proposal to update collection payment token
     */
    function createSetPaymentTokenProposal(address _collection, address _newToken)
        external
        onlyRole(ADMIN_ROLE)
        validCollection(_collection)
        returns (uint256)
    {
        return _createProposal(FunctionType.SetPaymentToken, abi.encode(_collection, _newToken));
    }

    /**
     * @dev Create proposal to update collection image URI
     */
    function createSetImageURIProposal(address _collection, string calldata _newImageURI)
        external
        onlyRole(ADMIN_ROLE)
        validCollection(_collection)
        returns (uint256)
    {
        return _createProposal(FunctionType.SetCollectionImageURI, abi.encode(_collection, _newImageURI));
    }

    /**
     * @dev Create proposal to update collection max supply
     */
    function createSetMaxSupplyProposal(address _collection, uint256 _newMaxSupply)
        external
        onlyRole(ADMIN_ROLE)
        validCollection(_collection)
        returns (uint256)
    {
        return _createProposal(FunctionType.SetMaxSupply, abi.encode(_collection, _newMaxSupply));
    }

    /**
     * @dev Create proposal to mint token to specific address
     */
    function createMintToProposal(address _collection, address _to)
        external
        onlyRole(ADMIN_ROLE)
        validCollection(_collection)
        validAddress(_to)
        returns (uint256)
    {
        return _createProposal(FunctionType.MintToAddress, abi.encode(_collection, _to));
    }

    /**
     * @dev Create proposal to withdraw native tokens from collection
     */
    function createWithdrawFundsProposal(address _collection, address _to, uint256 _amount)
        external
        onlyRole(ADMIN_ROLE)
        validCollection(_collection)
        validAddress(_to)
        returns (uint256)
    {
        return _createProposal(FunctionType.WithdrawFunds, abi.encode(_collection, _to, _amount));
    }

    /**
     * @dev Create proposal to withdraw ERC20 tokens from collection
     */
    function createWithdrawTokensProposal(address _collection, address _to)
        external
        onlyRole(ADMIN_ROLE)
        validCollection(_collection)
        validAddress(_to)
        returns (uint256)
    {
        return _createProposal(FunctionType.WithdrawTokens, abi.encode(_collection, _to));
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
            _executeProposal(proposal.functionType, proposal.functionData);
            emit ProposalExecuted(_proposalId, proposal.functionType);
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
            FunctionType functionType
        )
    {
        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.proposer,
            proposal.createdAt,
            proposal.approvalCount,
            proposal.expirationTime,
            proposal.executed,
            proposal.functionType
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
     * @dev Get proposal function data
     */
    function getProposalFunctionData(uint256 _proposalId)
        external
        view
        proposalExists(_proposalId)
        returns (bytes memory)
    {
        return proposals[_proposalId].functionData;
    }

    /**
     * @dev Get all collections created by factory
     */
    function getAllCollections() external view returns (StarKeeper[] memory) {
        return collections;
    }

    /**
     * @dev Get collections created by specific address
     */
    function getCreatorCollections(address _creator) external view returns (StarKeeper[] memory) {
        return creatorCollections[_creator];
    }

    /**
     * @dev Check if collection was created by this factory
     */
    function isCollectionFromFactory(address _collection) external view returns (bool) {
        return validCollections[_collection];
    }

    /**
     * @dev Get current admin addresses
     */
    function getAdmins() external view returns (address[] memory) {
        return admins;
    }

    // ============ Internal Functions ============

    /**
     * @dev Create new proposal with auto-approval from creator
     */
    function _createProposal(FunctionType _functionType, bytes memory _functionData) internal returns (uint256) {
        unchecked {
            ++proposalCounter;
        }
        uint256 proposalId = proposalCounter;

        Proposal storage proposal = proposals[proposalId];
        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.createdAt = block.timestamp;
        proposal.expirationTime = block.timestamp + PROPOSAL_DURATION;
        proposal.functionType = _functionType;
        proposal.functionData = _functionData;
        proposal.hasVoted[msg.sender] = true;
        proposal.approvalCount = 1;

        emit ProposalCreated(proposalId, _functionType, msg.sender);

        // Auto-execute if single admin or quorum = 1
        if (quorumThreshold == 1) {
            proposal.executed = true;
            _executeProposal(_functionType, _functionData);
            emit ProposalExecuted(proposalId, _functionType);
        }

        return proposalId;
    }

    /**
     * @dev Execute approved proposal
     */
    function _executeProposal(FunctionType _functionType, bytes memory _functionData) internal {
        if (_functionType == FunctionType.CreateCollection) {
            _executeCreateCollection(_functionData);
        } else if (_functionType == FunctionType.AddFactoryAdmin) {
            _executeAddAdmin(_functionData);
        } else if (_functionType == FunctionType.RemoveFactoryAdmin) {
            _executeRemoveAdmin(_functionData);
        } else if (_functionType == FunctionType.SetBaseURI) {
            _executeSetBaseURI(_functionData);
        } else if (_functionType == FunctionType.SetMintPrice) {
            _executeSetMintPrice(_functionData);
        } else if (_functionType == FunctionType.SetTokenMintPrice) {
            _executeSetTokenMintPrice(_functionData);
        } else if (_functionType == FunctionType.SetPaymentToken) {
            _executeSetPaymentToken(_functionData);
        } else if (_functionType == FunctionType.SetCollectionImageURI) {
            _executeSetImageURI(_functionData);
        } else if (_functionType == FunctionType.SetMaxSupply) {
            _executeSetMaxSupply(_functionData);
        } else if (_functionType == FunctionType.MintToAddress) {
            _executeMintTo(_functionData);
        } else if (_functionType == FunctionType.WithdrawFunds) {
            _executeWithdrawFunds(_functionData);
        } else if (_functionType == FunctionType.WithdrawTokens) {
            _executeWithdrawTokens(_functionData);
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

    function _executeCreateCollection(bytes memory _functionData) internal {
        (
            string memory name,
            string memory symbol,
            uint256 maxSupply,
            uint256 mintPrice,
            uint256 tokenMintPrice,
            address paymentToken,
            string memory baseTokenURI,
            string memory collectionImageURI
        ) = abi.decode(_functionData, (string, string, uint256, uint256, uint256, address, string, string));

        StarKeeper newCollection = new StarKeeper(
            name, symbol, maxSupply, mintPrice, tokenMintPrice, paymentToken, baseTokenURI, collectionImageURI
        );

        address collectionAddress = address(newCollection);
        collections.push(newCollection);
        creatorCollections[msg.sender].push(newCollection);
        validCollections[collectionAddress] = true;

        emit CollectionCreated(
            msg.sender, collectionAddress, name, maxSupply, mintPrice, paymentToken, tokenMintPrice, collectionImageURI
        );
    }

    function _executeAddAdmin(bytes memory _functionData) internal {
        address admin = abi.decode(_functionData, (address));

        _grantRole(ADMIN_ROLE, admin);
        admins.push(admin);
        _updateQuorumThreshold();

        emit AdminAdded(admin);
    }

    function _executeRemoveAdmin(bytes memory _functionData) internal {
        address admin = abi.decode(_functionData, (address));

        // Remove from admins array
        for (uint256 i = 0; i < admins.length; i++) {
            if (admins[i] == admin) {
                admins[i] = admins[admins.length - 1];
                admins.pop();
                break;
            }
        }

        _revokeRole(ADMIN_ROLE, admin);
        _updateQuorumThreshold();

        emit AdminRemoved(admin);
    }

    function _executeSetBaseURI(bytes memory _functionData) internal {
        (address collectionAddress, string memory newBaseURI) = abi.decode(_functionData, (address, string));

        try StarKeeper(collectionAddress).setBaseURI(newBaseURI) {
            emit BaseURIUpdated(collectionAddress, newBaseURI);
        } catch {
            revert CollectionOperationFailed();
        }
    }

    function _executeSetMintPrice(bytes memory _functionData) internal {
        (address collectionAddress, uint256 newPrice) = abi.decode(_functionData, (address, uint256));

        try StarKeeper(collectionAddress).setMintPrice(newPrice) {
            emit MintPriceUpdated(collectionAddress, newPrice);
        } catch {
            revert CollectionOperationFailed();
        }
    }

    function _executeSetTokenMintPrice(bytes memory _functionData) internal {
        (address collectionAddress, uint256 newPrice) = abi.decode(_functionData, (address, uint256));

        try StarKeeper(collectionAddress).setTokenMintPrice(newPrice) {
            emit TokenMintPriceUpdated(collectionAddress, newPrice);
        } catch {
            revert CollectionOperationFailed();
        }
    }

    function _executeSetPaymentToken(bytes memory _functionData) internal {
        (address collectionAddress, address newToken) = abi.decode(_functionData, (address, address));

        try StarKeeper(collectionAddress).setPaymentToken(newToken) {
            emit PaymentTokenUpdated(collectionAddress, newToken);
        } catch {
            revert CollectionOperationFailed();
        }
    }

    function _executeSetImageURI(bytes memory _functionData) internal {
        (address collectionAddress, string memory newImageURI) = abi.decode(_functionData, (address, string));

        try StarKeeper(collectionAddress).setCollectionImageURI(newImageURI) {
            emit CollectionImageURIUpdated(collectionAddress, newImageURI);
        } catch {
            revert CollectionOperationFailed();
        }
    }

    function _executeSetMaxSupply(bytes memory _functionData) internal {
        (address collectionAddress, uint256 newMaxSupply) = abi.decode(_functionData, (address, uint256));

        try StarKeeper(collectionAddress).setMaxSupply(newMaxSupply) {
            emit MaxSupplyUpdated(collectionAddress, newMaxSupply);
        } catch {
            revert CollectionOperationFailed();
        }
    }

    function _executeMintTo(bytes memory _functionData) internal {
        (address collectionAddress, address recipient) = abi.decode(_functionData, (address, address));

        try StarKeeper(collectionAddress).mintTo(recipient) returns (uint256 tokenId) {
            emit TokenMinted(collectionAddress, recipient, tokenId);
        } catch {
            revert CollectionOperationFailed();
        }
    }

    function _executeWithdrawFunds(bytes memory _functionData) internal {
        (address collectionAddress, address recipient, uint256 amount) =
            abi.decode(_functionData, (address, address, uint256));

        try StarKeeper(collectionAddress).withdrawFunds(payable(recipient), amount) {
            emit FundsWithdrawn(collectionAddress, recipient, amount);
        } catch {
            revert CollectionOperationFailed();
        }
    }

    function _executeWithdrawTokens(bytes memory _functionData) internal {
        (address collectionAddress, address recipient) = abi.decode(_functionData, (address, address));

        try StarKeeper(collectionAddress).withdrawTokens(recipient) {
            emit TokensWithdrawn(collectionAddress, recipient);
        } catch {
            revert CollectionOperationFailed();
        }
    }
}
