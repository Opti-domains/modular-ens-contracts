//SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9.0;

import "@solidstate/contracts/proxy/diamond/ISolidStateDiamond.sol";
import "./IMulticallable.sol";
import "./INameWrapperRegistry.sol";

interface IDiamondResolver is ISolidStateDiamond, IMulticallable {
  function registry() external view returns(INameWrapperRegistry);
}