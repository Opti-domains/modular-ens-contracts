// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "./WhitelistRegistrar.sol";

contract BoredTownDomains is WhitelistRegistrar {
    constructor(ModularENS _registry, address _operator, bytes32 _tldNameHash)
        WhitelistRegistrar(_operator, _tldNameHash)
        EIP712("BoredTownDomains", "0.0.1")
        FuseRegistrar("Bored Town Domains", ".bed", _registry)
    {}
}
