// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../registry/ModularENS.sol";
import "./IRegistrarHook.sol";

bytes32 constant OP_NAMEHASH = bytes32(0);

contract OpDomains is ERC721("Opti.Domains", ".op"), IRegistrarHook {
    ModularENS public immutable registry;
    bool internal _onUpdateRecord = false;

    constructor(ModularENS _registry) {
        registry = _registry;
    }

    function updateRecord(bytes32 nameHash, ModularENS.Record calldata record) external {
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

    function register(
        string calldata label,
        address owner,
        uint256 expiration,
        bool reverseRecord,
        bytes32[] calldata resolverCalldata,
        bytes calldata signature
    ) external payable {
        registry.register(OP_NAMEHASH, owner, expiration, 0, label, "");
    }

    function extendExpiry(bytes32 node, uint256 expiration, bytes calldata signature) external payable {
        registry.setExpiration(node, expiration);
    }

    
}
