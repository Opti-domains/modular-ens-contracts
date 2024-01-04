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

contract PublicResolverFacet is
    ABIResolver,
    AddrResolver,
    ContentHashResolver,
    DNSResolver,
    InterfaceResolver,
    NameResolver,
    PubkeyResolver,
    TextResolver,
    ExtendedResolver
{
    function supportsInterface(
        bytes4 interfaceID
    )
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
