// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import { IERC165 } from '@solidstate/contracts/interfaces/IERC165.sol';
import "../../base/DiamondResolverUtil.sol";
import "./IAddrResolver.sol";
import "./IAddressResolver.sol";

bytes32 constant ADDR_RESOLVER_SCHEMA = keccak256(abi.encodePacked("bytes32 node,uint256 coinType,bytes address", address(0), true));

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

abstract contract AddrResolver is
    IAddrResolver,
    IAddressResolver,
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
    ) public view virtual override returns (address payable) {
        bytes memory a = addr(node, COIN_TYPE_ETH);
        if (a.length == 0) {
            return payable(0);
        }
        return bytesToAddress(a);
    }

    function setAddrWithRef(
        bytes32 node,
        uint256 coinType,
        bytes32 ref,
        bytes memory a
    ) public virtual authorised(node) {
        emit AddressChanged(node, coinType, a);
        if (coinType == COIN_TYPE_ETH) {
            emit AddrChanged(node, bytesToAddress(a));
        }

        _attest(ADDR_RESOLVER_SCHEMA, bytes32(coinType), ref, abi.encode(node, coinType, a));
    }

    function setAddr(
        bytes32 node,
        uint256 coinType,
        bytes memory a
    ) public virtual {
        setAddrWithRef(node, coinType, bytes32(0), a);
    }

    function addr(
        bytes32 node,
        uint256 coinType
    ) public view virtual override returns (bytes memory) {
        bytes memory response = _readAttestation(node, ADDR_RESOLVER_SCHEMA, bytes32(coinType));
        if (response.length == 0) return "";
        (,, bytes memory a) = abi.decode(response, (bytes32, bytes32, bytes));
        return a;
    }

    function supportsInterface(
        bytes4 interfaceID
    ) public view virtual returns (bool) {
        return
            interfaceID == type(IAddrResolver).interfaceId ||
            interfaceID == type(IAddressResolver).interfaceId;
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
