// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";

import {IDiamondWritableInternal} from "@solidstate/contracts/proxy/diamond/writable/IDiamondWritableInternal.sol";

import "src/current/merkle/MerkleForest.sol";
import "src/current/registry/ModularENSRegistry.sol";
import "src/current/registrar/OpDomains.sol";

import {DiamondResolver, Diamond} from "src/current/diamond/DiamondResolver.sol";
import {UseRegistry, IUseRegistry} from "src/current/diamond/UseRegistry.sol";
import {OptiResolverAuthBasic, IOptiResolverAuthBasic} from "src/current/resolver/auth/OptiResolverAuthBasic.sol";
import {
    PublicResolverFacet,
    IABIResolver,
    IAddrResolver,
    IAddressResolver,
    IContentHashResolver,
    IDNSRecordResolver,
    IDNSZoneResolver,
    IInterfaceResolver,
    INameResolver,
    IPubkeyResolver,
    ITextResolver,
    IExtendedResolver
} from "src/current/resolver/public-resolver/PublicResolverFacet.sol";

contract DeployDevScript is Script {
    /// @notice Modifier that wraps a function in broadcasting.
    modifier broadcast() {
        vm.startBroadcast(msg.sender);
        _;
        vm.stopBroadcast();
    }

    function setUp() public {}

    function registerTld(string memory tld, Diamond diamond, ModularENSRegistry registry, address registrar) internal {
        bytes32 nameHash = keccak256(abi.encodePacked(bytes32(0), keccak256(abi.encodePacked(tld))));
        address tldResolver = diamond.clone(nameHash);

        registry.registerTLD(
            ModularENS.TLD({
                chainId: block.chainid,
                nameHash: nameHash,
                registrar: registrar,
                resolver: tldResolver,
                name: tld
            })
        );
    }

    function registerResolverUseRegistryFacet(Diamond diamond, ModularENSRegistry registry) internal {
        UseRegistry facet = new UseRegistry();

        bytes4[] memory selectors = new bytes4[](1);
        uint256 selectorIndex;

        // register selectors
        selectors[selectorIndex++] = IUseRegistry.registry.selector;

        IDiamondWritableInternal.FacetCut[] memory facetCuts = new IDiamondWritableInternal.FacetCut[](1);

        facetCuts[0] = IDiamondWritableInternal.FacetCut({
            target: address(facet),
            action: IDiamondWritableInternal.FacetCutAction.ADD,
            selectors: selectors
        });

        // Diamond cut and initialize registry
        diamond.diamondCut(facetCuts, address(facet), abi.encodeWithSelector(0xc4d66de8, registry));
    }

    function registerResolverAuthFacet(Diamond diamond) internal {
        OptiResolverAuthBasic facet = new OptiResolverAuthBasic();

        bytes4[] memory selectors = new bytes4[](1);
        uint256 selectorIndex;

        // register selectors
        selectors[selectorIndex++] = IOptiResolverAuthBasic.setApprovalForAll.selector;

        IDiamondWritableInternal.FacetCut[] memory facetCuts = new IDiamondWritableInternal.FacetCut[](1);

        facetCuts[0] = IDiamondWritableInternal.FacetCut({
            target: address(facet),
            action: IDiamondWritableInternal.FacetCutAction.ADD,
            selectors: selectors
        });

        // Diamond cut and initialize
        diamond.diamondCut(facetCuts, address(facet), abi.encodeWithSelector(0x8129fc1c));
    }

    function registerResolverFacet(Diamond diamond) internal {
        PublicResolverFacet facet = new PublicResolverFacet();

        bytes4[] memory selectors = new bytes4[](23);
        uint256 selectorIndex;

        // Register selectors (Since some of resolver method is not available on the interface, we need low level)
        selectors[selectorIndex++] = 0x2203ab56; // ABI(bytes32,uint256)
        selectors[selectorIndex++] = 0x3b3b57de; // addr(bytes32)
        selectors[selectorIndex++] = 0xf1cb7e06; // addr(bytes32,uint256)
        selectors[selectorIndex++] = 0xbc1c58d1; // contenthash(bytes32)
        selectors[selectorIndex++] = 0xa8fa5682; // dnsRecord(bytes32,bytes32,uint16)
        selectors[selectorIndex++] = 0x4cbf6ba4; // hasDNSRecords(bytes32,bytes32)
        selectors[selectorIndex++] = 0x124a319c; // interfaceImplementer(bytes32,bytes4)
        selectors[selectorIndex++] = 0x691f3431; // name(bytes32)
        selectors[selectorIndex++] = 0xc8690233; // pubkey(bytes32)
        selectors[selectorIndex++] = 0x623195b0; // setABI(bytes32,uint256,bytes)
        selectors[selectorIndex++] = 0x8b95dd71; // setAddr(bytes32,uint256,bytes)
        selectors[selectorIndex++] = 0xd5fa2b00; // setAddr(bytes32,address)
        selectors[selectorIndex++] = 0x0988c55d; // setAddrWithRef(bytes32,uint256,bytes32,bytes)
        selectors[selectorIndex++] = 0x304e6ade; // setContenthash(bytes32,bytes)
        selectors[selectorIndex++] = 0x0af179d7; // setDNSRecords(bytes32,bytes)
        selectors[selectorIndex++] = 0xe59d895d; // setInterface(bytes32,bytes4,address)
        selectors[selectorIndex++] = 0x77372213; // setName(bytes32,string)
        selectors[selectorIndex++] = 0x29cd62ea; // setPubkey(bytes32,bytes32,bytes32)
        selectors[selectorIndex++] = 0x10f13a8c; // setText(bytes32,string,string)
        selectors[selectorIndex++] = 0x966bf6d6; // setTextWithRef(bytes32,bytes32,string,string)
        selectors[selectorIndex++] = 0xce3decdc; // setZonehash(bytes32,bytes)
        selectors[selectorIndex++] = 0x59d1d43c; // text(bytes32,string)
        selectors[selectorIndex++] = 0x5c98042b; // zonehash(bytes32)

        IDiamondWritableInternal.FacetCut[] memory facetCuts = new IDiamondWritableInternal.FacetCut[](1);

        facetCuts[0] = IDiamondWritableInternal.FacetCut({
            target: address(facet),
            action: IDiamondWritableInternal.FacetCutAction.ADD,
            selectors: selectors
        });

        // Diamond cut and initialize
        diamond.diamondCut(facetCuts, address(facet), abi.encodeWithSelector(0x8129fc1c));
    }

    function run() public broadcast {
        // Deploy resolver factory
        Diamond diamond = new DiamondResolver(msg.sender);

        MerkleForest merkleForest = new MerkleForest();
        merkleForest.initialize();

        ModularENSRegistry registry = new ModularENSRegistry(msg.sender, merkleForest, diamond);

        // Add facets to the diamond
        registerResolverUseRegistryFacet(diamond, registry);
        registerResolverAuthFacet(diamond);
        registerResolverFacet(diamond);

        OpDomains opDomains = new OpDomains(registry);
        registerTld("op", diamond, registry, address(opDomains));

        // Print addresses
        console2.log("Registry address", address(registry));
        console2.log("Merkle Forest address", address(merkleForest));
        console2.log("OP Registrar address", address(opDomains));
    }
}
