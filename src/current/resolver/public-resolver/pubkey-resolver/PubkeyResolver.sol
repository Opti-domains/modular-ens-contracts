// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import {IERC165} from "@solidstate/contracts/interfaces/IERC165.sol";
import "../../attester/OptiResolverAttester.sol";
import "../../auth/OptiResolverAuth.sol";
import "./IPubkeyResolver.sol";

bytes32 constant PUBKEY_RESOLVER_STORAGE = keccak256("optidomains.resolver.PubkeyResolverStorage");
bytes32 constant PUBKEY_RESOLVER_SCHEMA =
    keccak256(abi.encodePacked("bytes32 node,bytes32 x,bytes32 y", address(0), true));

abstract contract PubkeyResolver is IPubkeyResolver, OptiResolverAttester, OptiResolverAuth, IERC165 {
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
    function setPubkey(bytes32 node, bytes32 x, bytes32 y) external virtual authorised(node) {
        _write(PUBKEY_RESOLVER_SCHEMA, abi.encode(node), abi.encode(x, y));
        emit PubkeyChanged(node, x, y);
    }

    /**
     * Returns the SECP256k1 public key associated with an ENS node.
     * Defined in EIP 619.
     * @param node The ENS node to query
     * @return x The X coordinate of the curve point for the public key.
     * @return y The Y coordinate of the curve point for the public key.
     */
    function pubkey(bytes32 node) external view virtual override ccip returns (bytes32 x, bytes32 y) {
        bytes memory response = _read(PUBKEY_RESOLVER_SCHEMA, abi.encode(node));
        if (response.length > 0) {
            (x, y) = abi.decode(response, (bytes32, bytes32));
        }
    }

    function supportsInterface(bytes4 interfaceID) public view virtual returns (bool) {
        return interfaceID == type(IPubkeyResolver).interfaceId;
    }
}
