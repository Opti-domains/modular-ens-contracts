// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import {IERC165} from "@solidstate/contracts/interfaces/IERC165.sol";
import "src/resolver/attester/OptiResolverAttester.sol";
import "src/resolver/auth/OptiResolverAuth.sol";
import "src/resolver/public-resolver/content-hash-resolver/IContentHashResolver.sol";

bytes32 constant CONTENT_RESOLVER_SCHEMA = keccak256(abi.encodePacked("bytes32 node,bytes hash", address(0), true));

abstract contract ContentHashResolver is IContentHashResolver, OptiResolverAttester, OptiResolverAuth, IERC165 {
    /**
     * Sets the contenthash associated with an ENS node.
     * May only be called by the owner of that node in the ENS registry.
     * @param node The node to update.
     * @param hash The contenthash to set
     */
    function setContenthash(bytes32 node, bytes calldata hash) external virtual authorised(node) {
        _write(CONTENT_RESOLVER_SCHEMA, abi.encode(node), abi.encode(hash));
        emit ContenthashChanged(node, hash);
    }

    /**
     * Returns the contenthash associated with an ENS node.
     * @param node The ENS node to query.
     * @return The associated contenthash.
     */
    function contenthash(bytes32 node) external view virtual override returns (bytes memory) {
        bytes memory response = _read(CONTENT_RESOLVER_SCHEMA, abi.encode(node));
        if (response.length == 0) return "";
        return abi.decode(response, (bytes));
    }

    function supportsInterface(bytes4 interfaceID) public view virtual returns (bool) {
        return interfaceID == type(IContentHashResolver).interfaceId;
    }
}
