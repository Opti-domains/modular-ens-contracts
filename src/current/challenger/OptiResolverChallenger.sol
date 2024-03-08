pragma solidity ^0.8.8;

import "./RootChallenger.sol";

bytes32 constant TOPIC_SUBMIT_ROOT = keccak256("optidomains.OptiResolverChallenger.submitRoot");

contract OptiResolverChallenger is RootChallenger {
    function _submitRoot(address operator, address resolver, bytes32[] calldata slots, bytes32[] calldata uids)
        internal
        returns (bytes32 root)
    {
        bytes32 slotsHash = keccak256(abi.encodePacked(slots));
        bytes32 uidsHash = keccak256(abi.encodePacked(uids));
        root = keccak256(abi.encodePacked(resolver, slotsHash, uidsHash));

        _publishChallengerRoot(operator, root);
    }

    function submitRoot(
        address operator,
        address resolver,
        bytes32[] calldata slots,
        bytes32[] calldata uids,
        bytes calldata signature
    ) public returns (bytes32 root) {
        root = _submitRoot(operator, resolver, slots, uids);

        if (
            msg.sender != operator
                && !SignatureValidator.validateBasicSignature(operator, TOPIC_SUBMIT_ROOT, root, signature)
        ) {
            revert InvalidSignature();
        }
    }
}
