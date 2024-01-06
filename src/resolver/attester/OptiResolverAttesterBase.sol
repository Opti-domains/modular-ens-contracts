// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

abstract contract OptiResolverAttesterBase {
    event ResolverWrite(
        bytes32 indexed schema,
        address indexed recipient,
        bytes32 indexed uid,
        uint64 expiration,
        bool revocable,
        bytes header,
        bytes body
    );

    event ResolverRevoke(
        bytes32 indexed schema,
        address indexed recipient,
        bytes32 indexed uid,
        bytes header
    );

    function _read(bytes32 schema, address recipient, bytes memory header)
        internal
        view
        virtual
        returns (bytes memory);

    function _write(
        bytes32 schema,
        address recipient,
        uint64 expiration,
        bool revocable,
        bytes memory header,
        bytes memory body
    ) internal virtual returns (bytes32);

    function _revoke(bytes32 schema, address recipient, bytes memory header) internal virtual returns (bytes32);
}
