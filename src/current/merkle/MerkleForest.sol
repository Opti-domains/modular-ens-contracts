/**
 * Contract to manage permissions to update the leaves of the imported MerkleTree contract (which is the base contract which handles tree inserts and updates).
 *
 * @Author iAmMichaelConnor
 */
pragma solidity ^0.8.8;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./MerkleForestSHA.sol";
import "./MerkleProof.sol";

contract MerkleForest is MerkleForestSHA, OwnableUpgradeable {
    struct MerkleRoot {
        bytes32 root;
        uint256 timestamp;
        uint256 nonce;
    }

    mapping(bytes32 => mapping(uint256 => MerkleRoot)) roots;
    mapping(bytes32 => uint256) public latestNonce;
    mapping(bytes32 => bool) public isRestored;
    mapping(bytes32 => uint256) public rootValidFrom;
    mapping(address => uint256) public operators;
    mapping(address => bool) public challengers;
    address public registry;

    error NonceOutdated();
    error EitherInsertOrRestore();
    error NotOperator();

    event NewRoot(
        address indexed operator, bytes32 indexed treeId, bytes32 indexed root, uint256 nonce, uint256 timestamp
    );
    event OperatorUpdated(address indexed operator, uint256 challengePeriod);
    event ChallengerUpdated(address indexed challenger, bool enabled);
    event RootChallenged(address indexed challenger, bytes32 indexed root);

    function initialize(address _registry) public initializer {
        registry = _registry;
        __Ownable_init();
    }

    modifier onlyRegistry() {
        if (msg.sender != registry) {
            revert NotOperator();
        }
        _;
    }

    /**
     * @notice Append a leaf to the tree
     * @param leafValue - the value of the leaf being inserted.
     */
    function insertLeaf(bytes32 treeId, bytes32 leafValue)
        external
        onlyRegistry
        returns (bytes32 root, uint256 nonce)
    {
        if (isRestored[treeId]) revert EitherInsertOrRestore();

        root = _insertLeaf(leafValue, treeId); // recalculate the root of the tree
        nonce = latestNonce[treeId]++;

        roots[treeId][nonce] = MerkleRoot({root: root, timestamp: block.timestamp, nonce: nonce});
        latestNonce[treeId] = nonce;
        rootValidFrom[root] = block.timestamp;

        emit NewRoot(msg.sender, treeId, root, nonce, block.timestamp);
    }

    function setOperator(address operator, uint256 challengePeriod) external onlyOwner {
        operators[operator] = challengePeriod;
        emit OperatorUpdated(operator, challengePeriod);
    }

    function setChallenger(address challenger, bool enabled) external onlyOwner {
        challengers[challenger] = enabled;
        emit ChallengerUpdated(challenger, enabled);
    }

    function restoreRoot(bytes32 treeId, bytes32 root, uint256 timestamp, uint256 nonce) external {
        if (operators[msg.sender] == 0) {
            revert NotOperator();
        }

        if (!isRestored[treeId] && latestNonce[treeId] > 0) revert EitherInsertOrRestore();

        if (!isRestored[treeId] || nonce > latestNonce[treeId]) {
            roots[treeId][nonce] = MerkleRoot({root: root, timestamp: timestamp, nonce: nonce});
            latestNonce[treeId] = nonce;
            isRestored[treeId] = true;
            rootValidFrom[root] = block.timestamp + operators[msg.sender] - 1;

            emit NewRoot(msg.sender, treeId, root, nonce, timestamp);
        } else {
            uint256 newValidity = block.timestamp + operators[msg.sender] - 1;
            if (nonce == latestNonce[treeId] && newValidity < rootValidFrom[root]) {
                rootValidFrom[root] = newValidity;
            } else {
                revert NonceOutdated();
            }
        }
    }

    function challengeRoot(bytes32 root) external {
        if (!challengers[msg.sender]) {
            revert NotOperator();
        }

        rootValidFrom[root] = 0;

        emit RootChallenged(msg.sender, root);
    }

    function isFraud(bytes32 root) public view returns (bool) {
        return rootValidFrom[root] == 0 || block.timestamp < rootValidFrom[root];
    }

    function latestRoot(bytes32 treeId) public view returns (MerkleRoot memory) {
        return roots[treeId][latestNonce[treeId]];
    }

    function proof(bytes32 treeId, bytes32 leaf, bytes32[] calldata path) public view returns (bool) {
        return MerkleProof.verifyCalldata(path, latestRoot(treeId).root, leaf);
    }
}
