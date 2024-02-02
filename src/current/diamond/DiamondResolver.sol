//SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9.0;

import "./Diamond.sol";
import "./Multicallable.sol";

bytes4 constant supportsInterfaceSignature = 0x01ffc9a7;

contract DiamondResolver is Diamond, Multicallable {
    constructor(address _owner) Diamond(_owner) {}

    function supportsInterface(bytes4 interfaceID)
        public
        view
        virtual
        override(Multicallable, Diamond)
        returns (bool)
    {
        return Diamond.supportsInterface(interfaceID) || Multicallable.supportsInterface(interfaceID);
    }
}
