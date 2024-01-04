// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import { IERC165 } from '@solidstate/contracts/interfaces/IERC165.sol';
import "../../base/DiamondResolverUtil.sol";
import "./ITextResolver.sol";

bytes32 constant TEXT_RESOLVER_SCHEMA = keccak256(abi.encodePacked("bytes32 node,string key,string value", address(0), true));

library TextResolverStorage {
    struct Layout {
        mapping(uint64 => mapping(bytes32 => mapping(string => string))) versionable_texts;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256("optidomains.contracts.storage.TextResolverStorage");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}

abstract contract TextResolver is ITextResolver, DiamondResolverUtil, IERC165 {
    /**
     * Sets the text data associated with an ENS node and key with referenced attestation.
     * May only be called by the owner of that node in the ENS registry.
     * @param node The node to update.
     * @param ref Referenced attestation.
     * @param key The key to set.
     * @param value The text data value to set.
     */
    function setTextWithRef(
        bytes32 node,
        bytes32 ref,
        string calldata key,
        string calldata value
    ) public virtual authorised(node) {
        _attest(TEXT_RESOLVER_SCHEMA, keccak256(abi.encodePacked(key)), ref, abi.encode(node, key, value));
        emit TextChanged(node, key, key, value);
    }

    /**
     * Sets the text data associated with an ENS node and key.
     * May only be called by the owner of that node in the ENS registry.
     * @param node The node to update.
     * @param key The key to set.
     * @param value The text data value to set.
     */
    function setText(
        bytes32 node,
        string calldata key,
        string calldata value
    ) external virtual {
        setTextWithRef(node, bytes32(0), key, value);
    }

    /**
     * Returns the text data associated with an ENS node and key.
     * @param node The ENS node to query.
     * @param key The text data key to query.
     * @return result The associated text data.
     */
    function text(
        bytes32 node,
        string calldata key
    ) external view virtual override returns (string memory result) {
        bytes memory response = _readAttestation(node, TEXT_RESOLVER_SCHEMA, keccak256(abi.encodePacked(key)));
        if (response.length == 0) return "";
        (,, result) = abi.decode(response, (bytes32, string, string));
    }

    function supportsInterface(
        bytes4 interfaceID
    ) public view virtual returns (bool) {
        return
            interfaceID == type(ITextResolver).interfaceId;
    }
}
