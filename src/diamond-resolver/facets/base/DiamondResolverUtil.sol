// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import {OwnableStorage} from "@solidstate/contracts/access/ownable/OwnableStorage.sol";
import "./DiamondResolverBaseStorage.sol";
import "./IVersionableResolver.sol";
import "../../INameWrapperRegistry.sol";
import "../../../attestation/OptiDomainsAttestation.sol";

error NotDiamondOwner();

abstract contract DiamondResolverUtil {
    error Unauthorised();

    event VersionChanged(bytes32 indexed node, uint64 newVersion);

    modifier baseOnlyOwner() {
        if (msg.sender != OwnableStorage.layout().owner) revert NotDiamondOwner();
        _;
    }

    function _registry() internal view returns(INameWrapperRegistry) {
        return IHasNameWrapperRegistry(address(this)).registry();
    }

    function _attestation() internal view returns(OptiDomainsAttestation) {
        return OptiDomainsAttestation(_registry().attestation());
    }

    function _readAttestation(bytes32 node, bytes32 schema, bytes32 key, bool toDomain) internal view returns(bytes memory) {
        return _attestation().read(node, schema, key, toDomain);
    }

    function _readAttestation(bytes32 node, bytes32 schema, bytes32 key) internal view returns(bytes memory) {
        return _attestation().read(node, schema, key);
    }

    function _attest(bytes32 schema, bytes32 key, bytes32 ref, bool toDomain, bytes memory value) internal {
        _attestation().attest(schema, key, ref, toDomain, value);
    }

    function _attest(bytes32 schema, bytes32 key, bytes32 ref, bytes memory value) internal {
        _attestation().attest(schema, key, ref, value);
    }

    function _attest(bytes32 schema, bytes32 key, bytes memory value) internal {
        _attestation().attest(schema, key, value);
    }

    function _revokeAttestation(bytes32 node, bytes32 schema, bytes32 key, bool toDomain) internal {
        _attestation().revoke(node, schema, key, toDomain);
    }

    function _recordVersions(bytes32 node) internal view returns (uint64) {
        return _attestation().readVersion(node);
    }

    /**
     * Increments the record version associated with an ENS node.
     * May only be called by the owner of that node in the ENS registry.
     * @param node The node to update.
     */
    function _clearRecords(bytes32 node) internal virtual {
        _attestation().increaseVersion(node);
        emit VersionChanged(node, _recordVersions(node));
    }

    function _isAuthorised(bytes32 node) internal view returns (bool) {
        (bool success, bytes memory result) = address(this).staticcall(
            abi.encodeWithSelector(0x25f36704, msg.sender, node)
        );
        if (!success) return false;
        return abi.decode(result, (bool));
    }

    modifier authorised(bytes32 node) {
        if (!_isAuthorised(node)) revert Unauthorised();
        _;
    }
}
