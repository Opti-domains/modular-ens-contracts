// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import "../../../registry/ENS.sol";
import {INameWrapper} from "../../../wrapper/INameWrapper.sol";

/**
 * @dev derived from PublicResolver (MIT license)
 */
library DiamondResolverBaseStorage {
    struct Layout {
        /**
         * A mapping of operators. An address that is authorised for an address
         * may make any changes to the name that the owner could, but may not update
         * the set of authorisations.
         * (owner, operator) => approved
         */
        mapping(address => mapping(address => bool)) operatorApprovals;

        /**
         * A mapping of delegates. A delegate that is authorised by an owner
         * for a name may make changes to the name's resolver, but may not update
         * the set of token approvals.
         * (owner, name, delegate) => approved
         */
        mapping(address => mapping(bytes32 => mapping(address => bool))) tokenApprovals;

        mapping(bytes32 => uint64) recordVersions;

        mapping(address => bool) supportsInterface;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256('optidomains.contracts.storage.DiamondResolverStorage');

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
