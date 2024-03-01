// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IOptiL1Gateway {
    function getAttestations(bytes32 ensNode, bytes32[] calldata slots, bytes calldata dnsEncodedName) external;
}
