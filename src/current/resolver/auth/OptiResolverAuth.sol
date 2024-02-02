// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

error Unauthorised();

abstract contract OptiResolverAuth {
    function _isAuthorised(bytes32 node) internal view virtual returns (bool);

    modifier authorised(bytes32 node) {
        if (!_isAuthorised(node)) revert Unauthorised();
        _;
    }
}
