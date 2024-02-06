pragma solidity >=0.8.4;

import "../registry/ModularENS.sol";
import "./interfaces/IL2ReverseRegistrar.sol";
import "./interfaces/IL2ReverseRegistrarPrivileged.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../resolver/public-resolver/text-resolver/ITextResolver.sol";
import "../resolver/public-resolver/name-resolver/INameResolver.sol";
import "../diamond/interfaces/IDiamondCloneFactory.sol";
import "../diamond/Multicallable.sol";

error InvalidSignature();
error SignatureOutOfDate();
error Unauthorised();
error NotOwnerOfContract();
error SetTextNotSupported();

library StringsForReverseRegistrar {
    bytes16 private constant HEX_DIGITS = "0123456789abcdef";
    uint8 private constant ADDRESS_LENGTH = 20;

    /**
     * @dev The `value` string doesn't fit in the specified `length`.
     */
    error StringsInsufficientHexLength(uint256 value, uint256 length);

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        uint256 localValue = value;
        bytes memory buffer = new bytes(2 * length);
        for (uint256 i = 2 * length - 1; i >= 0; --i) {
            buffer[i] = HEX_DIGITS[localValue & 0xf];
            localValue >>= 4;
        }
        if (localValue != 0) {
            revert StringsInsufficientHexLength(value, length);
        }
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal
     * representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), ADDRESS_LENGTH);
    }
}

// @note Inception date
// The inception date is in milliseconds, and so will be divided by 1000
// when comparing to block.timestamp. This means that the date will be
// rounded down to the nearest second.

contract L2ReverseRegistrar is
    Multicallable,
    Ownable,
    ITextResolver,
    INameResolver,
    IL2ReverseRegistrar,
    IL2ReverseRegistrarPrivileged,
    IDiamondCloneFactory
{
    using ECDSA for bytes32;

    ModularENS public immutable registry;

    mapping(bytes32 => uint256) public lastUpdated;
    mapping(uint64 => mapping(bytes32 => mapping(string => string))) versionable_texts;
    mapping(uint64 => mapping(bytes32 => string)) versionable_names;
    mapping(bytes32 => uint64) internal recordVersions;

    event VersionChanged(bytes32 indexed node, uint64 newVersion);
    event ReverseClaimed(address indexed addr, bytes32 indexed node);

    // addr.reverse namehash
    bytes32 constant L2ReverseNode = 0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2;

    // reverse namehash
    bytes32 constant RootReverseNode = 0xa097f6721ce401e757d1223a763fef49b8b5f90bb18567ddb86fd205dff71d34;

    // This is the hex encoding of the string 'abcdefghijklmnopqrstuvwxyz'
    // It is used as a constant to lookup the characters of the hex address
    bytes32 constant lookup = 0x3031323334353637383961626364656600000000000000000000000000000000;

    /**
     * @dev Constructor
     */
    constructor(ModularENS _registry) {
        registry = _registry;
        registry.register(RootReverseNode, address(this), 0, "addr", "");
    }

    modifier authorised(address addr) {
        isAuthorised(addr);
        _;
    }

    modifier authorisedSignature(bytes32 hash, address addr, uint256 inceptionDate, bytes memory signature) {
        isAuthorisedWithSignature(hash, addr, inceptionDate, signature);
        _;
    }

    modifier ownerAndAuthorisedWithSignature(
        bytes32 hash,
        address addr,
        address owner,
        uint256 inceptionDate,
        bytes memory signature
    ) {
        isOwnerAndAuthorisedWithSignature(hash, addr, owner, inceptionDate, signature);
        _;
    }

    function isAuthorised(address addr) internal view returns (bool) {
        if (addr != msg.sender && !ownsContract(addr, msg.sender)) {
            revert Unauthorised();
        }
    }

    function isAuthorisedWithSignature(bytes32 hash, address addr, uint256 inceptionDate, bytes memory signature)
        internal
        view
        returns (bool)
    {
        bytes32 message = keccak256(abi.encodePacked(hash, addr, inceptionDate, block.chainid)).toEthSignedMessageHash();
        bytes32 node = _getNamehash(addr);

        if (!SignatureChecker.isValidSignatureNow(addr, message, signature)) {
            revert InvalidSignature();
        }

        if (
            inceptionDate <= lastUpdated[node] // must be newer than current record
                || inceptionDate / 1000 >= block.timestamp // must be in the past
        ) {
            revert SignatureOutOfDate();
        }
    }

    function isOwnerAndAuthorisedWithSignature(
        bytes32 hash,
        address addr,
        address owner,
        uint256 inceptionDate,
        bytes memory signature
    ) internal view returns (bool) {
        bytes32 message =
            keccak256(abi.encodePacked(hash, addr, owner, inceptionDate, block.chainid)).toEthSignedMessageHash();
        bytes32 node = _getNamehash(addr);

        if (!ownsContract(addr, owner)) {
            revert NotOwnerOfContract();
        }

        if (!SignatureChecker.isValidERC1271SignatureNow(owner, message, signature)) {
            revert InvalidSignature();
        }

        if (
            inceptionDate <= lastUpdated[node] // must be newer than current record
                || inceptionDate / 1000 >= block.timestamp // must be in the past
        ) {
            revert SignatureOutOfDate();
        }
    }

    /**
     * @dev Sets the name for an addr using a signature that can be verified with ERC1271.
     * @param addr The reverse record to set
     * @param name The name of the reverse record
     * @param inceptionDate Date from when this signature is valid from
     * @param signature The resolver of the reverse node
     * @return The ENS node hash of the reverse record.
     */
    function setNameForAddrWithSignature(
        address addr,
        string memory name,
        uint256 inceptionDate,
        bytes memory signature
    )
        public
        override
        authorisedSignature(
            keccak256(abi.encodePacked(IL2ReverseRegistrar.setNameForAddrWithSignature.selector, name)),
            addr,
            inceptionDate,
            signature
        )
        returns (bytes32)
    {
        bytes32 node = _getNamehash(addr);

        _setName(addr, node, name, inceptionDate);
        return node;
    }

    /**
     * @dev Sets the name for a contract that is owned by a SCW using a signature
     * @param contractAddr The reverse node to set
     * @param owner The owner of the contract (via Ownable)
     * @param name The name of the reverse record
     * @param inceptionDate Date from when this signature is valid from
     * @param signature The signature of an address that will return true on isValidSignature for the owner
     * @return The ENS node hash of the reverse record.
     */
    function setNameForAddrWithSignatureAndOwnable(
        address contractAddr,
        address owner,
        string memory name,
        uint256 inceptionDate,
        bytes memory signature
    )
        public
        ownerAndAuthorisedWithSignature(
            keccak256(abi.encodePacked(IL2ReverseRegistrar.setNameForAddrWithSignatureAndOwnable.selector, name)),
            contractAddr,
            owner,
            inceptionDate,
            signature
        )
        returns (bytes32)
    {
        bytes32 node = _getNamehash(contractAddr);
        _setName(contractAddr, node, name, inceptionDate);
    }

    /**
     * @dev Sets the `name()` record for the reverse ENS record associated with
     * the calling account.
     * @param name The name to set for this address.
     * @return The ENS node hash of the reverse record.
     */
    function setName(string memory name) public override returns (bytes32) {
        return setNameForAddr(msg.sender, name);
    }

    /**
     * @dev Sets the `name()` record for the reverse ENS record associated with
     * the addr provided account.
     * Can be used if the addr is a contract that is owned by a SCW.
     * @param name The name to set for this address.
     * @return The ENS node hash of the reverse record.
     */
    function setNameForAddr(address addr, string memory name) public authorised(addr) returns (bytes32) {
        bytes32 node = _getNamehash(addr);
        _setName(addr, node, name, block.timestamp);
        return node;
    }

    /**
     * @dev Sets the `name()` record for the reverse ENS record associated with
     * the addr provided account with registrar's privileged permission.
     * @param name The name to set for this address.
     * @return The ENS node hash of the reverse record.
     */
    function setNameFromRegistrar(bytes32 tldNode, address addr, string memory name) public returns (bytes32) {
        if (registry.tld(tldNode).registrar != msg.sender) {
            revert Unauthorised();
        }

        bytes32 node = _getNamehash(addr);
        _setName(addr, node, name, block.timestamp);
        return node;
    }

    /**
     * @dev Sets the name for an addr using a signature that can be verified with ERC1271.
     * @param addr The reverse record to set
     * @param key The key of the text record
     * @param value The value of the text record
     * @param inceptionDate Date from when this signature is valid from
     * @param signature The resolver of the reverse node
     * @return The ENS node hash of the reverse record.
     */
    function setTextForAddrWithSignature(
        address addr,
        string calldata key,
        string calldata value,
        uint256 inceptionDate,
        bytes memory signature
    )
        public
        override
        authorisedSignature(
            keccak256(abi.encodePacked(IL2ReverseRegistrar.setTextForAddrWithSignature.selector, key, value)),
            addr,
            inceptionDate,
            signature
        )
        returns (bytes32)
    {
        bytes32 node = _getNamehash(addr);
        _setText(node, key, value, inceptionDate);
        return node;
    }

    /**
     * @dev Sets the name for a contract that is owned by a SCW using a signature
     * @param contractAddr The reverse node to set
     * @param owner The owner of the contract (via Ownable)
     * @param key The name of the reverse record
     * @param value The name of the reverse record
     * @param inceptionDate Date from when this signature is valid from
     * @param signature The signature of an address that will return true on isValidSignature for the owner
     * @return The ENS node hash of the reverse record.
     */
    function setTextForAddrWithSignatureAndOwnable(
        address contractAddr,
        address owner,
        string calldata key,
        string calldata value,
        uint256 inceptionDate,
        bytes memory signature
    )
        public
        ownerAndAuthorisedWithSignature(
            keccak256(abi.encodePacked(IL2ReverseRegistrar.setTextForAddrWithSignatureAndOwnable.selector, key, value)),
            contractAddr,
            owner,
            inceptionDate,
            signature
        )
        returns (bytes32)
    {
        bytes32 node = _getNamehash(contractAddr);
        _setText(node, key, value, inceptionDate);
    }

    /**
     * @dev Sets the `name()` record for the reverse ENS record associated with
     * the calling account.
     * @param key The key for this text record.
     * @param value The value to set for this text record.
     * @return The ENS node hash of the reverse record.
     */
    function setText(string calldata key, string calldata value) public override returns (bytes32) {
        return setTextForAddr(msg.sender, key, value);
    }

    /**
     * @dev Sets the `text(key)` record for the reverse ENS record associated with
     * the addr provided account with registrar's privileged permission.
     * @param key The key for this text record.
     * @param value The value to set for this text record.
     * @return The ENS node hash of the reverse record.
     */
    function setTextFromRegistrar(bytes32 tldNode, address addr, string calldata key, string calldata value)
        public
        returns (bytes32)
    {
        if (registry.tld(tldNode).registrar != msg.sender) {
            revert Unauthorised();
        }

        bytes32 node = _getNamehash(addr);
        _setText(node, key, value, block.timestamp);
        return node;
    }

    /**
     * @dev Sets the `text(key)` record for the reverse ENS record associated with
     * the addr provided account.
     * @param key The key for this text record.
     * @param value The value to set for this text record.
     * @return The ENS node hash of the reverse record.
     */
    function setTextForAddr(address addr, string calldata key, string calldata value)
        public
        override
        authorised(addr)
        returns (bytes32)
    {
        bytes32 node = _getNamehash(addr);
        _setText(node, key, value, block.timestamp);
        return node;
    }

    function _setText(bytes32 node, string calldata key, string calldata value, uint256 inceptionDate) internal {
        // Not supported in this version to prevent further bugs
        revert SetTextNotSupported();

        versionable_texts[recordVersions[node]][node][key] = value;
        _setLastUpdated(node, inceptionDate);
        emit TextChanged(node, key, key, value);
    }

    /**
     * Returns the text data associated with an ENS node and key.
     * @param node The ENS node to query.
     * @param key The text data key to query.
     * @return The associated text data.
     */
    function text(bytes32 node, string calldata key) external view virtual override returns (string memory) {
        return versionable_texts[recordVersions[node]][node][key];
    }

    /**
     * Sets the name associated with an ENS node, for reverse records.
     * May only be called by the owner of that node in the ENS registry.
     * @param node The node to update.
     * @param newName name record
     */
    function _setName(address addr, bytes32 node, string memory newName, uint256 inceptionDate) internal virtual {
        versionable_names[recordVersions[node]][node] = newName;
        _setLastUpdated(node, inceptionDate);

        registry.register(L2ReverseNode, addr, 0, StringsForReverseRegistrar.toHexString(addr), abi.encode(newName));

        emit NameChanged(node, newName);
    }

    /**
     * Returns the name associated with an ENS node, for reverse records.
     * Defined in EIP181.
     * @param node The ENS node to query.
     * @return The associated name.
     */
    function name(bytes32 node) external view virtual override returns (string memory) {
        return versionable_names[recordVersions[node]][node];
    }

    /**
     * Increments the record version associated with an ENS node.
     * May only be called by the owner of that node in the ENS registry.
     * @param addr The node to update.
     */
    function clearRecords(address addr) public virtual authorised(addr) {
        bytes32 labelHash = sha3HexAddress(addr);
        bytes32 reverseNode = keccak256(abi.encodePacked(L2ReverseNode, labelHash));
        recordVersions[reverseNode]++;
        emit VersionChanged(reverseNode, recordVersions[reverseNode]);
    }

    /**
     * Increments the record version associated with an ENS node.
     * May only be called by the owner of that node in the ENS registry.
     * @param addr The node to update.
     * @param signature A signature proving ownership of the node.
     */
    function clearRecordsWithSignature(address addr, uint256 inceptionDate, bytes memory signature)
        public
        virtual
        authorisedSignature(
            keccak256(abi.encodePacked(IL2ReverseRegistrar.clearRecordsWithSignature.selector)),
            addr,
            inceptionDate,
            signature
        )
    {
        bytes32 labelHash = sha3HexAddress(addr);
        bytes32 reverseNode = keccak256(abi.encodePacked(L2ReverseNode, labelHash));
        recordVersions[reverseNode]++;
        emit VersionChanged(reverseNode, recordVersions[reverseNode]);
    }

    /**
     * @dev Returns the node hash for a given account's reverse records.
     * @param addr The address to hash
     * @return The ENS node hash.
     */
    function node(address addr) public view override returns (bytes32) {
        return keccak256(abi.encodePacked(L2ReverseNode, sha3HexAddress(addr)));
    }

    function ownsContract(address contractAddr, address addr) internal view returns (bool) {
        try Ownable(contractAddr).owner() returns (address owner) {
            return owner == addr;
        } catch {
            return false;
        }
    }

    function _getNamehash(address addr) internal view returns (bytes32) {
        bytes32 labelHash = sha3HexAddress(addr);
        return keccak256(abi.encodePacked(L2ReverseNode, labelHash));
    }

    function _setLastUpdated(bytes32 node, uint256 inceptionDate) internal {
        lastUpdated[node] = inceptionDate;
    }

    /**
     * @dev An optimised function to compute the sha3 of the lower-case
     *      hexadecimal representation of an Ethereum address.
     * @param addr The address to hash
     * @return ret The SHA3 hash of the lower-case hexadecimal encoding of the
     *         input address.
     */
    function sha3HexAddress(address addr) internal pure returns (bytes32 ret) {
        assembly {
            for { let i := 40 } gt(i, 0) {} {
                i := sub(i, 1)
                mstore8(i, byte(and(addr, 0xf), lookup))
                addr := div(addr, 0x10)
                i := sub(i, 1)
                mstore8(i, byte(and(addr, 0xf), lookup))
                addr := div(addr, 0x10)
            }

            ret := keccak256(0, 40)
        }
    }

    function supportsInterface(bytes4 interfaceID) public pure returns (bool) {
        return interfaceID == type(IL2ReverseRegistrar).interfaceId || interfaceID == type(ITextResolver).interfaceId
            || interfaceID == type(INameResolver).interfaceId || interfaceID == type(IMulticallable).interfaceId
            || interfaceID == type(IL2ReverseRegistrarPrivileged).interfaceId;
    }

    function clone(bytes32) external override returns (address) {
        return address(this);
    }

    function getCloneAddress(bytes32) external view override returns (address predictedAddress) {
        return address(this);
    }
}
