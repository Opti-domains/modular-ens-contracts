// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IEVMVerifier} from "@ensdomains/evm-verifier/contracts/IEVMVerifier.sol";
import {RLPReader} from "@eth-optimism/contracts-bedrock/src/libraries/rlp/RLPReader.sol";
import {StateProof, EVMProofHelper} from "@ensdomains/evm-verifier/contracts/EVMProofHelper.sol";
import {Types} from "@eth-optimism/contracts-bedrock/src/libraries/Types.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Attestation} from "@ethereum-attestation-service/eas-contracts/contracts/IEAS.sol";

import "./OptiL1ResolverUtils.sol";
import "./OptiL1ResolverMetadata.sol";

// https://docs.optimism.io/chain/addresses
address constant OP_L2_OUTPUT_ORACLE = 0xdfe97868233d1aa22e815a266982f2cf17685a27;

struct OPWitnessData {
    uint256 l2OutputIndex;
    Types.OutputRootProof outputRootProof;
}

interface IL2OutputOracle {
    function getL2Output(uint256 _l2OutputIndex) external view returns (Types.OutputProposal memory);
}

// Foundry or solidity bug
// Invalid type for argument in function call. Invalid implicit conversion from struct Types.OutputRootProof memory to struct Types.OutputRootProof memory requested.
// So, we need to move hashOutputRootProof here
library Hashing {
    /// @notice Hashes the various elements of an output root proof into an output root hash which
    ///         can be used to check if the proof is valid.
    /// @param _outputRootProof Output root proof which should hash to an output root.
    /// @return Hashed output root proof.
    function hashOutputRootProof(Types.OutputRootProof memory _outputRootProof) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                _outputRootProof.version,
                _outputRootProof.stateRoot,
                _outputRootProof.messagePasserStorageRoot,
                _outputRootProof.latestBlockhash
            )
        );
    }

    function hashAttestation(Attestation memory attestation) internal pure returns (bytes32) {
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
}

abstract contract OptiFetchTarget {
    using Address for address;

    error InvalidCommonNode();
    error InvalidENSNode();
    error InvalidAttestationUid();
    error InvalidAttestation();
    error ImpossibleLengthMismatch();
    error OutputRootMismatch(uint256 l2OutputIndex, bytes32 expected, bytes32 actual);

    function getStorageValues(address target, bytes32[] memory commands, bytes[] memory constants, bytes memory proof)
        public
        view
        returns (bytes[] memory values)
    {
        (OPWitnessData memory opData, StateProof memory stateProof) = abi.decode(proof, (OPWitnessData, StateProof));
        Types.OutputProposal memory l2out = IL2OutputOracle(OP_L2_OUTPUT_ORACLE).getL2Output(opData.l2OutputIndex);
        bytes32 expectedRoot = Hashing.hashOutputRootProof(opData.outputRootProof);
        if (l2out.outputRoot != expectedRoot) {
            revert OutputRootMismatch(opData.l2OutputIndex, expectedRoot, l2out.outputRoot);
        }
        return
            EVMProofHelper.getStorageValues(target, commands, constants, opData.outputRootProof.stateRoot, stateProof);
    }

    /**
     * @dev CCIP Read callback logic to return resolver data with supplied attestations.
     *      Make public for testing and QA purpose.
     */
    function _ccipAttCallback(bytes memory callbackData, bytes32[] memory slots, Attestation[] memory attestations)
        public
        view
    {
        
    }

    /**
     * @dev Internal callback function invoked by CCIP-Read in response to an attestation resolve request.
     */
    function ccipAttCallback(bytes calldata response, bytes calldata extradata) public view {
        OptiL1ResolverMetadata.Layout storage S = OptiL1ResolverMetadata.layout();

        (
            bytes32 ensCommonNode,
            bytes32[] memory ensPaths,
            uint256 opPathLength,
            bytes memory proof,
            Attestation[] memory attestations
        ) = abi.decode(response, (bytes32, bytes32[], uint256, bytes, Attestation[]));

        (bytes32 ensNode, bytes32[] memory slots, bytes memory callbackData) =
            abi.decode(extradata, (bytes32, bytes32[], bytes));

        // Stage 1: Validate ENS Node and derive OP Node

        bytes32 opNode = S.domainMapping[ensCommonNode];

        if (opNode == bytes32(0)) {
            revert InvalidCommonNode();
        }

        unchecked {
            uint256 ensPathLength = ensPaths.length;
            for (uint256 i = 0; i < ensPathLength; ++i) {
                // Save variable by reuse ensCommonNode
                ensCommonNode = keccak256(abi.encodePacked(ensCommonNode, ensPaths[i]));

                // For wildcard domain support that resolve from a parent domain
                if (i < opPathLength) {
                    opNode = keccak256(abi.encodePacked(opNode, ensPaths[i]));
                }
            }
        }

        if (ensCommonNode != ensNode) {
            revert InvalidENSNode();
        }

        // Stage 2: Extract attestation UIDs from the storage proof

        (EVMFetcher.EVMFetchRequest memory request, address target) =
            OptiL1ResolverUtils.buildAttFetchRequest(opNode, slots);
        bytes[] memory uids = getStorageValues(target, request.commands, request.constants, proof);
        uint256 uidsLength = uids.length;

        if (uidsLength != slots.length) {
            revert ImpossibleLengthMismatch();
        }

        // Stage 3: Verify attestations against UID

        unchecked {
            for (uint256 i = 0; i < uidsLength; ++i) {
                Attestation memory a = attestations[i];

                if (abi.decode(uids[i], (bytes32)) != Hashing.hashAttestation(a)) {
                    revert InvalidAttestationUid();
                }

                if (
                    (a.expirationTime > 0 && block.timestamp > a.expirationTime) || a.revocationTime > 0
                        || a.attester != target
                ) {
                    revert InvalidAttestation();
                }
            }
        }

        // Stage 4: Return resolver data with supplied attestations
        _ccipAttCallback(callbackData, slots, attestations);
    }
}
