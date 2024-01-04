// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import "./IVersionableResolver.sol";
import {INameWrapper} from "../../../wrapper/INameWrapper.sol";

interface IDiamondResolverBase is IVersionableResolver {
    function setApprovalForAll(address operator, bool approved) external;

    function isApprovedForAll(
        address account,
        address operator
    ) external view returns (bool);

    function approve(bytes32 node, address delegate, bool approved) external;

    function isApprovedFor(
        address owner,
        bytes32 node,
        address delegate
    ) external view returns (bool);
}
