// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./RegistryAuthFacet.sol";

library RegistryWhitelistAuthStorage {
    struct Layout {
        /**
         * trustedETHController and trustedReverseRegistrar has right to control any name regardless of approval
         * controller address => whitelisted
         */
        mapping(address => bool) whitelisted;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256('optidomains.contracts.storage.RegistryWhitelistAuthStorage');

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}

contract RegistryWhitelistAuthFacet is RegistryAuthFacet {
    event SetWhitelisted(address indexed operator, bool approved);

    function isAuthorised(address sender, bytes32 node) public virtual override view returns (bool) {
        return super.isAuthorised(sender, node) || RegistryWhitelistAuthStorage.layout().whitelisted[sender];
    }

    function setWhitelisted(address operator, bool approved) public baseOnlyOwner {
        RegistryWhitelistAuthStorage.Layout storage l = RegistryWhitelistAuthStorage
            .layout();
        l.whitelisted[operator] = approved;
        emit SetWhitelisted(operator, approved);
    }
}
