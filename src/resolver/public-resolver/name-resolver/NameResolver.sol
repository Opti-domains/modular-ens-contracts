// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import {IERC165} from "@solidstate/contracts/interfaces/IERC165.sol";
import "src/resolver/attestor/OptiResolverAttestor.sol";
import "src/resolver/auth/OptiResolverAuth.sol";
import "src/resolver/public-resolver/name-resolver/INameResolver.sol";

bytes32 constant NAME_RESOLVER_SCHEMA = keccak256(abi.encodePacked("bytes32 node,string name", address(0), true));

abstract contract NameResolver is INameResolver, OptiResolverAttestor, OptiResolverAuth, IERC165 {
    /**
     * Sets the name associated with an ENS node, for reverse records.
     * May only be called by the owner of that node in the ENS registry.
     * @param node The node to update.
     */
    function setName(bytes32 node, string calldata newName) external virtual authorised(node) {
        _write(NAME_RESOLVER_SCHEMA, abi.encode(node), abi.encode(newName));
        emit NameChanged(node, newName);
    }

    /**
     * Returns the name associated with an ENS node, for reverse records.
     * Defined in EIP181.
     * @param node The ENS node to query.
     * @return result The associated name.
     */
    function name(bytes32 node) external view virtual override returns (string memory result) {
        bytes memory response = _read(NAME_RESOLVER_SCHEMA, abi.encode(node));
        if (response.length == 0) return "";
        result = abi.decode(response, (string));
    }

    function supportsInterface(bytes4 interfaceID) public view virtual returns (bool) {
        return interfaceID == type(INameResolver).interfaceId;
    }
}
