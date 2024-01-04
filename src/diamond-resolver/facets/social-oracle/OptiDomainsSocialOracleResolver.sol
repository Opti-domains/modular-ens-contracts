// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { IERC165 } from '@solidstate/contracts/interfaces/IERC165.sol';
import "../base/DiamondResolverUtil.sol";
import "../../../attestation/IOptiDomainsSocialOracle.sol";

bytes32 constant WALLET_ORACLE_SCHEMA = keccak256(
    abi.encodePacked(
        "bytes32 node,uint256 coinType,bytes identity,bytes proof",
        address(0),
        true
    )
);

bytes32 constant SOCIAL_ORACLE_SCHEMA = keccak256(
    abi.encodePacked(
        "bytes32 node,string provider,string identity,bytes proof",
        address(0),
        true
    )
);

bytes32 constant ADDR_RESOLVER_SCHEMA = keccak256(abi.encodePacked("bytes32 node,uint256 coinType,bytes address", address(0), true));
bytes32 constant TEXT_RESOLVER_SCHEMA = keccak256(abi.encodePacked("bytes32 node,string key,string value", address(0), true));

contract OptiDomainsSocialOracleResolver is DiamondResolverUtil, IERC165 {
    function setWalletWithVerification(
        bytes32 node,
        IOptiDomainsSocialOracle oracle,
        uint256 coinType,
        bytes calldata identity,
        bytes calldata proof,
        bytes calldata operatorSignature
    ) external virtual {
        _attest(
            ADDR_RESOLVER_SCHEMA, 
            bytes32(coinType), 
            oracle.attest(
                WALLET_ORACLE_SCHEMA,
                abi.encode(node, coinType, identity, proof),
                operatorSignature
            ), 
            abi.encode(node, coinType, identity)
        );
    }

    function setSocialProfile(
        bytes32 node,
        IOptiDomainsSocialOracle oracle,
        string calldata provider,
        string calldata identity,
        bytes calldata proof,
        bytes calldata operatorSignature
    ) external virtual {
        _attest(
            TEXT_RESOLVER_SCHEMA, 
            keccak256(abi.encodePacked(provider)), 
            oracle.attest(
                SOCIAL_ORACLE_SCHEMA,
                abi.encode(node, provider, identity, proof),
                operatorSignature
            ),
            abi.encode(node, provider, identity)
        );
    }

    function supportsInterface(
        bytes4
    ) public view virtual returns (bool) {
        return false;
    }
}
