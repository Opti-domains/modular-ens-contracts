/**
 * Contract to manage permissions to update the leaves of the imported MerkleTree contract (which is the base contract which handles tree inserts and updates).
 *
 * @Author iAmMichaelConnor
 */
pragma solidity ^0.8.8;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./MerkleForestSHA.sol";

contract MerkleForest is MerkleForestSHA, OwnableUpgradeable {
    struct MerkleRoot {
        bytes32 root;
        uint256 timestamp;
        uint256 nonce;
    }

    mapping(bytes32 => mapping(uint256 => MerkleRoot)) roots;
    mapping(bytes32 => uint256) public latestNonce;
    mapping(bytes32 => bool) public isRestored;

    error NonceOutdated();
    error EitherInsertOrRestore();

    event NewRoot(bytes32 indexed treeId, bytes32 indexed root, uint256 indexed nonce, uint256 timestamp);

    function initialize() public initializer {
        __Ownable_init();
    }

    /**
     * @notice Append a leaf to the tree
     * @param leafValue - the value of the leaf being inserted.
     */
    function insertLeaf(bytes32 treeId, bytes32 leafValue) external onlyOwner returns (bytes32 root, uint256 nonce) {
        if (isRestored[treeId]) revert EitherInsertOrRestore();

        root = _insertLeaf(leafValue, treeId); // recalculate the root of the tree
        nonce = latestNonce[treeId]++;

        roots[treeId][nonce] = MerkleRoot({root: root, timestamp: block.timestamp, nonce: nonce});
        latestNonce[treeId] = nonce;

        emit NewRoot(treeId, root, nonce, block.timestamp);
    }

    function restoreRoot(bytes32 treeId, bytes32 root, uint256 timestamp, uint256 nonce) external onlyOwner {
        if (!isRestored[treeId] && latestNonce[treeId] > 0) revert EitherInsertOrRestore();

        if (!isRestored[treeId] || nonce > latestNonce[treeId]) {
            roots[treeId][nonce] = MerkleRoot({root: root, timestamp: timestamp, nonce: nonce});
            latestNonce[treeId] = nonce;
            isRestored[treeId] = true;

            emit NewRoot(treeId, root, nonce, timestamp);
        } else {
            revert NonceOutdated();
        }
    }
}
