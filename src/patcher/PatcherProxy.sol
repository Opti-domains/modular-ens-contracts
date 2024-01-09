// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "src/patcher/Patcher.sol";

interface PatcherInitialize {
    function initialize(address _owner) external;
}

contract PatcherProxy is TransparentUpgradeableProxy {
    constructor(address _owner)
        TransparentUpgradeableProxy(
            address(new Patcher()),
            address(this),
            abi.encodeWithSelector(PatcherInitialize.initialize.selector, _owner)
        )
    {}
}
