// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "../../public-resolver/addr-resolver/AddrResolver.sol";
import "./IInterfaceResolver.sol";

bytes32 constant INTERFACE_RESOLVER_SCHEMA =
    keccak256(abi.encodePacked("bytes32 node,bytes4 interfaceID,address implementer", address(0), true));

abstract contract InterfaceResolver is IInterfaceResolver, AddrResolver {
    /**
     * Sets an interface associated with a name.
     * Setting the address to 0 restores the default behaviour of querying the contract at `addr()` for interface support.
     * @param node The node to update.
     * @param interfaceID The EIP 165 interface ID.
     * @param implementer The address of a contract that implements this interface for this node.
     */
    function setInterface(bytes32 node, bytes4 interfaceID, address implementer) external virtual authorised(node) {
        _write(INTERFACE_RESOLVER_SCHEMA, abi.encode(node, interfaceID), abi.encode(implementer));
        emit InterfaceChanged(node, interfaceID, implementer);
    }

    /**
     * Returns the address of a contract that implements the specified interface for this name.
     * If an implementer has not been set for this interfaceID and name, the resolver will query
     * the contract at `addr()`. If `addr()` is set, a contract exists at that address, and that
     * contract implements EIP165 and returns `true` for the specified interfaceID, its address
     * will be returned.
     * @param node The ENS node to query.
     * @param interfaceID The EIP 165 interface ID to check for.
     * @return The address that implements this interface, or 0 if the interface is unsupported.
     */
    function interfaceImplementer(bytes32 node, bytes4 interfaceID)
        external
        view
        virtual
        override
        ccip
        returns (address)
    {
        bytes memory implementerRaw = _read(INTERFACE_RESOLVER_SCHEMA, abi.encode(node, interfaceID));
        address implementer;
        if (implementerRaw.length > 0) {
            implementer = abi.decode(implementerRaw, (address));
        }
        if (implementer != address(0)) {
            return implementer;
        }

        address a = addr(node);
        if (a == address(0)) {
            return address(0);
        }

        (bool success, bytes memory returnData) =
            a.staticcall(abi.encodeWithSignature("supportsInterface(bytes4)", type(IERC165).interfaceId));
        if (!success || returnData.length < 32 || returnData[31] == 0) {
            // EIP 165 not supported by target
            return address(0);
        }

        (success, returnData) = a.staticcall(abi.encodeWithSignature("supportsInterface(bytes4)", interfaceID));
        if (!success || returnData.length < 32 || returnData[31] == 0) {
            // Specified interface not supported by target
            return address(0);
        }

        return a;
    }

    function supportsInterface(bytes4 interfaceID) public view virtual override returns (bool) {
        return interfaceID == type(IInterfaceResolver).interfaceId || super.supportsInterface(interfaceID);
    }
}
