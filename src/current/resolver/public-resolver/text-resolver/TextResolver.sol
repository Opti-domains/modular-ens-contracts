// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import {IERC165} from "@solidstate/contracts/interfaces/IERC165.sol";
import "../../attester/OptiResolverAttester.sol";
import "../../auth/OptiResolverAuth.sol";
import "./ITextResolver.sol";

bytes32 constant TEXT_RESOLVER_SCHEMA =
    keccak256(abi.encodePacked("bytes32 node,string key,string value", address(0), true));

abstract contract TextResolver is ITextResolver, OptiResolverAttester, OptiResolverAuth, IERC165 {
    /**
     * Sets the text data associated with an ENS node and key.
     * May only be called by the owner of that node in the ENS registry.
     * @param node The node to update.
     * @param key The key to set.
     * @param value The text data value to set.
     */
    function setText(bytes32 node, string calldata key, string calldata value) external virtual {
        _write(TEXT_RESOLVER_SCHEMA, abi.encode(node, key), abi.encode(value));
        emit TextChanged(node, key, key, value);
    }

    /**
     * Returns the text data associated with an ENS node and key.
     * @param node The ENS node to query.
     * @param key The text data key to query.
     * @return result The associated text data.
     */
    function text(bytes32 node, string calldata key)
        external
        view
        virtual
        override
        ccip
        returns (string memory result)
    {
        bytes memory response = _read(TEXT_RESOLVER_SCHEMA, abi.encode(node, key));
        if (response.length == 0) return "";
        result = abi.decode(response, (string));
    }

    function supportsInterface(bytes4 interfaceID) public view virtual returns (bool) {
        return interfaceID == type(ITextResolver).interfaceId;
    }
}
