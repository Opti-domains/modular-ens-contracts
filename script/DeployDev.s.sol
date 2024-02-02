// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "src/current/diamond/DiamondResolver.sol";
import "src/current/merkle/MerkleForest.sol";
import "src/current/registry/ModularENSRegistry.sol";
import "src/current/registrar/OpDomains.sol";

contract DeployDevScript is Script {
    /// @notice Modifier that wraps a function in broadcasting.
    modifier broadcast() {
        vm.startBroadcast(msg.sender);
        _;
        vm.stopBroadcast();
    }

    function setUp() public {}

    function run() public broadcast {
        // Deploy resolver factory
        Diamond diamond = new DiamondResolver(msg.sender);

        MerkleForest merkleForest = new MerkleForest();
        merkleForest.initialize();

        ModularENSRegistry registry = new ModularENSRegistry(msg.sender, merkleForest, diamond);

        OpDomains opDomains = new OpDomains(registry);
        address opDomainsResolver = diamond.clone(bytes32(0));

        registry.registerTLD(
            ModularENS.TLD({
                chainId: block.chainid,
                nameHash: keccak256(abi.encodePacked(bytes32(0), keccak256(abi.encodePacked("op")))),
                registrar: address(opDomains),
                resolver: opDomainsResolver,
                name: "op"
            })
        );
    }
}
