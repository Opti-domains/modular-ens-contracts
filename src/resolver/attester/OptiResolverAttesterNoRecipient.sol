// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import "@ensdomains/ens-contracts/registry/ENS.sol";
import "src/resolver/attester/OptiResolverAttesterBase.sol";

abstract contract OptiResolverAttesterNoRecipient is OptiResolverAttesterBase {
    function _read(bytes32 schema, bytes memory header) internal view virtual returns (bytes memory) {
        return _read(schema, address(this), header);
    }

    function _write(bytes32 schema, bytes memory header, bytes memory body) internal virtual returns (bytes32) {
        return _write(schema, address(this), 0, false, header, body);
    }

    function _revoke(bytes32 schema, bytes memory header) internal virtual returns (bytes32) {
        return _revoke(schema, address(this), header);
    }
}
