// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import "./facets/public-resolver/abi-resolver/IABIResolver.sol";
import "./facets/public-resolver/addr-resolver/IAddrResolver.sol";
import "./facets/public-resolver/content-hash-resolver/IContentHashResolver.sol";
import "./facets/public-resolver/dns-resolver/IDNSRecordResolver.sol";
import "./facets/public-resolver/dns-resolver/IDNSZoneResolver.sol";
import "./facets/public-resolver/interface-resolver/IInterfaceResolver.sol";
import "./facets/public-resolver/name-resolver/INameResolver.sol";
import "./facets/public-resolver/pubkey-resolver/IPubkeyResolver.sol";
import "./facets/public-resolver/text-resolver/ITextResolver.sol";
import "./facets/public-resolver/extended-resolver/IExtendedResolver.sol";
import "./facets/base/IDiamondResolverBase.sol";

// For unit test only
interface IDiamondResolverForTest is
    IABIResolver,
    IAddrResolver,
    IContentHashResolver,
    IDNSRecordResolver,
    IDNSZoneResolver,
    IInterfaceResolver,
    INameResolver,
    ITextResolver,
    IExtendedResolver,
    IDiamondResolverBase
{

}
