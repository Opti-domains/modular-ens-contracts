// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import {ERC165BaseInternal} from "@solidstate/contracts/introspection/ERC165/base/ERC165BaseInternal.sol";
import "./DiamondResolverBaseInternal.sol";
import "./DiamondResolverFactory.sol";
import "./IDiamondResolverBase.sol";

abstract contract DiamondResolverBase is
    IDiamondResolverBase,
    DiamondResolverBaseInternal,
    DiamondResolverFactory,
    ERC165BaseInternal
{
    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public {
        _setApprovalForAll(operator, approved);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(
        address account,
        address operator
    ) public view returns (bool) {
        return _isApprovedForAll(account, operator);
    }

    /**
     * @dev Approve a delegate to be able to updated records on a node.
     */
    function approve(bytes32 node, address delegate, bool approved) public {
        _approve(node, delegate, approved);
    }

    /**
     * @dev Check to see if the delegate has been approved by the owner for the node.
     */
    function isApprovedFor(
        address owner,
        bytes32 node,
        address delegate
    ) public view returns (bool) {
        return _isApprovedFor(owner, node, delegate);
    }

    function recordVersions(bytes32 node) public view returns (uint64) {
        return _recordVersions(node);
    }

    /**
     * Increments the record version associated with an ENS node.
     * May only be called by the owner of that node in the ENS registry.
     * @param node The node to update.
     */
    function clearRecords(bytes32 node) public virtual authorised(node) {
        _clearRecords(node);
    }

    function setSupportsInterface(bytes4 interfaceId, bool status) public baseOnlyOwner {
        _setSupportsInterface(interfaceId, status);
    }

    function setMultiSupportsInterface(bytes4[] memory interfaceId, bool status) public baseOnlyOwner {
        unchecked {
            uint length = interfaceId.length;
            for (uint i; i < length; ++i) {
                _setSupportsInterface(interfaceId[i], status);
            }
        }
    }
}
