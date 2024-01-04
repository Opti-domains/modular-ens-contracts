// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

interface IDiamondResolverAuth {
    function isAuthorised(address sender, bytes32 node) external view returns (bool);
}
