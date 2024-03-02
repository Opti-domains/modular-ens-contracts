// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {EVMFetcher} from "@ensdomains/evm-verifier/contracts/EVMFetcher.sol";
import {IEVMVerifier} from "@ensdomains/evm-verifier/contracts/IEVMVerifier.sol";

address constant REGISTRY_ADDRESS = address(0);
address constant BASE_OP_RESOLVER_ADDRESS = address(0);

library OptiL1ResolverUtils {
    using EVMFetcher for EVMFetcher.EVMFetchRequest;

    function _addOperation(EVMFetcher.EVMFetchRequest memory request, uint8 op) private pure {
        uint256 commandIdx = request.commands.length - 1;
        request.commands[commandIdx] =
            request.commands[commandIdx] | (bytes32(bytes1(op)) >> (8 * request.operationIdx++));
    }

    function getOpResolverAddress(bytes32 opNode) public pure returns (address predictedAddress) {
        bytes32 saltHash = keccak256(abi.encodePacked(REGISTRY_ADDRESS, opNode));
        predictedAddress =
            Clones.predictDeterministicAddress(BASE_OP_RESOLVER_ADDRESS, saltHash, BASE_OP_RESOLVER_ADDRESS);
    }

    function buildAttFetchRequest(bytes32 opNode, bytes32[] calldata slots)
        public
        view
        returns (EVMFetcher.EVMFetchRequest memory request, address target)
    {
        target = getOpResolverAddress(opNode);
        request = EVMFetcher.newFetchRequest(IEVMVerifier(address(this)), target);

        unchecked {
            uint256 slotsLength = slots.length;
            for (uint256 i = 0; i < slotsLength; ++i) {
                request.getStatic(uint256(keccak256(abi.encodePacked(opNode, slots[i]))));
            }

            if (request.commands.length > 0 && request.operationIdx < 32) {
                // Terminate last command
                _addOperation(request, 0xff);
            }
        }
    }
}
