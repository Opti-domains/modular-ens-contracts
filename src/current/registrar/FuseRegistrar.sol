// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "./BaseRegistrar.sol";

/**
 * @title FuseRegistrar
 * @notice Domain registrar implementation with fuse support
 *
 * Opti.domains supported fuses
 * - 0: PARENT_CANNOT_CONTROL
 * - 1: CANNOT_BURN_FUSES
 * - 2: CANNOT_TRANSFER
 * - 3: CANNOT_SET_RESOLVER
 * - 4: CANNOT_CREATE_SUBDOMAIN
 * - We may add up to 64 fuses in the future
 * - From bit 64 onwards are safe for custom fuses implementation
 *
 * With a difference from ENS that parent can restore fuses and always have full permission
 * regardless of fuses burning status unless PARENT_CANNOT_CONTROL is burned
 */
contract FuseRegistrar is BaseRegistrar {
    error FuseBurned(uint8 fuseIndex);
    error CannotSetFuse(uint256 currentFuses, uint256 newFuses);

    uint256[50] private __gap;

    constructor(string memory name, string memory symbol, ModularENS _registry)
        BaseRegistrar(name, symbol, _registry)
    {}

    function _isParentAuthorised(bytes32 node) internal view virtual override returns (bool) {
        uint256 fuses = abi.decode(registry.data(node), (uint256));
        if (fuses & 1 > 0) {
            revert FuseBurned(0);
        }
        return super._isParentAuthorised(node);
    }

    modifier fuseNotBurned(bytes32 node, uint8 fuseIndex) {
        if (!_isParentNode) {
            uint256 fuses = abi.decode(registry.data(node), (uint256));
            if (fuses & (1 << fuseIndex) != 0) revert FuseBurned(fuseIndex);
        }
        _;
    }

    function _beforeTokenTransfer(address, address, uint256 node, uint256) internal virtual override {
        if (_isParentNode) return;
        uint256 fuses = abi.decode(registry.data(bytes32(node)), (uint256));
        if (fuses & (1 << 2) != 0) revert FuseBurned(2);
    }

    function _register(
        string calldata label,
        bytes32 parentNode,
        address owner,
        uint256 expiration,
        uint256 fuses,
        bool reverseRecord,
        bytes[] calldata resolverCalldata
    ) internal virtual {
        _register(label, parentNode, owner, expiration, reverseRecord, resolverCalldata, abi.encode(fuses));
    }

    function registerSubdomain(
        string calldata label,
        bytes32 parentNode,
        address owner,
        uint256 expiration,
        uint256 fuses,
        bool reverseRecord,
        bytes[] calldata resolverCalldata
    ) public virtual authorised(parentNode) fuseNotBurned(parentNode, 4) {
        _register(label, parentNode, owner, expiration, fuses, reverseRecord, resolverCalldata);
    }

    function setFuses(bytes32 node, uint256 fuses) public virtual authorised(node) fuseNotBurned(node, 1) {
        if (!_isParentNode) {
            uint256 currentFuses = abi.decode(registry.data(node), (uint256));
            if (currentFuses & (~fuses) != 0 || fuses & 1 != 0) {
                revert CannotSetFuse(currentFuses, fuses);
            }
        }

        registry.setData(node, abi.encode(fuses));
    }

    function transferSubdomain(bytes32 node, address target) public virtual parentAuthorised(node) {
        _transfer(_ownerOf(uint256(node)), target, uint256(node));
    }

    function resolverDiamondCut(
        bytes32 node,
        IDiamondWritableInternal.FacetCut[] calldata facetCuts,
        address target,
        bytes calldata data
    ) public virtual override authorised(node) fuseNotBurned(node, 3) {
        super.resolverDiamondCut(node, facetCuts, target, data);
    }
}
