// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "./ENSReadOnly.sol";

interface ModularENS is ENSReadOnly {
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
        bytes32 parentNode;
        bytes32 tldNode;
        uint256 nonce;
        string name;
        bytes data;
    }

    // Core registration functions

    function registerTLD(TLD memory tld) external;

    function register(
        bytes32 parentNode,
        address owner,
        uint256 expiration,
        uint64 ttl,
        string memory label,
        bytes memory data
    ) external returns (bytes32, bytes32, uint256);

    function update(bytes32 _node, address _owner, uint256 _expiration, uint64 _ttl)
        external
        returns (bytes32, uint256);

    // Single update functions

    function setOwner(bytes32 node, address owner) external;
    function setExpiration(bytes32 node, uint64 expiration) external;
    function setTTL(bytes32 node, uint64 ttl) external;
    function setData(bytes32 node, bytes memory data) external;

    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    // Getter functions

    function record(bytes32 node) external view returns (Record memory);

    function expiration(bytes32 node) external view returns (uint256);
    function parentNode(bytes32 node) external view returns (bytes32);
    function tldNode(bytes32 node) external view returns (bytes32);
    function tld(bytes32 tldHash) external view returns (TLD memory);
    function data(bytes32 node) external view returns (bytes memory);

    function name(bytes32 node) external view returns (string memory);
    function dnsEncoded(bytes32 node) external view returns (bytes memory);
}
