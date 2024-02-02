//SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9.0;

import {ERC165BaseInternal} from "@solidstate/contracts/introspection/ERC165/base/ERC165BaseInternal.sol";
import "./interfaces/IUseRegistry.sol";

contract UseRegistry is IUseRegistry, ERC165BaseInternal {
    bytes32 internal constant STORAGE_SLOT = keccak256("optidomains.contracts.DiamondResolver.registry");

    function _setRegistry(ModularENS _registry) internal {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            sstore(slot, _registry)
        }
    }

    function registry() public view returns (ModularENS addr) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            addr := sload(slot)
        }
    }

    function initialize(ModularENS addr) public virtual {
        if (address(registry()) == address(0)) {
            _setRegistry(addr);
            _setSupportsInterface(type(IUseRegistry).interfaceId, true);
        }
    }
}
