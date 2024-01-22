// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "./ModularENS.sol";
import "../merkle/MerkleForest.sol";
import "../diamond/interfaces/IDiamondCloneFactory.sol";
import "@ensdomains/ens-contracts/utils/NameEncoder.sol";

contract ModularENSRegistry is ModularENS {
    address public immutable root;
    MerkleForest public immutable merkleForest;
    IDiamondCloneFactory public immutable baseResolver;

    mapping(bytes32 => Record) records;
    mapping(address => mapping(address => bool)) operators;
    mapping(bytes32 => TLD) _tld;
    mapping(bytes32 => uint256) latestTldNonce;
    mapping(bytes32 => bytes32) public nodeMerkleRoot;
    mapping(bytes32 => bool) public isRootFraud;

    uint256[500] private __gap;

    error NotRoot();
    error NotRegistrar();
    error SetResolverRestricted();
    error NotPrimaryChain();
    error BadTLD();

    event RecordChanged(bytes32 indexed tldNode, bytes32 indexed namehash, address indexed owner, Record record);
    event NewTLD(bytes32 indexed tldNode, bytes32 indexed namehash, address indexed registrar, TLD tld);

    modifier onlyRoot() {
        if (msg.sender != root) {
            revert NotRoot();
        }
        _;
    }

    modifier onlyRegistrar(bytes32 node) {
        address registrar = _tld[node].registrar;
        if (registrar != msg.sender || operators[registrar][msg.sender]) {
            revert NotRegistrar();
        }
        if (_tld[node].chainId != block.chainid) {
            revert NotPrimaryChain();
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

    // ============= Immutable constructor =============

    // ============= Getter functions =============

    function expiration(bytes32 node) public view returns (uint256) {
        return records[node].expiration;
    }

    function parentNode(bytes32 node) public view returns (bytes32) {
        return records[node].parentNode;
    }

    function tldNode(bytes32 node) public view returns (bytes32) {
        return records[node].tldNode;
    }

    function tld(bytes32 tldHash) public view returns (TLD memory) {
        return _tld[tldHash];
    }

    function name(bytes32 node) public view returns (string memory) {
        return records[node].name;
    }

    function dnsEncoded(bytes32 node) public view returns (bytes memory dnsName) {
        (dnsName,) = NameEncoder.dnsEncodeName(records[node].name);
    }

    /**
     * @dev Returns the address that owns the specified node.
     * @param node The specified node.
     * @return address of the owner.
     */
    function owner(bytes32 node) public view virtual override returns (address) {
        if (block.timestamp > records[node].expiration && records[node].expiration != 0) {
            return address(0);
        }

        if (isRootFraud[nodeMerkleRoot[node]]) {
            return address(0);
        }

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
        if (block.timestamp > records[node].expiration && records[node].expiration != 0) {
            return address(0);
        }

        if (isRootFraud[nodeMerkleRoot[node]]) {
            return address(0);
        }

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

    // ============= Write functions =============

    function registerTLD(TLD memory _tldObj) public onlyRoot {
        bytes32 _tldNode = sha256(abi.encode(_tldObj.chainId, _tldObj.nameHash));
        bytes32 _nameHash = keccak256(abi.encodePacked(bytes32(0), keccak256(abi.encodePacked(_tldObj.name))));

        if (_tld[_tldNode].nameHash != bytes32(0) || _nameHash != _tld[_tldNode].nameHash) {
            revert BadTLD();
        }

        _tld[_tldNode] = _tldObj;

        address _resolver = baseResolver.clone(_nameHash);

        // Create a TLD record
        Record memory _record = Record({
            owner: _tldObj.registrar,
            resolver: _resolver,
            ttl: 0,
            expiration: 0,
            fuses: 0,
            parentNode: bytes32(0),
            tldNode: _tldNode,
            nonce: 0,
            name: _tldObj.name
        });

        records[_nameHash] = _record;

        // Emit NewTLD and RecordChanged events
        emit NewTLD(_tldNode, _nameHash, _tldObj.registrar, _tldObj);
        emit RecordChanged(_tldNode, _nameHash, _tldObj.registrar, _record);
    }

    function update(bytes32 _node, address _owner, uint256 _expiration, uint256 _fuses, uint64 _ttl)
        public
        onlyRegistrar(_node)
        returns (bytes32 merkleRoot)
    {}

    function register(
        bytes32 _parentNode,
        string memory _label,
        address _owner,
        uint256 _expiration,
        uint256 _fuses,
        uint64 _ttl
    ) public onlyRegistrar(_parentNode) returns (bytes32 merkleRoot) {
        bytes32 _nameHash = keccak256(abi.encodePacked(_parentNode, keccak256(abi.encodePacked(_label))));

        if (records[_nameHash].resolver != address(0)) {
            update(_nameHash, _owner, _expiration, _fuses, _ttl);
        } else {
            bytes32 _tldNode = tldNode(_parentNode);

            address _resolver = baseResolver.clone(_nameHash);

            Record memory _record = Record({
                owner: _owner,
                resolver: _resolver,
                ttl: _ttl,
                expiration: _expiration,
                fuses: _fuses,
                parentNode: _parentNode,
                tldNode: _tldNode,
                nonce: latestTldNonce[_tldNode]++,
                name: string.concat(_label, ".", name(_parentNode))
            });

            records[_nameHash] = _record;

            // Append to merkle tree
            merkleRoot = merkleForest.insertLeaf(_tldNode, sha256(abi.encode(_record)));

            nodeMerkleRoot[_nameHash] = merkleRoot;

            // Emit RecordChanged event
            emit RecordChanged(_tldNode, _nameHash, _owner, _record);
        }
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
     * @param resolver The address of the resolver (Not used).
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
