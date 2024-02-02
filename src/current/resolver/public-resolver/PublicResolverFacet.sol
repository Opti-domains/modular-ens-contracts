// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import "./abi-resolver/ABIResolver.sol";
import "./addr-resolver/AddrResolver.sol";
import "./content-hash-resolver/ContentHashResolver.sol";
import "./dns-resolver/DNSResolver.sol";
import "./interface-resolver/InterfaceResolver.sol";
import "./name-resolver/NameResolver.sol";
import "./pubkey-resolver/PubkeyResolver.sol";
import "./text-resolver/TextResolver.sol";
import "./extended-resolver/ExtendedResolver.sol";
import "../attester/OptiResolverEAS.sol";
import "../auth/OptiResolverAuthBasic.sol";

contract PublicResolverFacet is
    ABIResolver,
    AddrResolver,
    ContentHashResolver,
    DNSResolver,
    InterfaceResolver,
    NameResolver,
    PubkeyResolver,
    TextResolver,
    ExtendedResolver,
    OptiResolverEAS,
    OptiResolverAuthBasicInternal
{
    function initialize() public virtual override(OptiResolverAuthBasicInternal) {
        OptiResolverAuthBasicInternal.initialize();

        _setSupportsInterface(type(IABIResolver).interfaceId, true);
        _setSupportsInterface(type(IAddrResolver).interfaceId, true);
        _setSupportsInterface(type(IAddressResolver).interfaceId, true);
        _setSupportsInterface(type(IContentHashResolver).interfaceId, true);
        _setSupportsInterface(type(IDNSRecordResolver).interfaceId, true);
        _setSupportsInterface(type(IDNSZoneResolver).interfaceId, true);
        _setSupportsInterface(type(IInterfaceResolver).interfaceId, true);
        _setSupportsInterface(type(INameResolver).interfaceId, true);
        _setSupportsInterface(type(IPubkeyResolver).interfaceId, true);
        _setSupportsInterface(type(ITextResolver).interfaceId, true);
        _setSupportsInterface(type(IExtendedResolver).interfaceId, true);
    }

    function supportsInterface(bytes4 interfaceID)
        public
        view
        override(
            ABIResolver,
            AddrResolver,
            ContentHashResolver,
            DNSResolver,
            InterfaceResolver,
            NameResolver,
            PubkeyResolver,
            TextResolver,
            ExtendedResolver
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceID);
    }
}
