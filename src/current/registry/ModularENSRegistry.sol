// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "./ModularENS.sol";

contract ModularENSRegistry is ModularENS {
    error NotRegistrar();
    error SetResolverRestricted();

    struct Record {
        address owner;
        address resolver;
        uint64 ttl;
        uint256 expiration;
        bytes32 parentNode;
        bytes32 tldNode;
        uint256 merkleIndex;
        string name;
    }

    mapping(bytes32 => Record) records;
    mapping(address => mapping(address => bool)) operators;
    mapping(bytes32 => TLD) _tld;

    uint256[500] private __gap;

    modifier onlyRegistrar(bytes32 node) {
        address registrar = _tld[node].registrar;
        if (registrar != msg.sender || operators[registrar][msg.sender]) {
            revert NotRegistrar();
        }
        _;
    }

    modifier restrictResolverChange(bytes32 node, address resolver) {
        address oldResolver = records[node].resolver;
        if (oldResolver != resolver) {
            revert SetResolverRestricted();
        }
        _;
    }

    // ============= Getter functions =============

    function expiration(bytes32 node) external returns (uint256) {
        return records[node].expiration;
    }

    function parentNode(bytes32 node) external returns (bytes32) {
        return records[node].parentNode;
    }

    function tldNode(bytes32 node) external returns (bytes32) {
        return records[node].tldNode;
    }

    function tld(bytes32 tldHash) external returns (TLD memory) {
        return _tld[tldHash];
    }

    function merkleIndex(bytes32 node) external returns (uint256) {
        return records[node].merkleIndex;
    }

    // TODO
    function merkleRoot(bytes32 tldHash, uint256 index) external returns (bytes32) {
        return bytes32(0);
    }

    function name(bytes32 node) external returns (string memory) {
        return records[node].name;
    }

    function dnsEncoded(bytes32 node) external returns (bytes memory) {
        
    }

    // ============= ENS Compatibility functions =============

    /**
     * @dev [Registrar Only] Sets the record for a node.
     * @param node The node to update.
     * @param owner The address of the new owner.
     * @param resolver The address of the resolver.
     * @param ttl The TTL in seconds.
     */
    function setRecord(bytes32 node, address owner, address resolver, uint64 ttl)
        external
        virtual
        override
        onlyRegistrar(node)
        restrictResolverChange(node, resolver)
    {
        setOwner(node, owner);
        _setResolverAndTTL(node, resolver, ttl);
    }

    /**
     * @dev [Registrar Only] Sets the record for a subnode.
     * @param node The parent node.
     * @param label The hash of the label specifying the subnode.
     * @param owner The address of the new owner.
     * @param resolver The address of the resolver.
     * @param ttl The TTL in seconds.
     */
    function setSubnodeRecord(bytes32 node, bytes32 label, address owner, address resolver, uint64 ttl)
        external
        virtual
        override
        onlyRegistrar(node)
        restrictResolverChange(node, resolver)
    {
        bytes32 subnode = setSubnodeOwner(node, label, owner);
        _setResolverAndTTL(subnode, resolver, ttl);
    }

    /**
     * @dev [Registrar Only] Transfers ownership of a node to a new address. May only be called by the current owner of the node.
     * @param node The node to transfer ownership of.
     * @param owner The address of the new owner.
     */
    function setOwner(bytes32 node, address owner) public virtual override onlyRegistrar(node) {
        _setOwner(node, owner);
        emit Transfer(node, owner);
    }

    /**
     * @dev [Registrar Only] Transfers ownership of a subnode keccak256(node, label) to a new address. May only be called by the owner of the parent node.
     * @param node The parent node.
     * @param label The hash of the label specifying the subnode.
     * @param owner The address of the new owner.
     */
    function setSubnodeOwner(bytes32 node, bytes32 label, address owner)
        public
        virtual
        override
        onlyRegistrar(node)
        returns (bytes32)
    {
        bytes32 subnode = keccak256(abi.encodePacked(node, label));
        _setOwner(subnode, owner);
        emit NewOwner(node, label, owner);
        return subnode;
    }

    /**
     * @dev [Restricted] Sets the resolver address for the specified node.
     * @param node The node to update.
     * @param resolver The address of the resolver.
     */
    function setResolver(bytes32 node, address resolver) public virtual override {
        revert SetResolverRestricted();
    }

    /**
     * @dev [Registrar Only] Sets the TTL for the specified node.
     * @param node The node to update.
     * @param ttl The TTL in seconds.
     */
    function setTTL(bytes32 node, uint64 ttl) public virtual override onlyRegistrar(node) {
        emit NewTTL(node, ttl);
        records[node].ttl = ttl;
    }

    /**
     * @dev [Registrar Only] Enable or disable approval for a third party ("operator") to manage
     *  all of `msg.sender`'s ENS records. Emits the ApprovalForAll event.
     * @param operator Address to add to the set of authorized operators.
     * @param approved True if the operator is approved, false to revoke approval.
     */
    function setApprovalForAll(address operator, bool approved) external virtual override {
        operators[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /**
     * @dev Returns the address that owns the specified node.
     * @param node The specified node.
     * @return address of the owner.
     */
    function owner(bytes32 node) public view virtual override returns (address) {
        address addr = records[node].owner;
        if (addr == address(this)) {
            return address(0x0);
        }

        return addr;
    }

    /**
     * @dev Returns the address of the resolver for the specified node.
     * @param node The specified node.
     * @return address of the resolver.
     */
    function resolver(bytes32 node) public view virtual override returns (address) {
        return records[node].resolver;
    }

    /**
     * @dev Returns the TTL of a node, and any records associated with it.
     * @param node The specified node.
     * @return ttl of the node.
     */
    function ttl(bytes32 node) public view virtual override returns (uint64) {
        return records[node].ttl;
    }

    /**
     * @dev Returns whether a record has been imported to the registry.
     * @param node The specified node.
     * @return Bool if record exists
     */
    function recordExists(bytes32 node) public view virtual override returns (bool) {
        return records[node].owner != address(0x0);
    }

    /**
     * @dev Query if an address is an authorized operator for another address.
     * @param owner The address that owns the records.
     * @param operator The address that acts on behalf of the owner.
     * @return True if `operator` is an approved operator for `owner`, false otherwise.
     */
    function isApprovedForAll(address owner, address operator) external view virtual override returns (bool) {
        return operators[owner][operator];
    }

    function _setOwner(bytes32 node, address owner) internal virtual {
        records[node].owner = owner;
    }

    function _setResolverAndTTL(bytes32 node, address resolver, uint64 ttl) internal {
        if (resolver != records[node].resolver) {
            records[node].resolver = resolver;
            emit NewResolver(node, resolver);
        }

        if (ttl != records[node].ttl) {
            records[node].ttl = ttl;
            emit NewTTL(node, ttl);
        }
    }
}
