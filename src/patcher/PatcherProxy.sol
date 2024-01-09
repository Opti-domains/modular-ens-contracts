// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

interface PatcherInitialize {
    function initialize(address _owner) external;
}

contract PatcherProxy is TransparentUpgradeableProxy {
    constructor(address _impl, address _owner)
        TransparentUpgradeableProxy(
            _impl,
            address(this),
            abi.encodeWithSelector(PatcherInitialize.initialize.selector, _owner)
        )
    {}
}
