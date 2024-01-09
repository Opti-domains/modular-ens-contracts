// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@ensdomains/ens-contracts/registry/ENS.sol";

interface ModularENS is ENS {
    struct TLD {
        uint256 chainId;
        bytes32 nameHash;
        bytes32 tldHash;
        address registrar;
    }

    function register(bytes32 parentNode, string memory label, address owner, uint256 expiration, uint64 ttl)
        external
        returns (bytes32);

    function expiration(bytes32 node) external returns (uint256);
    function parentNode(bytes32 node) external returns (bytes32);
    function tldNode(bytes32 node) external returns (bytes32);
    function tld(bytes32 tldHash) external returns (TLD memory);
    function merkleIndex(bytes32 node) external returns (uint256);
    function merkleRoot(bytes32 tldHash, uint256 index) external returns (bytes32);

    function name(bytes32 node) external returns (string memory);
    function dnsEncoded(bytes32 node) external returns (bytes memory);
}
