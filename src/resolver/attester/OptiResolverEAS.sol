// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@ethereum-attestation-service/eas-contracts/contracts/IEAS.sol";
import "src/resolver/attester/OptiResolverAttesterBase.sol";

bytes32 constant RESOLVER_STORAGE_NAMESPACE = keccak256("optidomains.resolver.storage");

// TODO
address constant EAS = 0x0000000000000000000000000000000000000000;

contract OptiResolverEAS is OptiResolverAttesterBase {
    function _read(bytes32 schema, address recipient, bytes memory header)
        internal
        view
        virtual
        override
        returns (bytes memory data)
    {
        bytes32 s = keccak256(abi.encode(RESOLVER_STORAGE_NAMESPACE, schema, recipient, header));
        bytes32 uid;

        assembly {
            uid := sload(s)
        }

        if (uid == bytes32(0)) return "";

        Attestation memory a = IEAS(EAS).getAttestation(uid);

        if (
            a.uid == uid && a.schema == schema && (a.expirationTime == 0 || block.timestamp <= a.expirationTime)
                && a.revocationTime == 0 && a.recipient == recipient && a.attester == address(this)
        ) {
            data = a.data;

            uint256 headerLength = header.length;
            uint256 bodyLength = data.length - headerLength;

            assembly {
                // Calculate the position of the body
                let bodyPosition := add(data, headerLength)

                // Store body length at the start of body
                mstore(bodyPosition, bodyLength)

                // Set data to start at body
                data := bodyPosition
            }
        }
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
