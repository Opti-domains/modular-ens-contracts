// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../base/DiamondResolverBaseInternal.sol";
import "../base/IDiamondResolverAuth.sol";

contract OwnedAuthFacet is DiamondResolverBaseInternal, IDiamondResolverAuth {
    function isAuthorised(address sender, bytes32) public virtual view returns (bool) {
        return sender == OwnableStorage.layout().owner;
    }
}
