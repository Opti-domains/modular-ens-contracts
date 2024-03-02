// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "./FuseRegistrar.sol";

bytes32 constant OP_NAMEHASH = 0x070904f45402bbf3992472be342c636609db649a8ec20a8aaa65faaafd4b8701;

contract OpDomains is FuseRegistrar {
    constructor(ModularENS _registry) FuseRegistrar("Opti.Domains", ".op", _registry) {}

    function register(
        string calldata label,
        address owner,
        uint256 expiration,
        uint256 fuses,
        bool reverseRecord,
        bytes[] calldata resolverCalldata,
        bytes calldata signature
    ) external payable {
        _register(label, OP_NAMEHASH, owner, expiration, fuses, reverseRecord, resolverCalldata);
    }

    function extendExpiry(bytes32 node, uint256 expiration, bytes calldata signature) external payable {
        registry.setExpiration(node, expiration);
    }
}
