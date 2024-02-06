pragma solidity >=0.8.4;

interface IL2ReverseRegistrarPrivileged {
    function setNameFromRegistrar(bytes32 tldNode, address addr, string memory name) external returns (bytes32);

    function setTextFromRegistrar(bytes32 tldNode, address addr, string calldata key, string calldata value)
        external
        returns (bytes32);
}
