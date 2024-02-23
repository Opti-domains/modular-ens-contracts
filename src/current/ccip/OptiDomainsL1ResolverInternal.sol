// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {EVMFetcher} from "@ensdomains/evm-verifier/contracts/EVMFetcher.sol";
import {EVMFetchTarget} from "@ensdomains/evm-verifier/contracts/EVMFetchTarget.sol";
import {IEVMVerifier} from "@ensdomains/evm-verifier/contracts/IEVMVerifier.sol";
import "@ensdomains/ens-contracts/registry/ENS.sol";
import {INameWrapper} from "@ensdomains/ens-contracts/wrapper/INameWrapper.sol";
import {BytesUtils} from "@ensdomains/ens-contracts/dnssec-oracle/BytesUtils.sol";
import {IAddrResolver} from "@ensdomains/ens-contracts/resolvers/profiles/IAddrResolver.sol";
import {IAddressResolver} from "@ensdomains/ens-contracts/resolvers/profiles/IAddressResolver.sol";
import {ITextResolver} from "@ensdomains/ens-contracts/resolvers/profiles/ITextResolver.sol";
import {IContentHashResolver} from "@ensdomains/ens-contracts/resolvers/profiles/IContentHashResolver.sol";
import {OptiDomainsFetchTarget} from "./OptiDomainsFetchTarget.sol";

address constant REGISTRY_ADDRESS = address(0);
address constant BASE_RESOLVER_ADDRESS = address(0);

uint256 constant FreeMemoryOccupied_error_signature =
    (0x3e9fd85b00000000000000000000000000000000000000000000000000000000);
uint256 constant FreeMemoryOccupied_error_length = 0x20;

error CCIPSlotOverflow();

library OptiDomainsL1ResolverUtils {
    using EVMFetcher for EVMFetcher.EVMFetchRequest;

    function _addOperation(EVMFetcher.EVMFetchRequest memory request, uint8 op) private pure {
        uint256 commandIdx = request.commands.length - 1;
        request.commands[commandIdx] =
            request.commands[commandIdx] | (bytes32(bytes1(op)) >> (8 * request.operationIdx++));
    }

    function getOpResolverAddress(bytes32 opNode) public pure returns (address predictedAddress) {
        bytes32 saltHash = keccak256(abi.encodePacked(REGISTRY_ADDRESS, opNode));
        predictedAddress = Clones.predictDeterministicAddress(BASE_RESOLVER_ADDRESS, saltHash, BASE_RESOLVER_ADDRESS);
    }

    function buildAttFetchRequest(bytes32 opNode, bytes32[] calldata slots)
        public
        view
        returns (EVMFetcher.EVMFetchRequest memory request)
    {
        address target = getOpResolverAddress(opNode);
        request = EVMFetcher.newFetchRequest(IEVMVerifier(address(this)), target);

        unchecked {
            uint256 slotsLength = slots.length;
            for (uint256 i = 0; i < slotsLength; ++i) {
                request.getStatic(uint256(slots[i]));
            }

            if (request.commands.length > 0 && request.operationIdx < 32) {
                // Terminate last command
                _addOperation(request, 0xff);
            }
        }
    }
}

contract OptidomainsL1ResolverInternal is OptiDomainsFetchTarget {
    using EVMFetcher for EVMFetcher.EVMFetchRequest;
    using BytesUtils for bytes;

    function _isCCIPCallback() private pure returns (bool) {
        // Verify the following format: [funcsig[4], ..., len[4], funcsig[4], keccak256(len, funcsig)[32]]
    }

    function _initCCIPCallback() private {}

    function _initCCIPFetch() private pure {
        assembly {
            // If free memory pointer is not at 0x80 then revert
            if iszero(eq(mload(0x40), 0x80)) {
                mstore(0, FreeMemoryOccupied_error_signature)
                revert(0, FreeMemoryOccupied_error_length)
            }

            // Move free memory pointer by 33 positions
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
        unchecked {
            bytes32[] memory slots;
            assembly {
                slots := 0x80
            }

            bytes32 ensNode = bytes32(msg.data[4:36]);
            bytes memory dnsEncodedName;

            // Try to fetch dns-encoded name
            if (msg.sender == address(this)) {}

            // for (uint256 i = 0; i < slots.length; ++i) {
            //     emit CCIPSlot(slots[i]);
            // }
        }
    }

    modifier ccip() {
        bool isCallback = _isCCIPCallback();

        if (isCallback) {
            _initCCIPCallback();
        } else {
            _initCCIPFetch();
        }

        _;

        if (!isCallback) {
            _finalizeCCIP();
        }
    }

    function testCCIP() public ccip {
        _appendCCIPslot(keccak256(abi.encode(5000)));
        _appendCCIPslot(keccak256(abi.encode(3000)));
        _appendCCIPslot(keccak256(abi.encode(2000)));
    }
}
