// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import { IERC165 } from '@solidstate/contracts/interfaces/IERC165.sol';
import "../base/DiamondResolverUtil.sol";

library AddrResolverStorage {
    struct Layout {
        mapping(uint64 => mapping(bytes32 => mapping(uint256 => bytes))) versionable_addresses;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256('optidomains.contracts.storage.AddrResolverStorage');

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}

contract TestAddrResolver is
    DiamondResolverUtil,
    IERC165
{
    uint256 private constant COIN_TYPE_ETH = 60;

    /**
     * Sets the address associated with an ENS node.
     * May only be called by the owner of that node in the ENS registry.
     * @param node The node to update.
     * @param a The address to set.
     */
    function setAddr(
        bytes32 node,
        address a
    ) external virtual authorised(node) {
        setAddr(node, COIN_TYPE_ETH, addressToBytes(a));
    }

    /**
     * Returns the address associated with an ENS node.
     * @param node The ENS node to query.
     * @return The associated address.
     */
    function addr(
        bytes32 node
    ) public view virtual returns (address payable) {
        return payable(address(1));
    }

    function setAddr(
        bytes32 node,
        uint256 coinType,
        bytes memory a
    ) public virtual authorised(node) {
        revert("Unsupported");
    }

    function addr(
        bytes32 node,
        uint256 coinType
    ) public view virtual returns (bytes memory) {
        return "";
    }

    function supportsInterface(
        bytes4 interfaceID
    ) public view virtual returns (bool) {
        return false;
    }

    function bytesToAddress(
        bytes memory b
    ) internal pure returns (address payable a) {
        require(b.length == 20);
        assembly {
            a := div(mload(add(b, 32)), exp(256, 12))
        }
    }

    function addressToBytes(address a) internal pure returns (bytes memory b) {
        b = new bytes(20);
        assembly {
            mstore(add(b, 32), mul(a, exp(256, 12)))
        }
    }
}
