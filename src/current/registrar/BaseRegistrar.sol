// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../registry/ModularENS.sol";
import "../diamond/interfaces/IMulticallable.sol";
import "./interfaces/IRegistrarHook.sol";

bytes32 constant OP_NAMEHASH = bytes32(0);

contract BaseRegistrar is ERC721, IRegistrarHook {
    ModularENS public immutable registry;
    bool internal _onUpdateRecord = false;

    error Unauthorised();

    modifier authorised(bytes32 node) {
        address owner = registry.owner(node);
        if (msg.sender == owner || registry.isApprovedForAll(owner, msg.sender)) {
            _;
        } else {
            revert Unauthorised();
        }
    }

    constructor(string memory name, string memory symbol, ModularENS _registry) ERC721(name, symbol) {
        registry = _registry;
    }

    function updateRecord(bytes32 nameHash, ModularENS.Record calldata record) external {
        if (msg.sender != address(registry)) {
            revert Unauthorised();
        }

        _onUpdateRecord = true;

        uint256 tokenId = uint256(nameHash);

        if (_exists(tokenId)) {
            address tokenOwner = _ownerOf(tokenId);
            if (tokenOwner != record.owner) {
                _transfer(tokenOwner, record.owner, tokenId);
            }
        } else {
            _mint(record.owner, tokenId);
        }

        _onUpdateRecord = false;
    }

    function _afterTokenTransfer(address, address to, uint256 tokenId, uint256) internal virtual override {
        if (!_onUpdateRecord) {
            registry.setOwner(bytes32(tokenId), to);
        }
    }

    function _register(
        string calldata label,
        bytes32 parentNode,
        address owner,
        uint256 expiration,
        bool reverseRecord,
        bytes32[] calldata resolverCalldata,
        bytes calldata data
    ) internal {
        (bytes32 node,,) = registry.register(parentNode, owner, expiration, label, data);
        registry.resolverCall(
            node, abi.encodeWithSelector(IMulticallable.multicallWithNodeCheck.selector, node, resolverCalldata)
        );
        if (reverseRecord) {
            
        }
    }

    function _setExpiration(bytes32 node, uint256 expiration) internal {
        registry.setExpiration(node, expiration);
    }

    function resolverDiamondCut(
        bytes32 node,
        IDiamondWritableInternal.FacetCut[] calldata facetCuts,
        address target,
        bytes calldata data
    ) public virtual authorised(node) {
        registry.resolverDiamondCut(node, facetCuts, target, data);
    }

    function resolverCall(bytes32 node, bytes calldata resolverCalldata)
        public
        payable
        authorised(node)
        returns (bytes memory)
    {
        return registry.resolverCall(node, resolverCalldata);
    }
}
