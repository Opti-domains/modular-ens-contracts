//SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9.0;

import "../wrapper/INameWrapper.sol";

// Only for unit test
contract MockNameWrapper {
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual returns (bool) {
        return interfaceId == type(INameWrapper).interfaceId;
    }

    function ownerOf(uint256 /* id */) public view returns (address) {
        return tx.origin;
    }
}