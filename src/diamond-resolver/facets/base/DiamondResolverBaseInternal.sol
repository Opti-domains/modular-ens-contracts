// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import "./DiamondResolverBaseStorage.sol";
import "./DiamondResolverUtil.sol";

error ERC165Base__InvalidInterfaceId();

abstract contract DiamondResolverBaseInternal is DiamondResolverUtil {
    // Logged when an operator is added or removed.
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    // Logged when a delegate is approved or an approval is revoked.
    event Approved(
        address owner,
        bytes32 indexed node,
        address indexed delegate,
        bool indexed approved
    );

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function _setApprovalForAll(address operator, bool approved) internal {
        require(
            msg.sender != operator,
            "ERC1155: setting approval status for self"
        );

        DiamondResolverBaseStorage.Layout storage l = DiamondResolverBaseStorage
            .layout();
        l.operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /**
     * @dev Approve a delegate to be able to updated records on a node.
     */
    function _approve(bytes32 node, address delegate, bool approved) internal {
        require(msg.sender != delegate, "Setting delegate status for self");

        DiamondResolverBaseStorage.Layout storage l = DiamondResolverBaseStorage
            .layout();
        l.tokenApprovals[msg.sender][node][delegate] = approved;
        emit Approved(msg.sender, node, delegate, approved);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function _isApprovedForAll(
        address account,
        address operator
    ) internal view returns (bool) {
        DiamondResolverBaseStorage.Layout storage l = DiamondResolverBaseStorage
            .layout();
        return l.operatorApprovals[account][operator];
    }

    /**
     * @dev Check to see if the delegate has been approved by the owner for the node.
     */
    function _isApprovedFor(
        address owner,
        bytes32 node,
        address delegate
    ) internal view returns (bool) {
        DiamondResolverBaseStorage.Layout storage l = DiamondResolverBaseStorage
            .layout();
        return l.tokenApprovals[owner][node][delegate];
    }
}
