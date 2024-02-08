// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "./BaseRegistrar.sol";

contract FuseRegistrar is BaseRegistrar {
    constructor(string memory name, string memory symbol, ModularENS _registry)
        BaseRegistrar(name, symbol, _registry)
    {}
}
