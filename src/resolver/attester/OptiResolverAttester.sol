// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@ensdomains/ens-contracts/registry/ENS.sol";
import "src/resolver/attester/OptiResolverAttesterBase.sol";

// TODO
address constant ENS_REGISTRY = 0x0000000000000000000000000000000000000000;

error DomainNotFound(bytes32 node);

abstract contract OptiResolverAttester is OptiResolverAttesterBase {
    function _read(bytes32 schema, bytes memory header) internal view virtual returns (bytes memory) {
        bytes32 node = abi.decode(header, (bytes32));
        address recipient = ENS(ENS_REGISTRY).owner(node);
        return _read(schema, recipient, header);
    }

    function _write(bytes32 schema, bytes memory header, bytes memory body) internal virtual returns (bytes32) {
        bytes32 node = abi.decode(header, (bytes32));
        address recipient = ENS(ENS_REGISTRY).owner(node);

        if (recipient == address(0)) {
            revert DomainNotFound(node);
        }

        return _write(schema, recipient, 0, false, header, body);
    }

    function _revoke(bytes32 schema, bytes memory header) internal virtual returns (bytes32) {
        bytes32 node = abi.decode(header, (bytes32));
        address recipient = ENS(ENS_REGISTRY).owner(node);
        return _revoke(schema, recipient, header);
    }
}
