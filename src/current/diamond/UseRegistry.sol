//SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9.0;

import {ERC165BaseInternal, IERC165} from "@solidstate/contracts/introspection/ERC165/base/ERC165Base.sol";
import {DiamondBaseStorage} from "@solidstate/contracts/proxy/diamond/base/DiamondBaseStorage.sol";
import "./interfaces/IUseRegistry.sol";

library UseRegistry {
    bytes32 internal constant STORAGE_SLOT = keccak256("optidomains.contracts.DiamondResolver.registry");

    function registry() internal view returns (ModularENS addr) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            addr := sload(slot)
        }

        if (address(addr) == address(0)) {
            address fallbackAddress = DiamondBaseStorage.layout().fallbackAddress;
            if (fallbackAddress != address(0)) {
                if (IERC165(fallbackAddress).supportsInterface(type(IUseRegistry).interfaceId)) {
                    return IUseRegistry(fallbackAddress).registry();
                }
            }
        }
    }
}

contract UseRegistryFacet is IUseRegistry, ERC165BaseInternal {
    function registry() public view returns (ModularENS) {
        return UseRegistry.registry();
    }

    function _setRegistry(ModularENS _registry) internal {
        bytes32 slot = UseRegistry.STORAGE_SLOT;
        assembly {
            sstore(slot, _registry)
        }
    }

    function initialize(ModularENS addr) public virtual {
        if (address(registry()) == address(0)) {
            _setRegistry(addr);
            _setSupportsInterface(type(IUseRegistry).interfaceId, true);
        }
    }
}
