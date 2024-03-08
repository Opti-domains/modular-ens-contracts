/**
 * Contract to manage permissions to update the leaves of the imported MerkleTree contract (which is the base contract which handles tree inserts and updates).
 *
 * @Author iAmMichaelConnor
 */
pragma solidity ^0.8.8;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../challenger/RootChallenger.sol";
import "../utils/SignatureValidator.sol";
import "./MerkleForestSHA.sol";
import "./MerkleProof.sol";

bytes32 constant TOPIC_RESTORE_ROOT = keccak256("optidomains.MerkleForest.restoreRoot");

contract MerkleForest is MerkleForestSHA, RootChallenger, OwnableUpgradeable {
    struct MerkleRoot {
        bytes32 root;
        uint256 timestamp;
        uint256 nonce;
    }

    mapping(bytes32 => mapping(uint256 => MerkleRoot)) roots;
    mapping(bytes32 => bytes32) public challengerRoots;
    mapping(bytes32 => uint256) public latestNonce;
    mapping(bytes32 => bool) public isRestored;
    address public registry;

    error NonceOutdated();
    error EitherInsertOrRestore();
    error InvalidRoot(bytes32 root);

    event NewRoot(
        address indexed operator, bytes32 indexed treeId, bytes32 indexed root, uint256 nonce, uint256 timestamp
    );

    function initialize(address _registry) public initializer {
        registry = _registry;
        _setOperator(address(this), true, 0);
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
        nonce = ++latestNonce[treeId];

        bytes32 challengerRoot = keccak256(abi.encodePacked(treeId, root, block.timestamp, nonce));

        roots[treeId][nonce] = MerkleRoot({root: root, timestamp: block.timestamp, nonce: nonce});
        challengerRoots[root] = challengerRoot;
        latestNonce[treeId] = nonce;

        _publishChallengerRoot(address(this), challengerRoot);

        emit NewRoot(address(this), treeId, root, nonce, block.timestamp);
    }

    function _restoreRoot(address operator, bytes32 treeId, bytes32 root, uint256 timestamp, uint256 nonce) internal {
        if (!isRestored[treeId] && latestNonce[treeId] > 0) revert EitherInsertOrRestore();

        if (!isRestored[treeId] || nonce > latestNonce[treeId]) {
            bytes32 challengerRoot = keccak256(abi.encodePacked(treeId, root, timestamp, nonce));

            roots[treeId][nonce] = MerkleRoot({root: root, timestamp: timestamp, nonce: nonce});
            challengerRoots[root] = challengerRoot;
            latestNonce[treeId] = nonce;
            isRestored[treeId] = true;

            _publishChallengerRoot(operator, challengerRoot);

            emit NewRoot(operator, treeId, root, nonce, timestamp);
        } else {
            revert NonceOutdated();
        }
    }

    function restoreRootWithSig(
        address operator,
        bytes32 treeId,
        bytes32 root,
        uint256 timestamp,
        uint256 nonce,
        bytes memory signature
    ) external {
        if (msg.sender != operator) {
            bytes32 rootHash = keccak256(abi.encodePacked(treeId, root, timestamp, nonce));
            if (!SignatureValidator.validateBasicSignature(operator, TOPIC_RESTORE_ROOT, rootHash, signature)) {
                revert InvalidSignature();
            }
        }

        _restoreRoot(operator, treeId, root, timestamp, nonce);
    }

    function setOperator(address operator, bool enabled, uint96 challengePeriod) external onlyOwner {
        _setOperator(operator, enabled, challengePeriod);
    }

    function setChallenger(address challenger, bool enabled) external onlyOwner {
        _setChallenger(challenger, enabled);
    }

    function latestRoot(bytes32 treeId) public view returns (MerkleRoot memory) {
        return roots[treeId][latestNonce[treeId]];
    }

    function isValidMerkleRoot(bytes32 root) public view returns (bool) {
        return isValidRoot(challengerRoots[root]);
    }

    function proof(bytes32 treeId, uint256 nonce, bytes32 leaf, bytes32[] calldata path)
        public
        view
        returns (bool, bytes32)
    {
        MerkleRoot storage merkleRoot = roots[treeId][nonce];

        bytes32 challengerRoot = keccak256(abi.encodePacked(treeId, merkleRoot.root, merkleRoot.timestamp, nonce));
        if (!isValidRoot(challengerRoot)) {
            revert InvalidRoot(challengerRoot);
        }

        return (MerkleProof.verifyCalldata(path, merkleRoot.root, leaf), merkleRoot.root);
    }
}
