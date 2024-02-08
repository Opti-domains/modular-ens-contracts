// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "../../registry/ModularENS.sol";

interface IRegistrarHook {
    function updateRecord(ModularENS.Record calldata record) external;
}
