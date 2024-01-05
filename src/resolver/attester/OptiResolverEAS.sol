// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@ethereum-attestation-service/eas-contracts/contracts/IEAS.sol";
import "src/resolver/attester/OptiResolverAttesterBase.sol";

// TODO
address constant EAS = 0x0000000000000000000000000000000000000000;

contract OptiResolverEAS is OptiResolverAttesterBase {
    function _read(bytes32 schema, address recipient, bytes memory header)
        internal
        view
        virtual
        override
        returns (bytes memory)
    {
        bytes32 s = keccak256(abi.encode(schema, recipient, header));
        bytes32 uid;

        assembly {
            uid := sload(s)
        }

        if (uid == bytes32(0)) return "";

        Attestation memory data = IEAS(EAS).getAttestation(uid);

        if (
            data.uid == uid && data.schema == schema
                && (data.expirationTime == 0 || block.timestamp <= data.expirationTime) && data.revocationTime == 0
                && data.recipient == recipient && data.attester == address(this)
        ) {}
    }

    function _write(
        bytes32 schema,
        address recipient,
        uint256 expiration,
        bool revocable,
        bytes memory header,
        bytes memory body
    ) internal virtual override returns (bytes32) {}

    function _revoke(bytes32 schema, address recipient, bytes memory header)
        internal
        virtual
        override
        returns (bytes32)
    {}
}
