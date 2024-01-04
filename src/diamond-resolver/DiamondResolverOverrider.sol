//SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9.0;

import "./facets/base/DiamondResolverUtil.sol";

error Overrider_SignatureBlacklisted(bytes4 sig);
error Overrider_ImplementationNotWhitelisted(address implementation);

library DiamondResolverOverriderStorage {
    struct Layout {
        // Facets overriding mapping
        mapping(bytes32 => mapping(bytes4 => address)) facets;

        // Blacklisted function signature
        mapping(bytes4 => bool) blacklisted;

        // Whitelisted implementation address
        mapping(address => bool) whitelisted;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256(
            "optidomains.contracts.storage.DiamondResolverOverriderStorage"
        );

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}

contract DiamondResolverOverrider is DiamondResolverUtil {
    function _getImplementation()
        internal
        view
        virtual
        returns (address)
    {
        if (msg.data.length < 36) {
            return address(0);
        }

        // inline storage layout retrieval uses less gas
        DiamondResolverOverriderStorage.Layout storage l;
        bytes32 slot = DiamondResolverOverriderStorage.STORAGE_SLOT;
        assembly {
            l.slot := slot
        }

        if (l.blacklisted[msg.sig]) {
            return address(0);
        }

        return l.facets[bytes32(msg.data[4:36])][msg.sig];
    }

    function setOverrideBlacklist(bytes4[] memory sig, bool blacklisted) public baseOnlyOwner {
        // inline storage layout retrieval uses less gas
        DiamondResolverOverriderStorage.Layout storage l;
        bytes32 slot = DiamondResolverOverriderStorage.STORAGE_SLOT;
        assembly {
            l.slot := slot
        }

        unchecked {
            uint256 sigLength = sig.length;
            for (uint256 i; i < sigLength; ++i) {
                l.blacklisted[sig[i]] = blacklisted;
            }
        }
    }

    function setWhitelistedImplementation(address[] memory implementations, bool whitelisted) public baseOnlyOwner {
        // inline storage layout retrieval uses less gas
        DiamondResolverOverriderStorage.Layout storage l;
        bytes32 slot = DiamondResolverOverriderStorage.STORAGE_SLOT;
        assembly {
            l.slot := slot
        }

        unchecked {
            uint256 implLength = implementations.length;
            for (uint256 i; i < implLength; ++i) {
                l.whitelisted[implementations[i]] = whitelisted;
            }
        }
    }

    function setOverride(bytes32 node, bytes4 sig, address implementation) public authorised(node) {
        // inline storage layout retrieval uses less gas
        DiamondResolverOverriderStorage.Layout storage l;
        bytes32 slot = DiamondResolverOverriderStorage.STORAGE_SLOT;
        assembly {
            l.slot := slot
        }

        if (l.blacklisted[sig]) {
            revert Overrider_SignatureBlacklisted(sig);
        }

        if (!l.whitelisted[implementation]) {
            revert Overrider_ImplementationNotWhitelisted(implementation);
        }

        l.facets[node][sig] = implementation;
    }
}
