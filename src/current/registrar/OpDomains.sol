// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "./WhitelistRegistrar.sol";

bytes32 constant OP_NAMEHASH = 0x070904f45402bbf3992472be342c636609db649a8ec20a8aaa65faaafd4b8701;

contract OpDomains is WhitelistRegistrar {
    constructor(ModularENS _registry, address _operator)
        WhitelistRegistrar(_operator, OP_NAMEHASH)
        EIP712("OpDomains", "0.0.1")
        FuseRegistrar("Opti.Domains", ".op", _registry)
    {}
}
