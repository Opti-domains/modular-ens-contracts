// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

library SignatureValidator {
    function validateBasicSignature(address signer, bytes32 topic, bytes32 hash, bytes memory signature)
        internal
        view
        returns (bool)
    {
        bytes32 digest = keccak256(abi.encodePacked(bytes1(0x19), bytes1(0), address(this), topic, hash));

        return SignatureChecker.isValidSignatureNow(signer, digest, signature);
    }
}
