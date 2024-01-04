// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import {IERC165} from "@solidstate/contracts/interfaces/IERC165.sol";
import "src/resolver/attestor/OptiResolverAttestor.sol";
import "src/resolver/auth/OptiResolverAuth.sol";
import "src/resolver/public-resolver/abi-resolver/IABIResolver.sol";

bytes32 constant ABI_RESOLVER_SCHEMA =
    keccak256(abi.encodePacked("bytes32 node,uint256 contentType,bytes abi", address(0), true));

abstract contract ABIResolver is IABIResolver, OptiResolverAttestor, OptiResolverAuth, IERC165 {
    /**
     * Sets the ABI associated with an ENS node.
     * Nodes may have one ABI of each content type. To remove an ABI, set it to
     * the empty string.
     * @param node The node to update.
     * @param contentType The content type of the ABI
     * @param data The ABI data.
     */
    function setABI(bytes32 node, uint256 contentType, bytes calldata data) external virtual authorised(node) {
        // Content types must be powers of 2
        require(((contentType - 1) & contentType) == 0);

        if (data.length == 0) {
            _revoke(ABI_RESOLVER_SCHEMA, abi.encode(node, bytes32(contentType)));
        } else {
            _write(ABI_RESOLVER_SCHEMA, abi.encode(node, bytes32(contentType)), abi.encode(data));
        }

        emit ABIChanged(node, contentType);
    }

    /**
     * Returns the ABI associated with an ENS node.
     * Defined in EIP205.
     * @param node The ENS node to query
     * @param contentTypes A bitwise OR of the ABI formats accepted by the caller.
     * @return contentType The content type of the return value
     * @return data The ABI data
     */
    function ABI(bytes32 node, uint256 contentTypes) external view virtual override returns (uint256, bytes memory) {
        for (uint256 contentType = 1; contentType <= contentTypes; contentType <<= 1) {
            bytes memory data = _read(ABI_RESOLVER_SCHEMA, abi.encode(node, bytes32(contentType)));
            if ((contentType & contentTypes) != 0 && data.length > 0) {
                return (contentType, abi.decode(data, (bytes)));
            }
        }

        return (0, bytes(""));
    }

    function supportsInterface(bytes4 interfaceID) public view virtual override returns (bool) {
        return interfaceID == type(IABIResolver).interfaceId;
    }
}
