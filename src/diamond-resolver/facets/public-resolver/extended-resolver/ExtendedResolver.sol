// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { IERC165 } from '@solidstate/contracts/interfaces/IERC165.sol';
import "./IExtendedResolver.sol";

contract ExtendedResolver is IERC165 {
    function resolve(
        bytes memory /* name */,
        bytes memory data
    ) external view returns (bytes memory) {
        (bool success, bytes memory result) = address(this).staticcall(data);
        if (success) {
            return result;
        } else {
            // Revert with the reason provided by the call
            assembly {
                revert(add(result, 0x20), mload(result))
            }
        }
    }

    function supportsInterface(
        bytes4 interfaceID
    )
        public
        view
        virtual
        returns (bool)
    {
        return interfaceID == type(IExtendedResolver).interfaceId;
    }
}
