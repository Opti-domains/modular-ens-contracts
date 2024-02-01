// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "./ModularENS.sol";
import "../merkle/MerkleForest.sol";
import "../diamond/interfaces/IDiamondCloneFactory.sol";
import "../registrar/IRegistrarHook.sol";
import "@ensdomains/ens-contracts/utils/NameEncoder.sol";

contract ModularENSRegistry is ModularENS {
    address public immutable root;
    MerkleForest public immutable merkleForest;
    IDiamondCloneFactory public immutable baseResolver;

    mapping(bytes32 => Record) records;
    mapping(address => mapping(address => bool)) operators;
    mapping(bytes32 => TLD) _tld;
    mapping(bytes32 => bytes32) public nodeMerkleRoot;

    uint256[500] private __gap;

    error NotRoot();
    error NotRegistrar();
    error NotRegistered();
    error AlreadyRegistered();
    error RegistrarNotDeployed();
    error ResolverRequired();
    error NotPrimaryChain();
    error BadTLD();
    error Impossible();

    event RecordChanged(
        bytes32 indexed tldNode, bytes32 indexed namehash, address indexed owner, bytes32 merkleRoot, Record record
    );
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

    // ============= Immutable constructor =============

    constructor(address _root, MerkleForest _merkleForest, IDiamondCloneFactory _baseResolver) {
        root = _root;
        merkleForest = _merkleForest;
        baseResolver = _baseResolver;
    }

    // ============= Getter functions =============

    function _validNode(bytes32 node) internal view returns (bool) {
        uint256 _expiration = expiration(node);
        return (block.timestamp <= _expiration || _expiration != 0) && !merkleForest.isFraud(nodeMerkleRoot[node]);
    }

    function expiration(bytes32 node) public view returns (uint256) {
        if (node == bytes32(0)) return 0;

        uint256 _parentExpiration = expiration(records[node].parentNode);
        uint256 _expiration = records[node].expiration;

        if (_parentExpiration == 0) {
            return _expiration;
        } else if (_expiration == 0 || _parentExpiration <= _expiration) {
            return _parentExpiration;
        } else {
            return _expiration;
        }
    }

    function record(bytes32 node) external view returns (Record memory) {
        return records[node];
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

    function data(bytes32 node) public view returns (bytes memory) {
        return records[node].data;
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
        if (!_validNode(node)) return address(0);

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
        if (!_validNode(node)) return address(0);
        return records[node].resolver;
    }

    /**
     * @dev Returns the TTL of a node, and any records associated with it.
     * @param node The specified node.
     * @return ttl of the node.
     */
    function ttl(bytes32 node) public view virtual override returns (uint64) {
        if (!_validNode(node)) return 0;
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

    function _updateMerkle(
        bytes32 _nameHash,
        bytes32 _recordHash,
        bytes32 _tldNode,
        bytes32 _parentNode,
        uint256 _recordNonce
    ) internal returns (bytes32 _merkleRoot, uint256 _nonce) {
        // Append to merkle tree
        (_merkleRoot, _nonce) = merkleForest.insertLeaf(_tldNode, _recordHash);

        // Append to parent node for future use cases
        merkleForest.insertLeaf(_parentNode, _recordHash);

        // Check for impossible case
        if (_nonce != _recordNonce) {
            revert Impossible();
        }

        // Update merkle root
        nodeMerkleRoot[_nameHash] = _merkleRoot;
    }

    function _sendHook(bytes32 _nameHash, Record memory _record) internal {
        // Send hook
        address _registrar = _tld[_record.tldNode].registrar;
        if (_registrar.code.length > 0) {
            IRegistrarHook(_registrar).updateRecord(_nameHash, _record);
        } else if (_registrar != address(0)) {
            revert RegistrarNotDeployed();
        }
    }

    function registerTLD(TLD memory _tldObj) public onlyRoot {
        bytes32 _tldNode = sha256(abi.encode(_tldObj.chainId, _tldObj.nameHash));
        bytes32 _nameHash = keccak256(abi.encodePacked(bytes32(0), keccak256(abi.encodePacked(_tldObj.name))));

        if (_tld[_tldNode].nameHash != bytes32(0) || _nameHash != _tldObj.nameHash || _tldObj.resolver == address(0)) {
            revert BadTLD();
        }

        _tld[_tldNode] = _tldObj;

        // Create a TLD record
        Record memory _record = Record({
            owner: _tldObj.registrar,
            resolver: _tldObj.resolver,
            ttl: 0,
            expiration: 0,
            parentNode: bytes32(0),
            tldNode: _tldNode,
            nonce: 0,
            name: _tldObj.name,
            data: ""
        });

        records[_nameHash] = _record;

        // Emit NewTLD event
        emit NewTLD(_tldNode, _nameHash, _tldObj.registrar, _tldObj);
    }

    function update(bytes32 _nameHash, address _owner, uint256 _expiration, uint64 _ttl)
        public
        onlyRegistrar(_nameHash)
        returns (bytes32 _merkleRoot, uint256 _nonce)
    {
        if (records[_nameHash].resolver == address(0)) {
            revert NotRegistered();
        }

        Record storage _record = records[_nameHash];

        // Emit transition events
        if (_record.owner != _owner) {
            emit Transfer(_nameHash, _owner);
        }

        if (_record.ttl != _ttl) {
            emit NewTTL(_nameHash, _ttl);
        }

        // Update record values
        _record.owner = _owner;
        _record.expiration = _expiration;
        _record.ttl = _ttl;
        _record.nonce = merkleForest.latestNonce(_record.tldNode);

        // Calculate recordHash with sha256 for most compatiblility across chains
        bytes32 _recordHash = sha256(abi.encode(_record));

        // Append to merkle tree
        (_merkleRoot, _nonce) =
            _updateMerkle(_nameHash, _recordHash, _record.tldNode, _record.parentNode, _record.nonce);

        // Send hook
        _sendHook(_nameHash, _record);

        // Emit RecordChanged event
        emit RecordChanged(_record.tldNode, _nameHash, _owner, _merkleRoot, _record);
    }

    function register(
        bytes32 _parentNode,
        address _owner,
        uint256 _expiration,
        uint64 _ttl,
        string memory _label,
        bytes memory _data
    ) public onlyRegistrar(_parentNode) returns (bytes32 _nameHash, bytes32 _merkleRoot, uint256 _nonce) {
        bytes32 _labelHash = keccak256(abi.encodePacked(_label));
        _nameHash = keccak256(abi.encodePacked(_parentNode, _labelHash));

        if (records[_nameHash].resolver != address(0)) {
            revert AlreadyRegistered();
        } else {
            bytes32 _tldNode = tldNode(_parentNode);

            address _resolver = baseResolver.clone(_nameHash);

            Record memory _record = Record({
                owner: _owner,
                resolver: _resolver,
                ttl: _ttl,
                expiration: _expiration,
                parentNode: _parentNode,
                tldNode: _tldNode,
                nonce: merkleForest.latestNonce(_tldNode),
                name: string.concat(_label, ".", name(_parentNode)),
                data: _data
            });

            records[_nameHash] = _record;

            // Calculate recordHash with sha256 for most compatiblility across chains
            bytes32 _recordHash = sha256(abi.encode(_record));

            // Append to merkle tree
            (_merkleRoot, _nonce) = _updateMerkle(_nameHash, _recordHash, _tldNode, _parentNode, _record.nonce);

            // Send hook
            _sendHook(_nameHash, _record);

            // Emit events
            emit RecordChanged(_tldNode, _nameHash, _owner, _merkleRoot, _record);
            emit NewOwner(_parentNode, _labelHash, _owner);
            emit Transfer(_nameHash, _owner);
            emit NewResolver(_nameHash, _resolver);
            emit NewTTL(_nameHash, _ttl);
        }
    }

    // ============= Single update functions =============

    function setOwner(bytes32 _node, address _owner) public {
        Record memory _record = records[_node];
        update(_node, _owner, _record.expiration, _record.ttl);
    }

    function setExpiration(bytes32 _node, uint256 _expiration) public {
        Record memory _record = records[_node];
        update(_node, _record.owner, _expiration, _record.ttl);
    }

    function setTTL(bytes32 _node, uint64 _ttl) public {
        Record memory _record = records[_node];
        update(_node, _record.owner, _record.expiration, _ttl);
    }

    function setData(bytes32 _node, bytes memory _data) public {
        if (records[_node].resolver == address(0)) {
            revert NotRegistered();
        }

        Record storage _record = records[_node];

        // Update record values
        _record.data = _data;
        _record.nonce = merkleForest.latestNonce(_record.tldNode);

        // Calculate recordHash with sha256 for most compatiblility across chains
        bytes32 _recordHash = sha256(abi.encode(_record));

        // Append to merkle tree
        (bytes32 _merkleRoot,) = _updateMerkle(_node, _recordHash, _record.tldNode, _record.parentNode, _record.nonce);

        // Emit RecordChanged event
        emit RecordChanged(_record.tldNode, _node, _record.owner, _merkleRoot, _record);
    }

    // ============= Registrar operator approval functions =============

    /**
     * @dev [Registrar Only] Enable or disable approval for a third party ("operator") to manage
     *  all of ENS records under a TLD. Emits the ApprovalForAll event.
     * @param _operator Address to add to the set of authorized operators.
     * @param _approved True if the operator is approved, false to revoke approval.
     */
    function setApprovalForAll(address _operator, bool _approved) public virtual {
        operators[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    /**
     * @dev Query if an address is an authorized operator for another address.
     * @param _owner The address that owns the records.
     * @param _operator The address that acts on behalf of the owner.
     * @return True if `operator` is an approved operator for `owner`, false otherwise.
     */
    function isApprovedForAll(address _owner, address _operator) public view virtual returns (bool) {
        return operators[_owner][_operator];
    }
}
