pragma solidity ^0.8.0;

import "@ethereum-attestation-service/eas-contracts/contracts/IEAS.sol";
import "../../challenger/RootChallenger.sol";
import "../attester/UseEAS.sol";

contract OptiResolverRelayerFacet is UseEAS {
    error InvalidRoot(bytes32 root);
    error InvalidAttestation();
    error DeprecatedAttestation();

    event AttestationReplayed(
        bytes32 indexed schema,
        address indexed recipient,
        bytes32 indexed sourceUid,
        bytes32 newUid,
        bytes32 slot,
        uint64 sourceTimestamp,
        uint64 expiration,
        bool revocable,
        bytes data
    );

    RootChallenger public immutable challenger;

    constructor(RootChallenger _challenger) {
        challenger = _challenger;
    }

    function hashAttestation(Attestation calldata attestation) internal pure returns (bytes32) {
        uint32 bump = 0;
        return keccak256(
            abi.encodePacked(
                attestation.schema,
                attestation.recipient,
                attestation.attester,
                attestation.time,
                attestation.expirationTime,
                attestation.revocable,
                attestation.refUID,
                attestation.data,
                bump
            )
        );
    }

    function relayAttestations(bytes32[] calldata slots, Attestation[] calldata attestations)
        public
        returns (bytes32[] memory newUids)
    {
        unchecked {
            uint256 attestationsLength = attestations.length;
            bytes32[] memory uids = new bytes32[](attestationsLength);
            newUids = new bytes32[](attestationsLength);

            for (uint256 i = 0; i < attestationsLength; ++i) {
                Attestation calldata a = attestations[i];
                uids[i] = hashAttestation(attestations[i]);

                if (
                    a.uid != uids[i] || (a.expirationTime > 0 && block.timestamp > a.expirationTime)
                        || a.revocationTime > 0 || a.attester != address(this)
                ) {
                    revert InvalidAttestation();
                }

                // Check if this attestation is newer than the existing one
                bytes32 oldAttSlot = slots[i];
                uint256 oldAttTime;
                assembly {
                    // Fetch attestation timestamp from the storage slot
                    oldAttTime := sload(add(oldAttSlot, 2))
                }

                if (a.time < oldAttTime) {
                    revert DeprecatedAttestation();
                }
            }

            bytes32 slotsHash = keccak256(abi.encodePacked(slots));
            bytes32 uidsHash = keccak256(abi.encodePacked(uids));
            bytes32 root = keccak256(abi.encodePacked(address(this), slotsHash, uidsHash));

            if (!challenger.isValidRoot(root)) {
                revert InvalidRoot(root);
            }

            for (uint256 i = 0; i < attestationsLength; ++i) {
                Attestation calldata a = attestations[i];
                bytes32 uid = _easWrite(
                    AttestationRequest({
                        schema: a.schema,
                        data: AttestationRequestData({
                            recipient: a.recipient,
                            expirationTime: a.expirationTime,
                            revocable: a.revocable,
                            refUID: a.refUID,
                            data: a.data,
                            value: 0
                        })
                    })
                );

                bytes32 sourceUid = a.uid;
                uint256 sourceTimestamp = a.time;
                bytes32 s = slots[i];

                newUids[i] = uid;

                assembly {
                    // Store UID to the storage slot
                    sstore(s, uid)

                    // Store source UID to the next storage slot
                    sstore(add(s, 1), sourceUid)

                    // Store source timestamp to the last storage slot
                    sstore(add(s, 2), sourceTimestamp)
                }

                emit AttestationReplayed(
                    a.schema, a.recipient, a.uid, uid, s, a.time, a.expirationTime, a.revocable, a.data
                );
            }
        }
    }
}
