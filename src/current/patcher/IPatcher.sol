// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

interface IPatcher {
    struct PatchImplementation {
        address target;
        address impl;
    }

    struct PatchAction {
        address target;
        bytes data;
    }

    struct PatchBody {
        bytes32[] deploys;
        PatchImplementation[] implementations;
        PatchAction[] actions;
    }

    struct Patch {
        uint256 nonce;
        PatchBody patch;
    }

    struct PatchFF {
        uint256 startNonce;
        uint256 endNonce;
        PatchBody patch;
    }

    function applyPatch(Patch memory patch, bytes memory signature) external;
    function applyPatchFF(PatchFF memory patch, bytes memory signature) external;
}
