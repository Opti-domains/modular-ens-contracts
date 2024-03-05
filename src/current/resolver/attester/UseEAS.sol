pragma solidity ^0.8.0;

import "@ethereum-attestation-service/eas-contracts/contracts/IEAS.sol";

// TODO
address constant EAS = 0x4200000000000000000000000000000000000021;
address constant FALLBACK_EAS = 0x4200000000000000000000000000000000000021;

contract UseEAS {
    function _easRead(bytes32 uid) internal view returns (Attestation memory a) {
        if (EAS.code.length > 0) {
            try IEAS(EAS).getAttestation(uid) returns (Attestation memory _a) {
                a = _a;
            } catch (bytes memory) {}
        }

        if (a.uid == bytes32(0)) {
            a = IEAS(FALLBACK_EAS).getAttestation(uid);
        }
    }

    function _easWrite(AttestationRequest memory request) internal returns (bytes32 uid) {
        if (EAS.code.length > 0) {
            try IEAS(EAS).attest(request) returns (bytes32 _uid) {
                uid = _uid;
            } catch (bytes memory) {}
        }

        if (uid == bytes32(0)) {
            uid = IEAS(EAS).attest(request);
        }
    }
}
