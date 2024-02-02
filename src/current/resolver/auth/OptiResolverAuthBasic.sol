// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {SafeOwnableInternal} from "@solidstate/contracts/access/ownable/SafeOwnableInternal.sol";
import "../../registry/ModularENS.sol";
import "./OptiResolverAuth.sol";

library OptiResolverAuthBasicStorage {
    struct Layout {
        ModularENS registry;
        mapping(address => mapping(address => bool)) operators;
        bool initialized;
    }

    bytes32 internal constant STORAGE_SLOT = keccak256("optidomains.contracts.storage.OptiResolverAuthBasic");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}

contract OptiResolverAuthBasic is OptiResolverAuth, SafeOwnableInternal {
    function initialize(ModularENS registry) external {
        OptiResolverAuthBasicStorage.Layout storage S = OptiResolverAuthBasicStorage.layout();
        require(!S.initialized, "Initialized");

        S.registry = registry;
    }

    function _isAuthorised(bytes32 node) internal view virtual override returns (bool) {
        OptiResolverAuthBasicStorage.Layout storage S = OptiResolverAuthBasicStorage.layout();
        address domainOwner = S.registry.owner(node);
        return domainOwner == msg.sender || _owner() == msg.sender || S.operators[domainOwner][msg.sender];
    }

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function setApprovalForAll(address _operator, bool _approved) public virtual {
        OptiResolverAuthBasicStorage.Layout storage S = OptiResolverAuthBasicStorage.layout();
        S.operators[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }
}
