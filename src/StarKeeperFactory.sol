// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {StarKeeper} from "./StarKeeper.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title StarKeeperFactory
 * @dev Factory contract for creating and managing StarKeeper _collections
 * @notice Implements 75% quorum governance for all admin operations and collection management
 * @author Yuri Improof (@yuriimproof) for TailTalks Team
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
    StarKeeper[] private _collections;
    mapping(address => StarKeeper[]) private _creatorCollections;
    mapping(address => bool) private _validCollections;

    // Governance
    address[] private _admins;
    uint256 public quorumThreshold;

    // Proposals
    uint256 public proposalCounter;
    mapping(uint256 => Proposal) private _proposals;

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
    event PaymentTokenUpdated(address indexed collection, address indexed newToken);
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
    error SupplyTooLow();
    error InvalidString();

    // ============ Modifiers ============

    modifier validAddress(address address_) {
        if (address_ == address(0)) revert InvalidAdminAddress();
        _;
    }

    modifier validCollection(address collection_) {
        if (!_validCollections[collection_]) revert InvalidCollectionAddress();
        _;
    }

    modifier proposalExists(uint256 proposalId_) {
        if (_proposals[proposalId_].id == 0) revert ProposalNotFound();
        _;
    }

    modifier validString(string calldata str_) {
        if (bytes(str_).length == 0) revert InvalidString();
        _;
    }

    modifier validSupply(uint256 supply_) {
        if (supply_ < 1) revert SupplyTooLow();
        _;
    }

    // ============ Constructor ============

    /**
     * @dev Initialize factory with admin governance
     * @param admins_ Initial admin addresses
     */
    constructor(address[] memory admins_) {
        if (admins_.length == 0) revert InvalidAdminAddress();

        for (uint256 i = 0; i < admins_.length; i++) {
            if (admins_[i] == address(0)) revert InvalidAdminAddress();
            _grantRole(ADMIN_ROLE, admins_[i]);
            _admins.push(admins_[i]);
        }

        _updateQuorumThreshold();
        emit AdminsInitialized(admins_.length, quorumThreshold);
    }

    // ============ Proposal Creation Functions ============

    /**
     * @dev Create proposal to deploy new collection
     */
    function createCollectionProposal(
        string calldata name_,
        string calldata symbol_,
        uint256 maxSupply_,
        uint256 mintPrice_,
        uint256 tokenMintPrice_,
        address paymentToken_,
        string calldata baseTokenURI_,
        string calldata collectionImageURI_
    ) external onlyRole(ADMIN_ROLE) validString(name_) validString(symbol_) validSupply(maxSupply_) returns (uint256) {
        bytes memory functionData = abi.encode(
            name_, symbol_, maxSupply_, mintPrice_, tokenMintPrice_, paymentToken_, baseTokenURI_, collectionImageURI_
        );

        return _createProposal(FunctionType.CreateCollection, functionData);
    }

    /**
     * @dev Create proposal to add factory admin
     */
    function createAddAdminProposal(address admin_)
        external
        onlyRole(ADMIN_ROLE)
        validAddress(admin_)
        returns (uint256)
    {
        if (hasRole(ADMIN_ROLE, admin_)) revert AdminAlreadyExists();

        return _createProposal(FunctionType.AddFactoryAdmin, abi.encode(admin_));
    }

    /**
     * @dev Create proposal to remove factory admin
     */
    function createRemoveAdminProposal(address admin_)
        external
        onlyRole(ADMIN_ROLE)
        validAddress(admin_)
        returns (uint256)
    {
        if (!hasRole(ADMIN_ROLE, admin_)) revert AdminDoesNotExist();
        if (_admins.length <= 1) revert LastAdminCannotBeRemoved();

        return _createProposal(FunctionType.RemoveFactoryAdmin, abi.encode(admin_));
    }

    /**
     * @dev Create proposal to update collection base URI
     */
    function createSetBaseURIProposal(address collection_, string calldata newBaseURI_)
        external
        onlyRole(ADMIN_ROLE)
        validCollection(collection_)
        validString(newBaseURI_)
        returns (uint256)
    {
        return _createProposal(FunctionType.SetBaseURI, abi.encode(collection_, newBaseURI_));
    }

    /**
     * @dev Create proposal to update collection mint price
     */
    function createSetMintPriceProposal(address collection_, uint256 newPrice_)
        external
        onlyRole(ADMIN_ROLE)
        validCollection(collection_)
        returns (uint256)
    {
        return _createProposal(FunctionType.SetMintPrice, abi.encode(collection_, newPrice_));
    }

    /**
     * @dev Create proposal to update collection token mint price
     */
    function createSetTokenMintPriceProposal(address collection_, uint256 newPrice_)
        external
        onlyRole(ADMIN_ROLE)
        validCollection(collection_)
        returns (uint256)
    {
        return _createProposal(FunctionType.SetTokenMintPrice, abi.encode(collection_, newPrice_));
    }

    /**
     * @dev Create proposal to update collection payment token
     */
    function createSetPaymentTokenProposal(address collection_, address newToken_)
        external
        onlyRole(ADMIN_ROLE)
        validCollection(collection_)
        returns (uint256)
    {
        return _createProposal(FunctionType.SetPaymentToken, abi.encode(collection_, newToken_));
    }

    /**
     * @dev Create proposal to update collection image URI
     */
    function createSetImageURIProposal(address collection_, string calldata newImageURI_)
        external
        onlyRole(ADMIN_ROLE)
        validCollection(collection_)
        validString(newImageURI_)
        returns (uint256)
    {
        return _createProposal(FunctionType.SetCollectionImageURI, abi.encode(collection_, newImageURI_));
    }

    /**
     * @dev Create proposal to update collection max supply
     */
    function createSetMaxSupplyProposal(address collection_, uint256 newMaxSupply_)
        external
        onlyRole(ADMIN_ROLE)
        validCollection(collection_)
        validSupply(newMaxSupply_)
        returns (uint256)
    {
        return _createProposal(FunctionType.SetMaxSupply, abi.encode(collection_, newMaxSupply_));
    }

    /**
     * @dev Create proposal to mint token to specific address
     */
    function createMintToProposal(address collection_, address to_)
        external
        onlyRole(ADMIN_ROLE)
        validCollection(collection_)
        validAddress(to_)
        returns (uint256)
    {
        return _createProposal(FunctionType.MintToAddress, abi.encode(collection_, to_));
    }

    /**
     * @dev Create proposal to withdraw native tokens from collection
     */
    function createWithdrawFundsProposal(address collection_, address to_, uint256 amount_)
        external
        onlyRole(ADMIN_ROLE)
        validCollection(collection_)
        validAddress(to_)
        returns (uint256)
    {
        return _createProposal(FunctionType.WithdrawFunds, abi.encode(collection_, to_, amount_));
    }

    /**
     * @dev Create proposal to withdraw ERC20 tokens from collection
     */
    function createWithdrawTokensProposal(address collection_, address to_, uint256 amount_)
        external
        onlyRole(ADMIN_ROLE)
        validCollection(collection_)
        validAddress(to_)
        returns (uint256)
    {
        return _createProposal(FunctionType.WithdrawTokens, abi.encode(collection_, to_, amount_));
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
            _executeProposal(proposal.functionType, proposal.functionData);
            emit ProposalExecuted(proposalId_, proposal.functionType);
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
            FunctionType functionType
        )
    {
        Proposal storage proposal = _proposals[proposalId_];
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
    function hasVotedForProposal(uint256 proposalId_, address admin_)
        external
        view
        proposalExists(proposalId_)
        returns (bool)
    {
        return _proposals[proposalId_].hasVoted[admin_];
    }

    /**
     * @dev Get proposal function data
     */
    function getProposalFunctionData(uint256 proposalId_)
        external
        view
        proposalExists(proposalId_)
        returns (bytes memory)
    {
        return _proposals[proposalId_].functionData;
    }

    /**
     * @dev Get all _collections created by factory
     */
    function getAllCollections() external view returns (StarKeeper[] memory) {
        return _collections;
    }

    /**
     * @dev Get _collections created by specific address
     */
    function getCreatorCollections(address creator_) external view returns (StarKeeper[] memory) {
        return _creatorCollections[creator_];
    }

    /**
     * @dev Check if collection was created by this factory
     */
    function isCollectionFromFactory(address collection_) external view returns (bool) {
        return _validCollections[collection_];
    }

    /**
     * @dev Get current admin addresses
     */
    function getAdmins() external view returns (address[] memory) {
        return _admins;
    }

    // ============ Internal Functions ============

    /**
     * @dev Create new proposal with auto-approval from creator
     */
    function _createProposal(FunctionType functionType_, bytes memory functionData_) internal returns (uint256) {
        unchecked {
            ++proposalCounter;
        }
        uint256 proposalId = proposalCounter;

        Proposal storage proposal = _proposals[proposalId];
        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.createdAt = block.timestamp;
        proposal.expirationTime = block.timestamp + PROPOSAL_DURATION;
        proposal.functionType = functionType_;
        proposal.functionData = functionData_;
        proposal.hasVoted[msg.sender] = true;
        proposal.approvalCount = 1;

        emit ProposalCreated(proposalId, functionType_, msg.sender);

        // Auto-execute if single admin or quorum = 1
        if (quorumThreshold == 1) {
            proposal.executed = true;
            _executeProposal(functionType_, functionData_);
            emit ProposalExecuted(proposalId, functionType_);
        }

        return proposalId;
    }

    /**
     * @dev Execute approved proposal
     */
    function _executeProposal(FunctionType functionType_, bytes memory functionData_) internal {
        if (functionType_ == FunctionType.CreateCollection) {
            _executeCreateCollection(functionData_);
        } else if (functionType_ == FunctionType.AddFactoryAdmin) {
            _executeAddAdmin(functionData_);
        } else if (functionType_ == FunctionType.RemoveFactoryAdmin) {
            _executeRemoveAdmin(functionData_);
        } else if (functionType_ == FunctionType.SetBaseURI) {
            _executeSetBaseURI(functionData_);
        } else if (functionType_ == FunctionType.SetMintPrice) {
            _executeSetMintPrice(functionData_);
        } else if (functionType_ == FunctionType.SetTokenMintPrice) {
            _executeSetTokenMintPrice(functionData_);
        } else if (functionType_ == FunctionType.SetPaymentToken) {
            _executeSetPaymentToken(functionData_);
        } else if (functionType_ == FunctionType.SetCollectionImageURI) {
            _executeSetImageURI(functionData_);
        } else if (functionType_ == FunctionType.SetMaxSupply) {
            _executeSetMaxSupply(functionData_);
        } else if (functionType_ == FunctionType.MintToAddress) {
            _executeMintTo(functionData_);
        } else if (functionType_ == FunctionType.WithdrawFunds) {
            _executeWithdrawFunds(functionData_);
        } else if (functionType_ == FunctionType.WithdrawTokens) {
            _executeWithdrawTokens(functionData_);
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

    function _executeCreateCollection(bytes memory functionData_) internal {
        (
            string memory name,
            string memory symbol,
            uint256 maxSupply,
            uint256 mintPrice,
            uint256 tokenMintPrice,
            address paymentToken,
            string memory baseTokenURI,
            string memory collectionImageURI
        ) = abi.decode(functionData_, (string, string, uint256, uint256, uint256, address, string, string));

        StarKeeper newCollection = new StarKeeper(
            name, symbol, maxSupply, mintPrice, tokenMintPrice, paymentToken, baseTokenURI, collectionImageURI
        );

        address collectionAddress = address(newCollection);
        _collections.push(newCollection);
        _creatorCollections[msg.sender].push(newCollection);
        _validCollections[collectionAddress] = true;

        emit CollectionCreated(
            msg.sender, collectionAddress, name, maxSupply, mintPrice, paymentToken, tokenMintPrice, collectionImageURI
        );
    }

    function _executeAddAdmin(bytes memory functionData_) internal {
        address admin = abi.decode(functionData_, (address));

        _grantRole(ADMIN_ROLE, admin);
        _admins.push(admin);
        _updateQuorumThreshold();

        emit AdminAdded(admin);
    }

    function _executeRemoveAdmin(bytes memory functionData_) internal {
        address admin = abi.decode(functionData_, (address));

        // Remove from admins array
        for (uint256 i = 0; i < _admins.length; i++) {
            if (_admins[i] == admin) {
                _admins[i] = _admins[_admins.length - 1];
                _admins.pop();
                break;
            }
        }

        _revokeRole(ADMIN_ROLE, admin);
        _updateQuorumThreshold();

        emit AdminRemoved(admin);
    }

    function _executeSetBaseURI(bytes memory functionData_) internal {
        (address payable collectionAddress, string memory newBaseURI) = abi.decode(functionData_, (address, string));

        try StarKeeper(collectionAddress).setBaseURI(newBaseURI) {
            emit BaseURIUpdated(collectionAddress, newBaseURI);
        } catch {
            revert CollectionOperationFailed();
        }
    }

    function _executeSetMintPrice(bytes memory functionData_) internal {
        (address payable collectionAddress, uint256 newPrice) = abi.decode(functionData_, (address, uint256));

        try StarKeeper(collectionAddress).setMintPrice(newPrice) {
            emit MintPriceUpdated(collectionAddress, newPrice); // Simplified event
        } catch {
            revert CollectionOperationFailed();
        }
    }

    function _executeSetTokenMintPrice(bytes memory functionData_) internal {
        (address payable collectionAddress, uint256 newPrice) = abi.decode(functionData_, (address, uint256));

        try StarKeeper(collectionAddress).setTokenMintPrice(newPrice) {
            emit TokenMintPriceUpdated(collectionAddress, newPrice); // Simplified event
        } catch {
            revert CollectionOperationFailed();
        }
    }

    function _executeSetPaymentToken(bytes memory functionData_) internal {
        (address payable collectionAddress, address newToken) = abi.decode(functionData_, (address, address));

        try StarKeeper(collectionAddress).setPaymentToken(newToken) {
            emit PaymentTokenUpdated(collectionAddress, newToken); // Simplified event
        } catch {
            revert CollectionOperationFailed();
        }
    }

    function _executeSetImageURI(bytes memory functionData_) internal {
        (address payable collectionAddress, string memory newImageURI) = abi.decode(functionData_, (address, string));

        try StarKeeper(collectionAddress).setCollectionImageURI(newImageURI) {
            emit CollectionImageURIUpdated(collectionAddress, newImageURI); // Simplified event
        } catch {
            revert CollectionOperationFailed();
        }
    }

    function _executeSetMaxSupply(bytes memory functionData_) internal {
        (address payable collectionAddress, uint256 newMaxSupply) = abi.decode(functionData_, (address, uint256));

        try StarKeeper(collectionAddress).setMaxSupply(newMaxSupply) {
            emit MaxSupplyUpdated(collectionAddress, newMaxSupply); // Simplified event
        } catch {
            revert CollectionOperationFailed();
        }
    }

    function _executeMintTo(bytes memory functionData_) internal {
        (address payable collectionAddress, address recipient) = abi.decode(functionData_, (address, address));

        try StarKeeper(collectionAddress).mintTo(recipient) returns (uint256 tokenId) {
            emit TokenMinted(collectionAddress, recipient, tokenId);
        } catch {
            revert CollectionOperationFailed();
        }
    }

    function _executeWithdrawFunds(bytes memory functionData_) internal {
        (address payable collectionAddress, address recipient, uint256 amount) =
            abi.decode(functionData_, (address, address, uint256));

        try StarKeeper(collectionAddress).withdrawFunds(payable(recipient), amount) {
            emit FundsWithdrawn(collectionAddress, recipient, amount);
        } catch {
            revert CollectionOperationFailed();
        }
    }

    function _executeWithdrawTokens(bytes memory functionData_) internal {
        (address payable collectionAddress, address recipient, uint256 amount) =
            abi.decode(functionData_, (address, address, uint256));

        try StarKeeper(collectionAddress).withdrawTokens(recipient, amount) {
            emit TokensWithdrawn(collectionAddress, recipient);
        } catch {
            revert CollectionOperationFailed();
        }
    }

    // ============ Receive Function ============

    /**
     * @dev Allow contract to receive ETH
     */
    receive() external payable {
        // Allow contract to receive ETH
    }
}
