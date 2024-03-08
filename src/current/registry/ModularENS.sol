// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {IDiamondWritableInternal} from "@solidstate/contracts/proxy/diamond/writable/IDiamondWritableInternal.sol";
import "./ENSReadOnly.sol";

interface ModularENS is ENSReadOnly {
    struct TLD {
        uint256 chainId;
        bytes32 nameHash;
        address registrar;
        address resolver;
        string name;
    }

    struct Record {
        address owner;
        address resolver;
        bytes32 nameHash;
        uint256 expiration;
        uint256 registrationTime;
        uint256 updatedTimestamp;
        bytes32 parentNode;
        bytes32 tldNode;
        uint256 nonce;
        string label;
        bytes data;
    }

    // Core registration functions

    function registerTLD(TLD memory tld) external;

    function register(bytes32 parentNode, address owner, uint256 expiration, string memory label, bytes memory data)
        external
        returns (bytes32, bytes32, uint256);

    function update(bytes32 _node, address _owner, uint256 _expiration) external returns (bytes32, uint256);

    function relay(Record calldata _record, bytes32[] calldata _proof) external;

    // Resolver functions

    function resolverDiamondCut(
        bytes32 _node,
        IDiamondWritableInternal.FacetCut[] calldata _facetCuts,
        address _target,
        bytes calldata _data
    ) external;

    function resolverCall(bytes32 _node, bytes calldata _calldata) external payable returns (bytes memory);

    // Single update functions

    function setOwner(bytes32 node, address owner) external;
    function setExpiration(bytes32 node, uint256 expiration) external;
    function setData(bytes32 node, bytes memory data) external;

    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    // Getter functions

    function record(bytes32 node) external view returns (Record memory);

    function expiration(bytes32 node) external view returns (uint256);
    function parentNode(bytes32 node) external view returns (bytes32);
    function tldNode(bytes32 node) external view returns (bytes32);
    function primaryChainId(bytes32 node) external view returns (uint256);
    function tld(bytes32 tldNodeHash) external view returns (TLD memory);
    function data(bytes32 node) external view returns (bytes memory);

    function name(bytes32 node) external view returns (string memory);
    function dnsEncoded(bytes32 node) external view returns (bytes memory);
}
