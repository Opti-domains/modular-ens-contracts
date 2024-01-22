// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

interface IDiamondCloneFactory {
    function clone(bytes32 salt) external returns (address newResolver);
}
