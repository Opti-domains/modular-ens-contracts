// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@ethereum-attestation-service/eas-contracts/contracts/IEAS.sol";
import "./OptiResolverAttesterBase.sol";
import "./UseEAS.sol";

bytes32 constant RESOLVER_STORAGE_NAMESPACE = keccak256("optidomains.resolver.storage");

contract OptiResolverEAS is OptiResolverAttesterBase, UseEAS {
    error HeaderMustIncludeNode();

    function _storageSlot(bytes32 schema, address recipient, bytes memory header) private pure returns (bytes32 s) {
        if (header.length < 32) revert HeaderMustIncludeNode();

        bytes memory packed = abi.encodePacked(header, schema, recipient, RESOLVER_STORAGE_NAMESPACE);
        uint256 packedLength = packed.length;

        assembly {
            // keccak256 hash omiting node
            s := keccak256(add(packed, 0x40), sub(packedLength, 0x20))

            // Store above hash next to the node
            mstore(add(packed, 0x40), s)

            // slot = keccak256 of node and the hash above
            s := keccak256(add(packed, 0x20), 0x40)
        }
    }

    function _read(bytes32 schema, address recipient, bytes memory header)
        internal
        view
        virtual
        override
        returns (bytes memory data)
    {
        bytes32 s = _storageSlot(schema, recipient, header);
        bytes32 uid;

        assembly {
            // Fetch UID from the storage slot
            uid := sload(s)
        }

        if (uid == bytes32(0)) return "";

        Attestation memory a = _easRead(uid);

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
        uint64 expiration,
        bool revocable,
        bytes memory header,
        bytes memory body
    ) internal virtual override returns (bytes32 uid) {
        if (body.length == 0) {
            return _revoke(schema, recipient, header);
        }

        bytes32 s = _storageSlot(schema, recipient, header);

        uid = _easWrite(
            AttestationRequest({
                schema: schema,
                data: AttestationRequestData({
                    recipient: recipient,
                    expirationTime: expiration,
                    revocable: revocable,
                    refUID: bytes32(0),
                    data: bytes.concat(header, body),
                    value: 0
                })
            })
        );

        assembly {
            // Store UID to the storage slot
            sstore(s, uid)
        }

        emit ResolverWrite(schema, recipient, uid, expiration, revocable, header, body);
    }

    function _revoke(bytes32 schema, address recipient, bytes memory header)
        internal
        virtual
        override
        returns (bytes32 uid)
    {
        bytes32 s = _storageSlot(schema, recipient, header);

        assembly {
            // Fetch UID from the storage slot
            uid := sload(s)

            // Clear UID from the storage slot
            sstore(s, 0)
        }

        IEAS(EAS).revoke(RevocationRequest({schema: schema, data: RevocationRequestData({uid: uid, value: 0})}));

        emit ResolverRevoke(schema, recipient, uid, header);
    }

    function _ccipBefore() internal view virtual override {}
    function _ccipAfter() internal view virtual override {}
}
