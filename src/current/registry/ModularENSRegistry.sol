// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {IDiamondWritable} from "@solidstate/contracts/proxy/diamond/writable/IDiamondWritable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@ensdomains/ens-contracts/utils/NameEncoder.sol";
import "./ModularENS.sol";
import "../merkle/MerkleForest.sol";
import "../diamond/interfaces/IDiamondCloneFactory.sol";
import "../registrar/interfaces/IRegistrarHook.sol";
import "forge-std/console.sol";

contract ModularENSRegistry is ModularENS {
    address public immutable root;
    MerkleForest public immutable merkleForest;

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

    error NonceOutdated();
    error InvalidRecord();

    event RecordChanged(
        bytes32 indexed tldNode,
        bytes32 indexed parentNode,
        address indexed owner,
        bytes32 nameHash,
        bytes32 merkleRoot,
        Record record
    );
    event NewTLD(bytes32 indexed tldNode, bytes32 indexed namehash, address indexed registrar, TLD tld);

    modifier onlyRoot() {
        if (msg.sender != root) {
            revert NotRoot();
        }
        _;
    }

    modifier onlyRegistrar(bytes32 node) {
        bytes32 tldHash = records[node].tldNode;
        address registrar = _tld[tldHash].registrar;
        if (registrar != msg.sender || operators[registrar][msg.sender]) {
            revert NotRegistrar();
        }
        if (_tld[tldHash].chainId != block.chainid) {
            revert NotPrimaryChain();
        }
        _;
    }

    // ============= Immutable constructor =============

    constructor(address _root, MerkleForest _merkleForest) {
        root = _root;
        merkleForest = _merkleForest;
    }

    // ============= Getter functions =============

    function _validNode(bytes32 node) internal view returns (bool) {
        uint256 _expiration = expiration(node);
        return
            (block.timestamp <= _expiration || _expiration == 0) && merkleForest.isValidMerkleRoot(nodeMerkleRoot[node]);
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

    function tld(bytes32 tldNodeHash) public view returns (TLD memory) {
        return _tld[tldNodeHash];
    }

    function primaryChainId(bytes32 node) public view returns (uint256) {
        return _tld[records[node].tldNode].chainId;
    }

    function data(bytes32 node) public view returns (bytes memory) {
        return records[node].data;
    }

    function name(bytes32 node) public view returns (string memory) {
        if (node == bytes32(0)) return "";
        return string.concat(records[node].label, ".", name(records[node].parentNode));
    }

    function dnsEncoded(bytes32 node) public view returns (bytes memory dnsName) {
        (dnsName,) = NameEncoder.dnsEncodeName(name(node));
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
     * @dev [DEPRECATED] Returns the TTL of a node, and any records associated with it.
     * @return ttl of the node (Always 0).
     */
    function ttl(bytes32) public view virtual override returns (uint64) {
        return 0;
    }

    /**
     * @dev Returns whether a record has been imported to the registry.
     * @param node The specified node.
     * @return Bool if record exists
     */
    function recordExists(bytes32 node) public view virtual override returns (bool) {
        return records[node].tldNode != bytes32(0);
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

    function _sendHook(Record memory _record) internal {
        // Send hook
        address _registrar = _tld[_record.tldNode].registrar;
        if (_registrar.code.length > 0) {
            IRegistrarHook(_registrar).updateRecord(_record);
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
            nameHash: _nameHash,
            expiration: 0,
            registrationTime: 0,
            updatedTimestamp: 0,
            parentNode: bytes32(0),
            tldNode: _tldNode,
            nonce: 0,
            label: _tldObj.name,
            data: ""
        });

        records[_nameHash] = _record;

        // Emit NewTLD event
        emit NewTLD(_tldNode, _nameHash, _tldObj.registrar, _tldObj);
    }

    function update(bytes32 _nameHash, address _owner, uint256 _expiration)
        public
        onlyRegistrar(_nameHash)
        returns (bytes32 _merkleRoot, uint256 _nonce)
    {
        if (records[_nameHash].tldNode == bytes32(0)) {
            revert NotRegistered();
        }

        Record storage _record = records[_nameHash];

        // Emit transition events
        if (_record.owner != _owner) {
            emit Transfer(_nameHash, _owner);
        }

        // Update record values
        _record.owner = _owner;
        _record.expiration = _expiration;
        _record.nonce = merkleForest.latestNonce(_record.tldNode) + 1;
        _record.updatedTimestamp = block.timestamp;

        // Calculate recordHash with sha256 for most compatiblility across chains
        bytes32 _recordHash = sha256(abi.encode(_record));

        // Append to merkle tree
        (_merkleRoot, _nonce) =
            _updateMerkle(_nameHash, _recordHash, _record.tldNode, _record.parentNode, _record.nonce);

        // Send hook
        _sendHook(_record);

        // Emit RecordChanged event
        emit RecordChanged(_record.tldNode, _record.parentNode, _owner, _nameHash, _merkleRoot, _record);
    }

    function register(
        bytes32 _parentNode,
        address _owner,
        uint256 _expiration,
        string memory _label,
        bytes memory _data
    ) public onlyRegistrar(_parentNode) returns (bytes32 _nameHash, bytes32 _merkleRoot, uint256 _nonce) {
        bytes32 _labelHash = keccak256(abi.encodePacked(_label));
        _nameHash = keccak256(abi.encodePacked(_parentNode, _labelHash));

        if (records[_nameHash].tldNode != bytes32(0)) {
            revert AlreadyRegistered();
        } else {
            bytes32 _tldNode = tldNode(_parentNode);

            address _resolver = IDiamondCloneFactory(_tld[_tldNode].resolver).clone(_nameHash);

            Record memory _record = Record({
                owner: _owner,
                resolver: _resolver,
                nameHash: _nameHash,
                expiration: _expiration,
                registrationTime: block.timestamp,
                updatedTimestamp: block.timestamp,
                parentNode: _parentNode,
                tldNode: _tldNode,
                nonce: merkleForest.latestNonce(_tldNode) + 1,
                label: _label,
                data: _data
            });

            records[_nameHash] = _record;

            // Calculate recordHash with sha256 for most compatiblility across chains
            bytes32 _recordHash = sha256(abi.encode(_record));

            // Append to merkle tree
            (_merkleRoot, _nonce) = _updateMerkle(_nameHash, _recordHash, _tldNode, _parentNode, _record.nonce);

            // Send hook
            _sendHook(_record);

            // Emit events
            emit RecordChanged(_tldNode, _parentNode, _owner, _nameHash, _merkleRoot, _record);
            emit NewOwner(_parentNode, _labelHash, _owner);
            emit Transfer(_nameHash, _owner);
            emit NewResolver(_nameHash, _resolver);
        }
    }

    function relay(Record calldata _record, bytes32[] calldata _proof) external {
        bytes32 _nameHash = _record.nameHash;

        if (_record.nonce <= records[_nameHash].nonce) {
            revert NonceOutdated();
        }

        bytes32 _recordHash = sha256(abi.encode(_record));
        (bool validated, bytes32 _merkleRoot) = merkleForest.proof(_record.tldNode, _record.nonce, _recordHash, _proof);

        if (!validated) {
            revert InvalidRecord();
        }

        records[_nameHash] = _record;

        // Send hook
        _sendHook(_record);

        // Emit events
        emit RecordChanged(_record.tldNode, _record.parentNode, _record.owner, _nameHash, _merkleRoot, _record);
        emit NewOwner(_record.parentNode, keccak256(abi.encodePacked(_record.label)), _record.owner);
        emit Transfer(_nameHash, _record.owner);
        emit NewResolver(_nameHash, _record.resolver);
    }

    // ============= Resolver functions =============

    function resolverDiamondCut(
        bytes32 _node,
        IDiamondWritableInternal.FacetCut[] calldata _facetCuts,
        address _target,
        bytes calldata _data
    ) public onlyRegistrar(_node) {
        address _resolver = IDiamondCloneFactory(_tld[records[_node].tldNode].resolver).getCloneAddress(_node);
        IDiamondWritable(_resolver).diamondCut(_facetCuts, _target, _data);
    }

    function resolverCall(bytes32 _node, bytes calldata _calldata)
        public
        payable
        onlyRegistrar(_node)
        returns (bytes memory)
    {
        address _resolver = IDiamondCloneFactory(_tld[records[_node].tldNode].resolver).getCloneAddress(_node);
        (bool success, bytes memory result) = _resolver.call{value: msg.value}(_calldata);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
        return result;
    }

    // ============= Single update functions =============

    function setOwner(bytes32 _node, address _owner) public {
        Record memory _record = records[_node];
        update(_node, _owner, _record.expiration);
    }

    function setExpiration(bytes32 _node, uint256 _expiration) public {
        Record memory _record = records[_node];
        update(_node, _record.owner, _expiration);
    }

    function setData(bytes32 _node, bytes memory _data) public {
        if (records[_node].resolver == address(0)) {
            revert NotRegistered();
        }

        Record storage _record = records[_node];

        // Update record values
        _record.data = _data;
        _record.nonce = merkleForest.latestNonce(_record.tldNode) + 1;

        // Calculate recordHash with sha256 for most compatiblility across chains
        bytes32 _recordHash = sha256(abi.encode(_record));

        // Append to merkle tree
        (bytes32 _merkleRoot,) = _updateMerkle(_node, _recordHash, _record.tldNode, _record.parentNode, _record.nonce);

        // Emit RecordChanged event
        emit RecordChanged(_record.tldNode, _record.parentNode, _record.owner, _node, _merkleRoot, _record);
    }

    // ============= Registrar operator approval functions =============

    /**
     * @dev Enable or disable approval for a third party ("operator") to manage
     *  all of ENS records under a registrar or up to the registrar logic.
     *  Emits the ApprovalForAll event.
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
