// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {ERC165BaseInternal} from "@solidstate/contracts/introspection/ERC165/base/ERC165Base.sol";
import {SafeOwnableInternal} from "@solidstate/contracts/access/ownable/SafeOwnableInternal.sol";
import "../../diamond/UseRegistry.sol";
import "./IOptiResolverAuthBasic.sol";
import "./OptiResolverAuth.sol";

library OptiResolverAuthBasicStorage {
    struct Layout {
        mapping(address => mapping(address => bool)) operators;
    }

    bytes32 internal constant STORAGE_SLOT = keccak256("optidomains.contracts.storage.OptiResolverAuthBasic");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}

contract OptiResolverAuthBasicInternal is OptiResolverAuth, SafeOwnableInternal {
    function _isAuthorised(bytes32 node) internal view virtual override returns (bool) {
        OptiResolverAuthBasicStorage.Layout storage S = OptiResolverAuthBasicStorage.layout();
        address domainOwner = UseRegistry.registry().owner(node);
        return domainOwner == msg.sender || _owner() == msg.sender || S.operators[domainOwner][msg.sender];
    }
}

contract OptiResolverAuthBasic is IOptiResolverAuthBasic, OptiResolverAuthBasicInternal, ERC165BaseInternal {
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function initialize() public virtual {
        _setSupportsInterface(type(IOptiResolverAuthBasic).interfaceId, true);
    }

    function setApprovalForAll(address _operator, bool _approved) public virtual {
        OptiResolverAuthBasicStorage.Layout storage S = OptiResolverAuthBasicStorage.layout();
        S.operators[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }
}
