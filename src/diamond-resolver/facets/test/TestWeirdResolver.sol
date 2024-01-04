// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import { IERC165 } from '@solidstate/contracts/interfaces/IERC165.sol';
import "../base/DiamondResolverUtil.sol";

contract TestWeirdResolver is
    DiamondResolverUtil,
    IERC165
{
    // Only immutable works
    uint256 immutable weirdConst;

    constructor(uint256 _weirdConst) {
        weirdConst = _weirdConst;
    }

    function weird(
        bytes32 node
    ) external virtual view returns(uint256) {
        return weirdConst;
    }

    function supportsInterface(
        bytes4 interfaceID
    ) public view virtual returns (bool) {
        return false;
    }
}
