// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { OwnableInternal } from '@solidstate/contracts/access/ownable/OwnableInternal.sol';
import { DiamondBaseStorage } from '@solidstate/contracts/proxy/diamond/base/DiamondBaseStorage.sol';
import { IDiamondFallback } from '@solidstate/contracts/proxy/diamond/fallback/IDiamondFallback.sol';
import { Proxy } from '@solidstate/contracts/proxy/Proxy.sol';

interface IDiamondBaseExtendable is IDiamondFallback {
    function getImplementation(bytes4 sig) external view returns (address);
}

/**
 * @title Fallback feature for EIP-2535 "Diamond" proxy
 */
abstract contract DiamondBaseExtendable is
    IDiamondBaseExtendable,
    Proxy,
    OwnableInternal
{
    /**
     * @inheritdoc IDiamondFallback
     */
    function getFallbackAddress()
        external
        view
        returns (address fallbackAddress)
    {
        fallbackAddress = _getFallbackAddress();
    }

    /**
     * @inheritdoc IDiamondFallback
     */
    function setFallbackAddress(address fallbackAddress) external onlyOwner {
        _setFallbackAddress(fallbackAddress);
    }

    function _getImplementation()
        internal
        view
        virtual
        override
        returns (address implementation)
    {
        implementation = getImplementation(msg.sig);
    }

    function getImplementation(bytes4 sig) public view virtual returns (address implementation) {
        // inline storage layout retrieval uses less gas
        DiamondBaseStorage.Layout storage l;
        bytes32 slot = DiamondBaseStorage.STORAGE_SLOT;
        assembly {
            l.slot := slot
        }

        implementation = address(bytes20(l.facets[sig]));

        if (implementation == address(0)) {
            implementation = _getFallbackAddress();
            if (implementation != address(0)) {
                implementation = IDiamondBaseExtendable(payable(implementation)).getImplementation(sig);
            }
        }
    }

    /**
     * @notice query the address of the fallback implementation
     * @return fallbackAddress address of fallback implementation
     */
    function _getFallbackAddress()
        internal
        view
        virtual
        returns (address fallbackAddress)
    {
        fallbackAddress = DiamondBaseStorage.layout().fallbackAddress;
    }

    /**
     * @notice set the address of the fallback implementation
     * @param fallbackAddress address of fallback implementation
     */
    function _setFallbackAddress(address fallbackAddress) internal virtual {
        DiamondBaseStorage.layout().fallbackAddress = fallbackAddress;
    }
}
