// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import { IERC165 } from '@solidstate/contracts/interfaces/IERC165.sol';
import "../../base/DiamondResolverUtil.sol";
import "./IPubkeyResolver.sol";

bytes32 constant PUBKEY_RESOLVER_STORAGE = keccak256("optidomains.resolver.PubkeyResolverStorage");
bytes32 constant PUBKEY_RESOLVER_SCHEMA = keccak256(abi.encodePacked("bytes32 node,bytes32 x,bytes32 y", address(0), true));

library PubkeyResolverStorage {
    struct PublicKey {
        bytes32 x;
        bytes32 y;
    }

    struct Layout {
        mapping(uint64 => mapping(bytes32 => PublicKey)) versionable_pubkeys;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256("optidomains.contracts.storage.PubkeyResolverStorage");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}

abstract contract PubkeyResolver is IPubkeyResolver, DiamondResolverUtil, IERC165 {
    struct PublicKey {
        bytes32 x;
        bytes32 y;
    }

    /**
     * Sets the SECP256k1 public key associated with an ENS node.
     * @param node The ENS node to query
     * @param x the X coordinate of the curve point for the public key.
     * @param y the Y coordinate of the curve point for the public key.
     */
    function setPubkey(
        bytes32 node,
        bytes32 x,
        bytes32 y
    ) external virtual authorised(node) {
        _attest(PUBKEY_RESOLVER_SCHEMA, bytes32(0), abi.encode(node, x, y));
        emit PubkeyChanged(node, x, y);
    }

    /**
     * Returns the SECP256k1 public key associated with an ENS node.
     * Defined in EIP 619.
     * @param node The ENS node to query
     * @return x The X coordinate of the curve point for the public key.
     * @return y The Y coordinate of the curve point for the public key.
     */
    function pubkey(
        bytes32 node
    ) external view virtual override returns (bytes32 x, bytes32 y) {
        bytes memory response = _readAttestation(node, PUBKEY_RESOLVER_SCHEMA, bytes32(0));
        if (response.length > 0) {
            (, x, y) = abi.decode(response, (bytes32, bytes32, bytes32));
        }
    }

    function supportsInterface(
        bytes4 interfaceID
    ) public view virtual returns (bool) {
        return
            interfaceID == type(IPubkeyResolver).interfaceId;
    }
}
