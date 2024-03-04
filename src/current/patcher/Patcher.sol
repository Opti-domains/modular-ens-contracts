// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/utils/StorageSlot.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "src/Semver.sol";
import "../utils/SignatureValidator.sol";
import "./IPatcher.sol";
import "./DummyContract.sol";

bytes32 constant TOPIC_APPLY_PATCH = keccak256("optidomains.Patcher.applyPatch");
bytes32 constant TOPIC_APPLY_PATCH_FF = keccak256("optidomains.Patcher.applyPatchFF");

/**
 * @title Patcher
 * @author Chomtana
 * @notice Contract responsible for managing patch lifecycle
 *
 * Patcher allow protocol owner to control patch across chains without having to manually execute tx on each chain.
 * Operator need to sign patch with nonce and the signature can be reused across chains.
 *
 * Patcher contract perform these operations
 * 1. Execute tx on behalf of the Patcher contract
 * 2. Deploy proxies with deterministic address
 * 3. Set proxies implementation
 */
contract Patcher is IPatcher, OwnableUpgradeable, Semver {
    // PatcherProxyStarter initialize
    DummyContract internal dummyContract;
    ProxyAdmin public proxyAdmin;

    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    // Pather variables
    uint256 public latestNonce;

    uint256[500] private __gap;

    error InvalidNonce();
    error InvalidContract();
    error InvalidSignature();
    error InvalidCaller();

    event PatchApplied(bytes32 indexed patchHash, uint256 indexed startNonce, uint256 indexed endNonce);
    event ProxyDeployed(bytes32 indexed patchHash, address indexed deployedAddress, bytes32 indexed salt);
    event ImplementationSet(bytes32 indexed patchHash, address indexed target, address indexed implementation);
    event ActionExecuted(bytes32 indexed patchHash, address indexed target, bytes data);

    constructor() Semver(1, 0, 0) {}

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }

    function _applyPatch(PatchBody memory patch, bytes32 patchHash) internal {
        unchecked {
            // Loop over all deploys
            for (uint256 i = 0; i < patch.deploys.length; i++) {
                bytes32 salt = patch.deploys[i];
                address deployedAddress = address(
                    new TransparentUpgradeableProxy{salt: salt}(address(dummyContract), address(proxyAdmin), "")
                );
                emit ProxyDeployed(patchHash, deployedAddress, salt);
            }

            // Loop over all implementations
            for (uint256 i = 0; i < patch.implementations.length; i++) {
                PatchImplementation memory impl = patch.implementations[i];

                if (impl.target == address(this)) {
                    _setImplementation(impl.impl);
                } else {
                    // Check if target exists and is a contract
                    require(Address.isContract(impl.target), "Target is not a contract");

                    // Set implementation of target to impl.impl through proxyAdmin
                    proxyAdmin.upgrade(ITransparentUpgradeableProxy(payable(impl.target)), impl.impl);
                    emit ImplementationSet(patchHash, impl.target, impl.impl);
                }
            }

            // Loop over all actions
            for (uint256 i = 0; i < patch.actions.length; i++) {
                PatchAction memory action = patch.actions[i];

                // Low level call to target with data as calldata
                (bool success, bytes memory returnData) = action.target.call(action.data);
                require(success, string(abi.encodePacked("Call failed: ", returnData)));
                emit ActionExecuted(patchHash, action.target, action.data);
            }
        }
    }

    function applyPatch(Patch memory patch, bytes memory signature) public {
        // Check nonce
        if (patch.nonce != latestNonce) {
            revert InvalidNonce();
        }

        bytes32 patchHash = keccak256(abi.encode(patch));

        // Check signature
        if (msg.sender != owner()) {
            if (!SignatureValidator.validateBasicSignature(owner(), TOPIC_APPLY_PATCH, patchHash, signature)) {
                revert InvalidSignature();
            }
        }

        // Apply patch
        _applyPatch(patch.patch, patchHash);

        // Increase nonce
        latestNonce++;

        // Emit PatchApplied event
        emit PatchApplied(patchHash, patch.nonce, latestNonce);
    }

    function applyPatchFF(PatchFF memory patch, bytes memory signature) public {
        // Check nonce
        if (patch.startNonce != latestNonce) {
            revert InvalidNonce();
        }

        bytes32 patchHash = keccak256(abi.encode(patch));

        // Check signature
        if (msg.sender != owner()) {
            if (!SignatureValidator.validateBasicSignature(owner(), TOPIC_APPLY_PATCH_FF, patchHash, signature)) {
                revert InvalidSignature();
            }
        }

        // Apply patch
        _applyPatch(patch.patch, patchHash);

        // Increase nonce
        latestNonce = patch.endNonce;

        // Emit PatchApplied event
        emit PatchApplied(patchHash, patch.startNonce, patch.endNonce);
    }

    function applyTransferOwnership(address newOwner) public {
        if (msg.sender != address(this)) {
            revert InvalidCaller();
        }

        _transferOwnership(newOwner);
    }

    function calculateProxyAddress(bytes32 salt) public view returns (address) {
        // Generate the bytecode for TransparentUpgradeableProxy
        bytes memory bytecode = abi.encodePacked(
            type(TransparentUpgradeableProxy).creationCode, abi.encode(address(dummyContract), address(proxyAdmin), "")
        );

        // Compute the hash for the CREATE2 deployment
        bytes32 bytecodeHash = keccak256(bytecode);
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, bytecodeHash));

        // The address is the last 20 bytes of the hash
        return address(uint160(uint256(hash)));
    }
}
