// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import { IERC165 } from '@solidstate/contracts/interfaces/IERC165.sol';
import "../../base/DiamondResolverUtil.sol";
import "./IABIResolver.sol";

bytes32 constant ABI_RESOLVER_SCHEMA = keccak256(abi.encodePacked("bytes32 node,uint256 contentType,bytes abi", address(0), true));

library ABIResolverStorage {
    struct Layout {
        mapping(uint64 => mapping(bytes32 => mapping(uint256 => bytes))) versionable_abis;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256('optidomains.contracts.storage.ABIResolverStorage');

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}

abstract contract ABIResolver is IABIResolver, DiamondResolverUtil, IERC165 {
    /**
     * Sets the ABI associated with an ENS node.
     * Nodes may have one ABI of each content type. To remove an ABI, set it to
     * the empty string.
     * @param node The node to update.
     * @param contentType The content type of the ABI
     * @param data The ABI data.
     */
    function setABI(
        bytes32 node,
        uint256 contentType,
        bytes calldata data
    ) external virtual authorised(node) {
        // Content types must be powers of 2
        require(((contentType - 1) & contentType) == 0);

        if (data.length == 0) {
            _revokeAttestation(node, ABI_RESOLVER_SCHEMA, bytes32(contentType), false);
        } else {
            _attest(ABI_RESOLVER_SCHEMA, bytes32(contentType), abi.encode(node, contentType, data));
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
    function ABI(
        bytes32 node,
        uint256 contentTypes
    ) external view virtual override returns (uint256, bytes memory) {
        for (
            uint256 contentType = 1;
            contentType <= contentTypes;
            contentType <<= 1
        ) {
            bytes memory data = _readAttestation(node, ABI_RESOLVER_SCHEMA, bytes32(contentType));
            if (
                (contentType & contentTypes) != 0 &&
                data.length > 0
            ) {
                (,, bytes memory a) = abi.decode(data, (bytes32, uint256, bytes));
                return (contentType, a);
            }
        }

        return (0, bytes(""));
    }

    function supportsInterface(
        bytes4 interfaceID
    ) public view virtual override returns (bool) {
        return
            interfaceID == type(IABIResolver).interfaceId;
    }
}
