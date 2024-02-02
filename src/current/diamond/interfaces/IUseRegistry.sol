//SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9.0;

import "../../registry/ModularENS.sol";

interface IUseRegistry {
    function registry() external view returns (ModularENS addr);
}
