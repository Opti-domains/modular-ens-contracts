//SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "./public-resolver/abi-resolver/IABIResolver.sol";
import "./public-resolver/addr-resolver/IAddressResolver.sol";
import "./public-resolver/addr-resolver/IAddrResolver.sol";
import "./public-resolver/content-hash-resolver/IContentHashResolver.sol";
import "./public-resolver/dns-resolver/IDNSRecordResolver.sol";
import "./public-resolver/dns-resolver/IDNSZoneResolver.sol";
import "./public-resolver/interface-resolver/IInterfaceResolver.sol";
import "./public-resolver/name-resolver/INameResolver.sol";
import "./public-resolver/pubkey-resolver/IPubkeyResolver.sol";
import "./public-resolver/text-resolver/ITextResolver.sol";
import "./public-resolver/extended-resolver/IExtendedResolver.sol";

/**
 * A generic resolver interface which includes all the functions including the ones deprecated
 */
interface Resolver is
    IERC165,
    IABIResolver,
    IAddressResolver,
    IAddrResolver,
    IContentHashResolver,
    IDNSRecordResolver,
    IDNSZoneResolver,
    IInterfaceResolver,
    INameResolver,
    IPubkeyResolver,
    ITextResolver,
    IExtendedResolver
{
    /* Deprecated events */
    event ContentChanged(bytes32 indexed node, bytes32 hash);

    function setApprovalForAll(address, bool) external;

    function approve(bytes32 node, address delegate, bool approved) external;

    function isApprovedForAll(address account, address operator) external;

    function isApprovedFor(address owner, bytes32 node, address delegate) external;

    function setABI(bytes32 node, uint256 contentType, bytes calldata data) external;

    function setAddr(bytes32 node, address addr) external;

    function setAddr(bytes32 node, uint256 coinType, bytes calldata a) external;

    function setContenthash(bytes32 node, bytes calldata hash) external;

    function setDnsrr(bytes32 node, bytes calldata data) external;

    function setName(bytes32 node, string calldata _name) external;

    function setPubkey(bytes32 node, bytes32 x, bytes32 y) external;

    function setText(bytes32 node, string calldata key, string calldata value) external;

    function setInterface(bytes32 node, bytes4 interfaceID, address implementer) external;

    function multicall(bytes[] calldata data) external returns (bytes[] memory results);

    function multicallWithNodeCheck(bytes32 nodehash, bytes[] calldata data)
        external
        returns (bytes[] memory results);

    /* Deprecated functions */
    function content(bytes32 node) external view returns (bytes32);

    function multihash(bytes32 node) external view returns (bytes memory);

    function setContent(bytes32 node, bytes32 hash) external;

    function setMultihash(bytes32 node, bytes calldata hash) external;
}
