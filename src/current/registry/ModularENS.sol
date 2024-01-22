// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@ensdomains/ens-contracts/registry/ENS.sol";

interface ModularENS is ENS {
    struct TLD {
        uint256 chainId;
        bytes32 nameHash;
        address registrar;
        string name;
    }

    struct Record {
        address owner;
        address resolver;
        uint64 ttl;
        uint256 expiration;
        uint256 fuses;
        bytes32 parentNode;
        bytes32 tldNode;
        uint256 nonce;
        string name;
    }

    function registerTLD(TLD memory tld) external;

    function register(
        bytes32 parentNode,
        string memory label,
        address owner,
        uint256 expiration,
        uint256 fuses,
        uint64 ttl
    ) external returns (bytes32);

    function expiration(bytes32 node) external view returns (uint256);
    function parentNode(bytes32 node) external view returns (bytes32);
    function tldNode(bytes32 node) external view returns (bytes32);
    function tld(bytes32 tldHash) external view returns (TLD memory);

    function name(bytes32 node) external view returns (string memory);
    function dnsEncoded(bytes32 node) external view returns (bytes memory);
}
