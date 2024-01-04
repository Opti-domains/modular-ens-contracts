// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

error Unauthorised();

contract OptiResolverAuth {
    function _isAuthorised(bytes32 node) internal view returns (bool) {
        // TODO
        return true;
    }

    modifier authorised(bytes32 node) {
        if (!_isAuthorised(node)) revert Unauthorised();
        _;
    }
}
