//SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9.0;

import "./SolidStateDiamond.sol";
import "./Multicallable.sol";
import "./IDiamondResolver.sol";
import "./facets/base/IDiamondResolverBase.sol";
import "./facets/base/DiamondResolverBase.sol";
import "../registry/ENS.sol";
import "./INameWrapperRegistry.sol";
import {IReverseRegistrar} from "../reverseRegistrar/IReverseRegistrar.sol";
import {INameWrapper} from "../wrapper/INameWrapper.sol";

bytes4 constant supportsInterfaceSignature = 0x01ffc9a7;

contract DiamondResolver is 
    SolidStateDiamond,
    Multicallable,
    DiamondResolverBase
{
    bytes32 constant ADDR_REVERSE_NODE =
        0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2;

    INameWrapperRegistry public immutable registry;

    constructor(address _owner, INameWrapperRegistry _registry) SolidStateDiamond(_owner) {
        registry = _registry;
    }

    function initialize(address _owner, address _fallback) public virtual override {
        super.initialize(_owner, _fallback);

        if (_fallback == address(0)) {
            bytes4[] memory selectors = new bytes4[](8);
            uint256 selectorIndex;

            // register DiamondResolverBase

            selectors[selectorIndex++] = IHasNameWrapperRegistry.registry.selector;
            selectors[selectorIndex++] = IDiamondResolverBase.setApprovalForAll.selector;
            selectors[selectorIndex++] = IDiamondResolverBase.isApprovedForAll.selector;
            selectors[selectorIndex++] = IDiamondResolverBase.approve.selector;
            selectors[selectorIndex++] = IDiamondResolverBase.isApprovedFor.selector;
            selectors[selectorIndex++] = IVersionableResolver.recordVersions.selector;
            selectors[selectorIndex++] = IVersionableResolver.clearRecords.selector;
            selectors[selectorIndex++] = IDiamondResolverFactory.clone.selector;

            // diamond cut

            FacetCut[] memory facetCuts = new FacetCut[](1);

            facetCuts[0] = FacetCut({
                target: address(this),
                action: FacetCutAction.ADD,
                selectors: selectors
            });

            _diamondCut(facetCuts, address(0), '');
        }

        _setSupportsInterface(type(IDiamondResolver).interfaceId, true);
        _setSupportsInterface(type(IVersionableResolver).interfaceId, true);
        _setSupportsInterface(type(IHasNameWrapperRegistry).interfaceId, true);
        _setSupportsInterface(type(IDiamondResolverFactory).interfaceId, true);
    }

    function supportsInterface(
        bytes4 interfaceID
    )
        public
        view
        virtual
        override(Multicallable, SolidStateDiamond)
        returns (bool)
    {
        return SolidStateDiamond.supportsInterface(interfaceID) || Multicallable.supportsInterface(interfaceID);
    }
}
