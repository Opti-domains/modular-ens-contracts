// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

abstract contract OptiResolverAttesterBase {
    function _read(bytes32 schema, address recipient, bytes memory header)
        internal
        view
        virtual
        returns (bytes memory);

    function _write(
        bytes32 schema,
        address recipient,
        uint256 expiration,
        bool revocable,
        bytes memory header,
        bytes memory body
    ) internal virtual returns (bytes32);

    function _revoke(bytes32 schema, address recipient, bytes memory header) internal virtual returns (bytes32);
}
