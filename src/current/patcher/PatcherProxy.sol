// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "../utils/SignatureValidator.sol";
import "./DummyContract.sol";

bytes32 constant TOPIC_PATCHER_INIT = keccak256("optidomains.patcher.applyPatch");

interface PatcherInitialize {
    function initialize(address _owner) external;
}

contract PatcherProxyStarter is OwnableUpgradeable {
    // PatcherProxyStarter initialize
    DummyContract internal dummyContract;
    ProxyAdmin public proxyAdmin;

    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    error InvalidSignature();

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }

    function initialize(address _owner) public virtual initializer {
        dummyContract = new DummyContract();
        proxyAdmin = new ProxyAdmin();
        _transferOwnership(_owner);
    }

    function setup(address impl, bytes memory signature) public {
        if (msg.sender != owner()) {
            if (
                !SignatureValidator.validateBasicSignature(
                    owner(), TOPIC_PATCHER_INIT, keccak256(abi.encode(impl)), signature
                )
            ) {
                revert InvalidSignature();
            }
        }

        _setImplementation(impl);
    }
}

contract PatcherProxy is TransparentUpgradeableProxy {
    constructor(address _owner)
        TransparentUpgradeableProxy(
            address(new PatcherProxyStarter()),
            address(this),
            abi.encodeWithSelector(PatcherInitialize.initialize.selector, _owner)
        )
    {}
}
