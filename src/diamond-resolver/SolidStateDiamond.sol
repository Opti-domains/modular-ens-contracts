// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IOwnable, Ownable, OwnableInternal } from '@solidstate/contracts/access/ownable/Ownable.sol';
import { ISafeOwnable, SafeOwnable } from '@solidstate/contracts/access/ownable/SafeOwnable.sol';
import { IERC173 } from '@solidstate/contracts/interfaces/IERC173.sol';
import { DiamondBase } from '@solidstate/contracts/proxy/diamond/base/DiamondBase.sol';
import { DiamondFallback, IDiamondFallback } from '@solidstate/contracts/proxy/diamond/fallback/DiamondFallback.sol';
import { DiamondReadable, IDiamondReadable } from '@solidstate/contracts/proxy/diamond/readable/DiamondReadable.sol';
import { DiamondWritable, IDiamondWritable } from '@solidstate/contracts/proxy/diamond/writable/DiamondWritable.sol';
import { ISolidStateDiamond, IERC165 } from '@solidstate/contracts/proxy/diamond/ISolidStateDiamond.sol';
import { ERC165BaseInternal } from "@solidstate/contracts/introspection/ERC165/base/ERC165BaseInternal.sol";
import "./DiamondBaseExtendable.sol";

/**
 * @title SolidState "Diamond" proxy reference implementation
 * Overrided to fix non-virtual function in ERC165Base implementation
 */
abstract contract SolidStateDiamond is
    ISolidStateDiamond,
    DiamondBaseExtendable,
    DiamondReadable,
    DiamondWritable,
    SafeOwnable,
    ERC165BaseInternal
{
    constructor(address _owner) {
        initialize(_owner, address(0));
    }

    struct Initialization {
        bool initialized;
    }

    function initialize(address _owner, address _fallback) public virtual {
        Initialization storage initialization;
        bytes32 slot = keccak256("optidomains.contracts.initialization");
        assembly {
            initialization.slot := slot
        }

        require(!initialization.initialized, "Initialized");

        if (_fallback == address(0)) {
            bytes4[] memory selectors = new bytes4[](13);
            uint256 selectorIndex;

            // register DiamondFallback

            selectors[selectorIndex++] = IDiamondFallback
                .getFallbackAddress
                .selector;
            selectors[selectorIndex++] = IDiamondFallback
                .setFallbackAddress
                .selector;
            selectors[selectorIndex++] = IDiamondBaseExtendable
                .getImplementation
                .selector;

            // register DiamondWritable

            selectors[selectorIndex++] = IDiamondWritable.diamondCut.selector;

            // register DiamondReadable

            selectors[selectorIndex++] = IDiamondReadable.facets.selector;
            selectors[selectorIndex++] = IDiamondReadable
                .facetFunctionSelectors
                .selector;
            selectors[selectorIndex++] = IDiamondReadable.facetAddresses.selector;
            selectors[selectorIndex++] = IDiamondReadable.facetAddress.selector;

            // register ERC165

            selectors[selectorIndex++] = IERC165.supportsInterface.selector;

            // register SafeOwnable

            selectors[selectorIndex++] = Ownable.owner.selector;
            selectors[selectorIndex++] = SafeOwnable.nomineeOwner.selector;
            selectors[selectorIndex++] = Ownable.transferOwnership.selector;
            selectors[selectorIndex++] = SafeOwnable.acceptOwnership.selector;

            // diamond cut

            FacetCut[] memory facetCuts = new FacetCut[](1);

            facetCuts[0] = FacetCut({
                target: address(this),
                action: FacetCutAction.ADD,
                selectors: selectors
            });

            _diamondCut(facetCuts, address(0), '');
        } else {
            _setFallbackAddress(_fallback);
        }

        _setSupportsInterface(type(IDiamondBaseExtendable).interfaceId, true);
        _setSupportsInterface(type(IDiamondFallback).interfaceId, true);
        _setSupportsInterface(type(IDiamondWritable).interfaceId, true);
        _setSupportsInterface(type(IDiamondReadable).interfaceId, true);
        _setSupportsInterface(type(IERC165).interfaceId, true);
        _setSupportsInterface(type(IERC173).interfaceId, true);

        // set owner

        _setOwner(_owner);
    }

    receive() external payable {}

    function _transferOwnership(
        address account
    ) internal virtual override(OwnableInternal, SafeOwnable) {
        super._transferOwnership(account);
    }

    function supportsInterface(
        bytes4 interfaceID
    ) public view virtual override(IERC165) returns (bool result) {
        result = _supportsInterface(interfaceID);
        if (!result) {
            address fallbackAddress = _getFallbackAddress();
            if (fallbackAddress != address(0)) {
                result = result || IERC165(fallbackAddress).supportsInterface(interfaceID);
            }
        }
    }
}
