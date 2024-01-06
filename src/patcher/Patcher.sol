// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/**
 * @title Patcher
 * @author Chomtana
 * @notice Contract responsible for managing patch lifecycle
 *
 * Patcher allow protocol owner to control patch across chains without having to manually execute tx on each chain.
 * Operator need to sign patch with nonce and the signature can be reused across chains.
 *
 * Patcher contract perform these operations
 * 1. Execute tx on behalf of the Patcher contract
 * 2. Deploy proxies with deterministic address
 * 3. Set proxies implementation
 */
contract Patcher {
    constructor() {}
}

contract PatcherWithConstructor {}
