// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./interfaces/IDiamondCloneFactory.sol";

interface IDiamondResolverInitialize {
    function initialize(address _owner, address _fallback) external;
}

contract DiamondCloneFactory is IDiamondCloneFactory {
    event CloneDiamond(address indexed cloner, address indexed resolver);

    /**
     * Clone DiamondResolver to customize your own resolver
     */
    function clone(bytes32 salt) public returns (address newResolver) {
        newResolver = Clones.cloneDeterministic(address(this), keccak256(abi.encodePacked(msg.sender, salt)));
        IDiamondResolverInitialize(newResolver).initialize(msg.sender, address(this));
        emit CloneDiamond(msg.sender, newResolver);
    }

    /**
     * Get the predicted address of a clone based on the sender and a salt
     * without deploying it.
     */
    function getCloneAddress(bytes32 salt) public view returns (address predictedAddress) {
        bytes32 saltHash = keccak256(abi.encodePacked(msg.sender, salt));
        predictedAddress = Clones.predictDeterministicAddress(address(this), saltHash, address(this));
    }
}
