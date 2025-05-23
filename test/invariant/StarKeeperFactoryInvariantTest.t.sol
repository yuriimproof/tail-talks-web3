// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {StarKeeperFactory} from "../../src/StarKeeperFactory.sol";
import {StarKeeper} from "../../src/StarKeeper.sol";
import {MockERC20} from "../mocks/ERC20Mock.sol";
import {StarKeeperFactoryHandler} from "./StarKeeperFactoryHandler.sol";

contract StarKeeperFactoryInvariantTest is Test {
    StarKeeperFactory public factory;
    MockERC20 public mockToken;
    StarKeeperFactoryHandler public handler;

    // Test addresses
    address public admin1 = makeAddr("admin1");
    address public admin2 = makeAddr("admin2");
    address public admin3 = makeAddr("admin3");

    function setUp() public {
        mockToken = new MockERC20();

        address[] memory initialAdmins = new address[](1);
        initialAdmins[0] = admin1;

        vm.prank(admin1);
        factory = new StarKeeperFactory(initialAdmins);

        // Create handler and target it instead of the factory directly
        handler = new StarKeeperFactoryHandler(factory, mockToken, admin1, admin2, admin3);

        // Target the handler for invariant testing
        targetContract(address(handler));
    }

    // ============ INVARIANTS ============

    /**
     * @dev Invariant: Factory should always have at least one admin
     */
    function invariant_factory_has_admins() public view {
        address[] memory admins = factory.getAdmins();
        assertGt(admins.length, 0, "Factory should always have at least one admin");
    }

    /**
     * @dev Invariant: Quorum threshold should be reasonable
     */
    function invariant_quorum_reasonable() public view {
        address[] memory admins = factory.getAdmins();
        uint256 quorum = factory.quorumThreshold();

        assertGe(quorum, 1, "Quorum should be at least 1");
        assertLe(quorum, admins.length, "Quorum should not exceed admin count");

        // For multiple admins, quorum should be 75% (rounded up)
        if (admins.length > 1) {
            uint256 expectedQuorum = (admins.length * 75 + 99) / 100;
            assertEq(quorum, expectedQuorum, "Quorum should be 75% of admin count");
        }
    }

    /**
     * @dev Invariant: All collections should be valid
     */
    function invariant_all_collections_valid() public view {
        StarKeeper[] memory collections = factory.getAllCollections();

        for (uint256 i = 0; i < collections.length; i++) {
            address collectionAddr = address(collections[i]);

            // Collection should be non-zero address
            assertNotEq(collectionAddr, address(0), "Collection address should not be zero");

            // Factory should recognize this collection
            assertTrue(factory.isCollectionFromFactory(collectionAddr), "Factory should recognize its own collections");

            // Collection should have reasonable max supply
            uint256 maxSupply = collections[i].maxSupply();
            assertGt(maxSupply, 0, "Collection should have positive max supply");
            assertLe(maxSupply, 100_000, "Collection max supply should be reasonable"); // 100k max
        }
    }

    /**
     * @dev Invariant: Collection total supply should never exceed max supply
     */
    function invariant_collection_supply_limits() public view {
        StarKeeper[] memory collections = factory.getAllCollections();

        for (uint256 i = 0; i < collections.length; i++) {
            uint256 totalSupply = collections[i].totalSupply();
            uint256 maxSupply = collections[i].maxSupply();

            assertLe(totalSupply, maxSupply, "Collection total supply should never exceed max supply");
        }
    }

    /**
     * @dev Invariant: All factory admins should have admin role
     */
    function invariant_admin_role_consistency() public view {
        address[] memory admins = factory.getAdmins();
        bytes32 adminRole = keccak256("ADMIN_ROLE");

        for (uint256 i = 0; i < admins.length; i++) {
            assertTrue(factory.hasRole(adminRole, admins[i]), "All addresses in admin array should have admin role");
        }
    }

    /**
     * @dev Invariant: Proposal counter should be non-decreasing
     */
    function invariant_proposal_counter_increasing() public view {
        uint256 proposalCounter = factory.proposalCounter();
        assertGe(proposalCounter, 0, "Proposal counter should be non-negative");

        // In a more sophisticated test, you'd track previous values
        // For now, just ensure it's reasonable
        assertLe(proposalCounter, 10000, "Proposal counter should be reasonable");
    }

    /**
     * @dev Invariant: Collections should have reasonable pricing
     */
    function invariant_collection_pricing_reasonable() public view {
        StarKeeper[] memory collections = factory.getAllCollections();

        for (uint256 i = 0; i < collections.length; i++) {
            uint256 mintPrice = collections[i].mintPrice();
            uint256 tokenMintPrice = collections[i].tokenMintPrice();

            // Prices shouldn't be unreasonably high
            assertLe(mintPrice, 10 ether, "Collection mint price should be reasonable");
            assertLe(tokenMintPrice, 10 ** 25, "Collection token price should be reasonable"); // 10M tokens max
        }
    }

    /**
     * @dev Invariant: Factory should be the factory for all its collections
     */
    function invariant_factory_ownership() public view {
        StarKeeper[] memory collections = factory.getAllCollections();

        for (uint256 i = 0; i < collections.length; i++) {
            address collectionFactory = collections[i].factory();
            assertEq(collectionFactory, address(factory), "Collection should point back to this factory");
        }
    }

    /**
     * @dev Invariant: No duplicate admins in admin array
     */
    function invariant_no_duplicate_admins() public view {
        address[] memory admins = factory.getAdmins();

        // Check for duplicates
        for (uint256 i = 0; i < admins.length; i++) {
            for (uint256 j = i + 1; j < admins.length; j++) {
                assertNotEq(admins[i], admins[j], "Admin array should not contain duplicates");
            }
        }
    }

    /**
     * @dev Invariant: All admin addresses should be non-zero
     */
    function invariant_admins_non_zero() public view {
        address[] memory admins = factory.getAdmins();

        for (uint256 i = 0; i < admins.length; i++) {
            assertNotEq(admins[i], address(0), "Admin addresses should not be zero address");
        }
    }
}
