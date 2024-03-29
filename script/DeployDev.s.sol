// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {EIP712Helper} from "./utils/EIP712Helper.s.sol";

import {IDiamondWritableInternal} from "@solidstate/contracts/proxy/diamond/writable/IDiamondWritableInternal.sol";

import "src/current/merkle/MerkleForest.sol";
import "src/current/registry/ModularENSRegistry.sol";
import "src/current/registrar/OpDomains.sol";

import {DiamondResolver, Diamond} from "src/current/diamond/DiamondResolver.sol";
import {UseRegistryFacet, IUseRegistry} from "src/current/diamond/UseRegistry.sol";
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
import {UniversalResolver} from "@ensdomains/ens-contracts/utils/UniversalResolver.sol";
import {L2ReverseRegistrar} from "src/current/registrar/L2ReverseRegistrar.sol";

interface ResolverWriteActions {
    function setAddr(bytes32 node, address a) external;
    function setText(bytes32 node, string calldata key, string calldata value) external;
}

contract DeployDevScript is Script {
    bytes32 constant RootReverseNode = 0xa097f6721ce401e757d1223a763fef49b8b5f90bb18567ddb86fd205dff71d34;
    bytes32 constant TestOpNode = 0xfae0b61043b4c3f6c273df2f4250b206df74ff1581506844d930bf1f7356d5bf;

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

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
        UseRegistryFacet facet = new UseRegistryFacet();

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
        ModularENSRegistry registry = new ModularENSRegistry(msg.sender, merkleForest);

        merkleForest.initialize(address(registry));

        // Add facets to the diamond
        registerResolverUseRegistryFacet(diamond, registry);
        registerResolverAuthFacet(diamond);
        registerResolverFacet(diamond);

        // Register L2ReverseRegistrar
        L2ReverseRegistrar reverseRegistrar = new L2ReverseRegistrar(registry);
        registry.registerTLD(
            ModularENS.TLD({
                chainId: block.chainid,
                nameHash: RootReverseNode,
                registrar: address(reverseRegistrar),
                resolver: address(reverseRegistrar),
                name: "reverse"
            })
        );
        reverseRegistrar.registerAddrNode();

        // Register .op TLD
        OpDomains opDomains = new OpDomains(registry, msg.sender);
        registerTld("op", diamond, registry, address(opDomains));

        // Deploy UniversalResolver
        UniversalResolver universalResolver = new UniversalResolver(address(registry), new string[](0));

        // Init EIP712 helper for OpDomains
        uint256 eip712deadline = 2000000000;
        EIP712Helper opDomainsEIP712 = new EIP712Helper("OpDomains", "0.0.1", block.chainid, address(opDomains));

        // Test register .op domain
        bytes[] memory resolverCalldata = new bytes[](2);
        resolverCalldata[0] = abi.encodeWithSelector(ResolverWriteActions.setAddr.selector, TestOpNode, msg.sender);
        resolverCalldata[1] =
            abi.encodeWithSelector(ResolverWriteActions.setText.selector, TestOpNode, "com.twitter", "optidomains");

        // Backend operator sign domain registration commitment
        {
            bytes32 registrationCommitment =
                keccak256(abi.encode("test", msg.sender, 1893456000, 0, true, resolverCalldata));
            bytes32 registrationStructHash =
                keccak256(abi.encode(REGISTER_COMMITMENT_TYPEHASH, registrationCommitment, 0.002 ether, eip712deadline));
            bytes memory registrationSignature = opDomainsEIP712.sign(deployerPrivateKey, registrationStructHash);
            opDomains.register{value: 0.002 ether}(
                "test", msg.sender, 1893456000, 0, true, resolverCalldata, eip712deadline, registrationSignature
            );
        }

        // Backend operator sign extend expiry
        {
            bytes32 expirationStructHash =
                keccak256(abi.encode(EXTEND_EXPIRY_TYPEHASH, TestOpNode, 1993456000, 0.005 ether, eip712deadline));
            bytes memory expirationSignature = opDomainsEIP712.sign(deployerPrivateKey, expirationStructHash);
            opDomains.extendExpiry{value: 0.005 ether}(TestOpNode, 1993456000, eip712deadline, expirationSignature);
        }

        // Print addresses
        console2.log("Registry address", address(registry));
        console2.log("Merkle Forest address", address(merkleForest));
        console2.log("OP Registrar address", address(opDomains));
        console2.log("L2 Reverse Registrar address", address(reverseRegistrar));
        console2.log("Universal Resolver address", address(universalResolver));
    }
}
