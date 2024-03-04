// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "./FuseRegistrar.sol";

bytes32 constant OP_NAMEHASH = 0x070904f45402bbf3992472be342c636609db649a8ec20a8aaa65faaafd4b8701;

bytes32 constant REGISTER_COMMITMENT_TYPEHASH = keccak256("RegisterCommitment(bytes32 commitment,uint256 deadline)");
bytes32 constant EXTEND_EXPIRY_TYPEHASH = keccak256("ExtendExpiry(bytes32 node,uint256 expiration,uint256 deadline)");

contract OpDomains is EIP712, FuseRegistrar {
    error SignatureExpired();
    error InvalidSignature();

    address public immutable operator;

    constructor(ModularENS _registry, address _operator)
        EIP712("OpDomains", "0.0.1")
        FuseRegistrar("Opti.Domains", ".op", _registry)
    {
        operator = _operator;
    }

    function register(
        string calldata label,
        address owner,
        uint256 expiration,
        uint256 fuses,
        bool reverseRecord,
        bytes[] calldata resolverCalldata,
        uint256 deadline,
        bytes calldata signature
    ) external payable {
        if (block.timestamp > deadline) {
            revert SignatureExpired();
        }

        bytes32 commitment = keccak256(abi.encode(label, owner, expiration, fuses, reverseRecord, resolverCalldata));

        bytes32 structHash = keccak256(abi.encode(REGISTER_COMMITMENT_TYPEHASH, commitment, deadline));
        bytes32 digest = _hashTypedDataV4(structHash);
        if (!SignatureChecker.isValidSignatureNow(operator, digest, signature)) {
            revert InvalidSignature();
        }

        _register(label, OP_NAMEHASH, owner, expiration, fuses, reverseRecord, resolverCalldata);
    }

    function extendExpiry(bytes32 node, uint256 expiration, uint256 deadline, bytes calldata signature)
        external
        payable
    {
        if (block.timestamp > deadline) {
            revert SignatureExpired();
        }

        bytes32 structHash = keccak256(abi.encode(EXTEND_EXPIRY_TYPEHASH, node, expiration, deadline));
        bytes32 digest = _hashTypedDataV4(structHash);
        if (!SignatureChecker.isValidSignatureNow(operator, digest, signature)) {
            revert InvalidSignature();
        }

        registry.setExpiration(node, expiration);
    }
}
