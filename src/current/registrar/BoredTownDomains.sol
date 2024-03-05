// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "./WhitelistRegistrar.sol";

bytes32 constant BED_NAMEHASH = 0x1bbca8d94eb9755a83557b1004cde6f25be663bd2c476d34a337bb91b6cf976b;

contract BoredTownDomains is WhitelistRegistrar {
    constructor(ModularENS _registry, address _operator)
        WhitelistRegistrar(_operator, BED_NAMEHASH)
        EIP712("BoredTownDomains", "0.0.1")
        FuseRegistrar("Bored Town Domains", ".bed", _registry)
    {}
}
