// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Attestation} from "@ethereum-attestation-service/eas-contracts/contracts/IEAS.sol";

abstract contract OptiFetchTarget {
    using Address for address;

    function _ccipAttCallback(
        bytes32 opNode,
        bytes32[] memory slots,
        bytes memory callbackData,
        Attestation[] memory attestations
    ) internal {}

    /**
     * @dev Internal callback function invoked by CCIP-Read in response to an attestation resolve request.
     */
    function ccipAttCallback(bytes calldata response, bytes calldata extradata) external {
        (
            bytes32 ensCommonNode,
            bytes32[] memory ensPaths,
            uint256 opPathLength,
            bytes memory proof,
            Attestation[] memory attestations
        ) = abi.decode(response, (bytes32, bytes32[], uint256, bytes, Attestation[]));

        (bytes32 ensNode, bytes32[] memory slots, bytes memory callbackData) =
            abi.decode(extradata, (bytes32, bytes32[], bytes));
    }
}
