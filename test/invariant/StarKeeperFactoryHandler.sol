// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {StarKeeperFactory} from "../../src/StarKeeperFactory.sol";
import {StarKeeper} from "../../src/StarKeeper.sol";
import {MockERC20} from "../mocks/ERC20Mock.sol";

contract StarKeeperFactoryHandler is Test {
    StarKeeperFactory public factory;
    MockERC20 public mockToken;

    // Test addresses
    address public admin1;
    address public admin2;
    address public admin3;

    uint256 public ghost_collectionCount;
    uint256 public ghost_proposalCount;

    constructor(StarKeeperFactory _factory, MockERC20 _mockToken, address _admin1, address _admin2, address _admin3) {
        factory = _factory;
        mockToken = _mockToken;
        admin1 = _admin1;
        admin2 = _admin2;
        admin3 = _admin3;
    }

    function createCollectionProposal(
        uint256 _nameSeed,
        uint256 _symbolSeed,
        uint256 _maxSupply,
        uint256 _mintPrice,
        uint256 _tokenMintPrice,
        uint256 _paymentTokenSeed
    ) external {
        // Bound inputs to reasonable values
        _maxSupply = bound(_maxSupply, 1, 100_000); // 1 to 100k max supply
        _mintPrice = bound(_mintPrice, 0, 10 ether); // 0 to 10 ETH
        _tokenMintPrice = bound(_tokenMintPrice, 0, 10 ** 25); // 0 to 10M tokens

        // Generate reasonable names/symbols
        string memory name = string(abi.encodePacked("Collection", _nameSeed % 1000));
        string memory symbol = string(abi.encodePacked("COL", _symbolSeed % 1000));

        // Random payment token (75% chance of zero address, 25% mock token)
        address paymentToken = (_paymentTokenSeed % 4 == 0) ? address(mockToken) : address(0);

        string memory baseURI = "https://example.com/";
        string memory imageURI = "https://example.com/image.png";

        // Use one of the admin addresses
        address[] memory admins = factory.getAdmins();
        if (admins.length > 0) {
            address currentAdmin = admins[_nameSeed % admins.length];

            vm.prank(currentAdmin);
            try factory.createCollectionProposal(
                name, symbol, _maxSupply, _mintPrice, _tokenMintPrice, paymentToken, baseURI, imageURI
            ) {
                ghost_proposalCount++;

                // If proposal executed (single admin), increment collection count
                if (factory.quorumThreshold() == 1) {
                    ghost_collectionCount++;
                }
            } catch {
                // Ignore failed calls
            }
        }
    }

    function voteForProposal(uint256 _proposalId) external {
        // Bound proposal ID to reasonable range
        uint256 totalProposals = factory.proposalCounter();
        if (totalProposals == 0) return;

        _proposalId = bound(_proposalId, 1, totalProposals);

        // Use one of the admin addresses
        address[] memory admins = factory.getAdmins();
        if (admins.length > 0) {
            address currentAdmin = admins[_proposalId % admins.length];

            vm.prank(currentAdmin);
            try factory.voteForProposal(_proposalId) {
                // Check if proposal executed after this vote
                (,,,, bool executed,) = factory.getProposalDetails(_proposalId);
                if (executed) {
                    // This was a collection creation proposal that just executed
                    ghost_collectionCount++;
                }
            } catch {
                // Ignore failed calls
            }
        }
    }

    function addAdmin(uint256 _adminSeed) external {
        address newAdmin = address(uint160(_adminSeed));
        if (newAdmin == address(0)) return;

        address[] memory admins = factory.getAdmins();
        if (admins.length > 0) {
            address currentAdmin = admins[_adminSeed % admins.length];

            vm.prank(currentAdmin);
            try factory.createAddAdminProposal(newAdmin) {
                ghost_proposalCount++;
            } catch {
                // Ignore failed calls
            }
        }
    }
}
