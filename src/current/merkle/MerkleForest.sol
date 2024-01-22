/**
 * Contract to manage permissions to update the leaves of the imported MerkleTree contract (which is the base contract which handles tree inserts and updates).
 *
 * @Author iAmMichaelConnor
 */
pragma solidity ^0.8.8;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./MerkleForestSHA.sol";

error InvalidRootTimestamp();

contract MerkleForest is MerkleForestSHA, OwnableUpgradeable {
    mapping(bytes32 => bytes32[]) public roots;
    mapping(bytes32 => uint256[]) public timestamps;

    event NewRoot(bytes32 indexed treeId, bytes32 root, uint256 timestamp, uint256 index);

    function initialize() public initializer {
        __Ownable_init();
    }

    /**
     * @notice Append a leaf to the tree
     * @param leafValue - the value of the leaf being inserted.
     */
    function insertLeaf(bytes32 treeId, bytes32 leafValue) external onlyOwner returns (bytes32 root) {
        root = _insertLeaf(leafValue, treeId); // recalculate the root of the tree
        roots[treeId].push(root);
        timestamps[treeId].push(block.timestamp);
        emit NewRoot(treeId, root, block.timestamp, roots[treeId].length - 1);
    }

    /**
     * @notice Append leaves to the tree
     * @param leafValues - the values of the leaves being inserted.
     */
    function insertLeaves(bytes32 treeId, bytes32[] calldata leafValues) external onlyOwner returns (bytes32 root) {
        root = _insertLeaves(leafValues, treeId); // recalculate the root of the tree
        roots[treeId].push(root);
        timestamps[treeId].push(block.timestamp);
        emit NewRoot(treeId, root, block.timestamp, roots[treeId].length - 1);
    }

    function restoreRoot(bytes32 treeId, bytes32 root, uint256 timestamp) external onlyOwner {
        if (timestamps[treeId].length == 0 || timestamp >= timestamps[treeId][timestamps[treeId].length - 1]) {
            roots[treeId].push(root);
            timestamps[treeId].push(timestamp);
            emit NewRoot(treeId, root, timestamp, roots[treeId].length - 1);
        } else {
            revert InvalidRootTimestamp();
        }
    }
}
