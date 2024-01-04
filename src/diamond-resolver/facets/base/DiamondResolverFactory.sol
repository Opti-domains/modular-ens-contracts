// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./IDiamondResolverFactory.sol";

interface IDiamondResolverInitialize {
    function initialize(address _owner, address _fallback) external;
}

contract DiamondResolverFactory is IDiamondResolverFactory {
    event CloneDiamondResolver(address indexed cloner, address indexed resolver);

    /**
     * @dev Modifier to ensure that the first 20 bytes of a submitted salt match
     * those of the calling account. This provides protection against the salt
     * being stolen by frontrunners or other attackers.
     * @param salt bytes32 The salt value to check against the calling address.
     */
    modifier containsCaller(bytes32 salt) {
        // prevent contract submissions from being stolen from tx.pool by requiring
        // that the first 20 bytes of the submitted salt match msg.sender.
        require(
            (address(bytes20(salt)) == msg.sender),
            "Invalid salt - first 20 bytes of the salt must match calling address."
        );
        _;
    }

    /**
     * Clone DiamondResolver to customize your own resolver
     */
    function clone(bytes32 salt) public containsCaller(salt) {
        address newResolver = Clones.cloneDeterministic(address(this), salt);
        IDiamondResolverInitialize(newResolver).initialize(msg.sender, address(this));
        emit CloneDiamondResolver(msg.sender, newResolver);
    }
}