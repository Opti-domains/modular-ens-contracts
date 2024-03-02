// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {EVMFetchTarget} from "@ensdomains/evm-verifier/contracts/EVMFetchTarget.sol";
import {OptiFetchTarget} from "./OptiFetchTarget.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "@ensdomains/ens-contracts/registry/ENS.sol";
import "../resolver/attester/OptiResolverAttesterBase.sol";
import "./OptiL1ResolverMetadata.sol";
import "./OptiL1ResolverUtils.sol";
import "./IOptiL1Gateway.sol";

uint256 constant FreeMemoryOccupied_error_signature =
    (0x3e9fd85b00000000000000000000000000000000000000000000000000000000);
uint256 constant FreeMemoryOccupied_error_length = 0x20;

// keccak256("CCIP_CALLBACK_SELECTOR")
bytes32 constant CCIP_CALLBACK_SELECTOR = (0x008005059b29fe32430d77b550e3fd6faed6e319156c99f488cac9c10006b476);

// keccak256("DNS_ENCODED_NAME_SELECTOR")
bytes32 constant DNS_ENCODED_NAME_SELECTOR = (0x1bc8709fa4e9a9a9d0c17c26a82f1a28d50ebe5469b3220f3e4253c914e56bc1);

bytes32 constant RESOLVER_STORAGE_NAMESPACE = keccak256("optidomains.resolver.storage");

error CCIPSlotOverflow();
error PleaseWriteOnL2();
error InvalidSlot();

contract OptidomainsL1ResolverAttester is OptiFetchTarget, OptiResolverAttesterBase {
    using EVMFetcher for EVMFetcher.EVMFetchRequest;
    using Address for address;

    error OffchainLookup(address sender, string[] urls, bytes callData, bytes4 callbackFunction, bytes extraData);
    error HeaderMustIncludeNode();

    function _storageSlotCommon(bytes32 schema, address recipient, bytes memory header)
        private
        pure
        returns (bytes32 s)
    {
        if (header.length < 32) revert HeaderMustIncludeNode();

        bytes memory packed = abi.encodePacked(header, schema, recipient, RESOLVER_STORAGE_NAMESPACE);
        uint256 packedLength = packed.length;

        assembly {
            // keccak256 hash omiting node
            s := keccak256(add(packed, 0x40), sub(packedLength, 0x20))
        }
    }

    function _isCCIPCallback() private view returns (bool result) {
        // Verify the following format: [funcsig[4], ..., len[32], keccak256(prevrandao, CCIP_CALLBACK_SELECTOR)[32]]
        assembly {
            // If free memory pointer is not at 0x80 then revert
            if iszero(eq(mload(0x40), 0x80)) {
                mstore(0, FreeMemoryOccupied_error_signature)
                revert(0, FreeMemoryOccupied_error_length)
            }

            // Load calldata size
            let calldataLength := calldatasize()

            // Check minimum calldata length requirement
            if gt(calldataLength, 67) {
                // Calculate checksum: keccak256(block.prevrandao, CCIP_CALLBACK_SELECTOR)
                mstore(0x80, prevrandao()) // Load block.prevrandao value
                mstore(0xA0, CCIP_CALLBACK_SELECTOR) // Append CCIP_CALLBACK_SELECTOR after prevrandao
                let checksum := keccak256(0x80, 0x40) // Compute keccak256 hash of combined values

                // Load the calldata checksum (last 32 bytes of calldata)
                let calldataChecksum := calldataload(sub(calldataLength, 0x20))

                // Compare checksums and return result
                result := eq(checksum, calldataChecksum)
            }
        }
    }

    function _initCCIPCallback() private pure {
        assembly {
            // If free memory pointer is not at 0x80 then revert
            if iszero(eq(mload(0x40), 0x80)) {
                mstore(0, FreeMemoryOccupied_error_signature)
                revert(0, FreeMemoryOccupied_error_length)
            }

            // Allocate calldata pointer to the first slot
            mstore(0x80, calldataload(sub(calldatasize(), 0x40)))

            // Move free memory pointer by 2 slot (_isCCIPCallback used 2 slot)
            mstore(0x40, 0xC0)
        }
    }

    function _readCCIPCallback() private pure returns (bytes32 slot, bytes memory data) {
        unchecked {
            uint256 p;
            uint256 dataLength;

            assembly {
                // Load calldata pointer
                p := mload(0x80)

                // First value is the slot
                slot := calldataload(p)

                // Second value is the data length
                dataLength := calldataload(add(p, 0x20))

                // Move pointer to the start of data
                p := add(p, 0x40)
            }

            data = msg.data[p:p + dataLength];

            assembly {
                // Move new pointer to the next calldata
                mstore(0x80, add(p, dataLength))
            }
        }
    }

    function _processCCIPFallback(bytes memory response) private pure {
        uint256 responseLength = response.length;

        if (responseLength == 0) return;

        bytes memory emptyBytes = new bytes(responseLength);

        // Empty primitive data types
        if (keccak256(response) == keccak256(emptyBytes)) return;

        // Empty bytes memory
        if (responseLength >= 64) {
            emptyBytes[31] = 0x20;
            if (keccak256(response) == keccak256(emptyBytes)) return;
        }

        // Return response and skip every step ahead
        assembly {
            // Return response removing length prefix (0x20)
            return(add(response, 0x20), responseLength)
        }
    }

    function _intCCIPFallback() private view {
        unchecked {
            address[] storage officialResolvers = OptiL1ResolverMetadata.layout().officialResolvers;
            uint256 officialResolversLength = officialResolvers.length;

            for (uint256 i = 1; i <= officialResolversLength; ++i) {
                (bool success, bytes memory response) =
                    officialResolvers[officialResolversLength - i].staticcall(msg.data);
                if (success) {
                    _processCCIPFallback(response);
                }
            }
        }
    }

    function _initCCIPFetch() private pure {
        assembly {
            // If free memory pointer is not at 0x80 then revert
            if iszero(eq(mload(0x40), 0x80)) {
                mstore(0, FreeMemoryOccupied_error_signature)
                revert(0, FreeMemoryOccupied_error_length)
            }

            // Move free memory pointer by 33 slots
            mstore(0x40, 0x4A0)
        }
    }

    function _appendCCIPslot(bytes32 slot) private pure {
        unchecked {
            uint256 length;
            assembly {
                // Fetch length from the first memory pointer
                length := add(mload(0x80), 1)
            }

            if (length > 32) {
                revert CCIPSlotOverflow();
            }

            assembly {
                // Increase length of array
                mstore(0x80, length)

                // Push slot to the end of array
                mstore(add(0x80, mul(length, 32)), slot)
            }
        }
    }

    event CCIPSlot(bytes32 slot);

    function _finalizeCCIP() private view {
        OptiL1ResolverMetadata.Layout storage S = OptiL1ResolverMetadata.layout();

        unchecked {
            bytes32[] memory slots;
            assembly {
                slots := 0x80
            }

            bytes32 ensNode = bytes32(msg.data[4:36]);
            bytes memory dnsEncodedName;

            // Try to fetch dns-encoded name
            if (msg.sender == address(this)) {
                assembly {
                    // Load calldata size
                    let calldataLength := calldatasize()

                    // Check minimum calldata length requirement
                    if gt(calldataLength, 67) {
                        // Calculate checksum: keccak256(block.prevrandao, DNS_ENCODED_NAME_SELECTOR)
                        mstore(0x80, prevrandao()) // Load block.prevrandao value
                        mstore(0xA0, DNS_ENCODED_NAME_SELECTOR) // Append DNS_ENCODED_NAME_SELECTOR after prevrandao
                        let checksum := keccak256(0x80, 0x40) // Compute keccak256 hash of combined values

                        // Load the calldata checksum (last 32 bytes of calldata)
                        let calldataChecksum := calldataload(sub(calldataLength, 0x20))

                        // Compare checksums and return result
                        if eq(checksum, calldataChecksum) {
                            // Allocate new memory for DNS encoded name
                            dnsEncodedName := mload(0x40)

                            // Get offset equal to the length of typical calldata
                            let offset := calldataload(sub(calldataLength, 0x40))

                            // [length][...dnsEncodedName...]
                            let dataLength := add(calldataload(offset), 1)

                            // Copy calldata to memory starting at ptr
                            calldatacopy(dnsEncodedName, offset, dataLength)

                            // Move the free memory pointer by the amount we copied over
                            mstore(0x40, add(dnsEncodedName, dataLength))
                        }
                    }
                }
            }

            revert OffchainLookup(
                address(this),
                S.gatewayURLs,
                abi.encodeCall(IOptiL1Gateway.getAttestations, (ensNode, slots, dnsEncodedName)),
                OptiFetchTarget.ccipAttCallback.selector,
                abi.encode(ensNode, slots, msg.data)
            );
        }
    }

    function _read(bytes32 schema, address recipient, bytes memory header)
        internal
        view
        virtual
        override
        returns (bytes memory)
    {
        bool isCallback;
        assembly {
            // If length > 32 then it's a callback pointer position because
            // Minimum pointer position = 4 (funcsig) + 32 (node) = 36
            isCallback := gt(mload(0x80), 32)
        }

        bytes32 s = _storageSlotCommon(schema, recipient, header);

        if (isCallback) {
            (bytes32 slot, bytes memory data) = _readCCIPCallback();
            if (slot != s) {
                revert InvalidSlot();
            }
            return data;
        } else {
            _appendCCIPslot(s);
        }
    }

    function _write(bytes32, address, uint64, bool, bytes memory, bytes memory)
        internal
        virtual
        override
        returns (bytes32)
    {
        revert PleaseWriteOnL2();
    }

    function _revoke(bytes32, address, bytes memory) internal virtual override returns (bytes32) {
        revert PleaseWriteOnL2();
    }

    function _ccipBefore() internal view virtual override {
        bool isCallback = _isCCIPCallback();

        if (isCallback) {
            _initCCIPCallback();
        } else {
            _initCCIPFetch();
            _intCCIPFallback();
        }
    }

    function _ccipAfter() internal view virtual override {
        bool isCallback;
        assembly {
            // If length > 32 then it's a callback pointer position because
            // Minimum pointer position = 4 (funcsig) + 32 (node) = 36
            isCallback := gt(mload(0x80), 32)
        }

        if (!isCallback) {
            _finalizeCCIP();
        }
    }
}
