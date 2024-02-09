//SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9.0;

import "./Diamond.sol";
import "./Multicallable.sol";

bytes4 constant supportsInterfaceSignature = 0x01ffc9a7;

contract DiamondResolver is Diamond, Multicallable {
    constructor(address _owner) Diamond(_owner) {}

    function initialize(address _owner, address _fallback) public virtual override {
        super.initialize(_owner, _fallback);

        if (_fallback == address(0)) {
            bytes4[] memory selectors = new bytes4[](2);
            uint256 selectorIndex;

            // register Multicallable
            selectors[selectorIndex++] = IMulticallable.multicall.selector;
            selectors[selectorIndex++] = IMulticallable.multicallWithNodeCheck.selector;

            // diamond cut

            FacetCut[] memory facetCuts = new FacetCut[](1);

            facetCuts[0] = FacetCut({target: address(this), action: FacetCutAction.ADD, selectors: selectors});

            _diamondCut(facetCuts, address(0), "");
        }

        _setSupportsInterface(type(IMulticallable).interfaceId, true);
    }
}
