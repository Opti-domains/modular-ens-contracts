// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import {IERC165} from "@solidstate/contracts/interfaces/IERC165.sol";
import "@ensdomains/ens-contracts/dnssec-oracle/RRUtils.sol";
import "../../attester/OptiResolverAttester.sol";
import "../../auth/OptiResolverAuth.sol";
import "./IDNSRecordResolver.sol";
import "./IDNSZoneResolver.sol";

bytes32 constant DNS_RESOLVER_SCHEMA_ZONEHASHES =
    keccak256(abi.encodePacked("bytes32 node,bytes zonehashes", address(0), true));
bytes32 constant DNS_RESOLVER_SCHEMA_RECORDS =
    keccak256(abi.encodePacked("bytes32 node,bytes32 nameHash,uint16 resource,bytes data", address(0), true));
bytes32 constant DNS_RESOLVER_SCHEMA_COUNT =
    keccak256(abi.encodePacked("bytes32 node,bytes32 nameHash,uint16 count", address(0), true));

abstract contract DNSResolver is
    IDNSRecordResolver,
    IDNSZoneResolver,
    OptiResolverAttester,
    OptiResolverAuth,
    IERC165
{
    using RRUtils for *;
    using BytesUtils for bytes;

    /**
     * Set one or more DNS records.  Records are supplied in wire-format.
     * Records with the same node/name/resource must be supplied one after the
     * other to ensure the data is updated correctly. For example, if the data
     * was supplied:
     *     a.example.com IN A 1.2.3.4
     *     a.example.com IN A 5.6.7.8
     *     www.example.com IN CNAME a.example.com.
     * then this would store the two A records for a.example.com correctly as a
     * single RRSET, however if the data was supplied:
     *     a.example.com IN A 1.2.3.4
     *     www.example.com IN CNAME a.example.com.
     *     a.example.com IN A 5.6.7.8
     * then this would store the first A record, the CNAME, then the second A
     * record which would overwrite the first.
     *
     * @param node the namehash of the node for which to set the records
     * @param data the DNS wire format records to set
     */
    function setDNSRecords(bytes32 node, bytes calldata data) external virtual authorised(node) {
        uint16 resource = 0;
        uint256 offset = 0;
        bytes memory name;
        bytes memory value;
        bytes32 nameHash;
        // Iterate over the data to add the resource records
        for (RRUtils.RRIterator memory iter = data.iterateRRs(0); !iter.done(); iter.next()) {
            if (resource == 0) {
                resource = iter.dnstype;
                name = iter.name();
                nameHash = keccak256(abi.encodePacked(name));
                value = bytes(iter.rdata());
            } else {
                bytes memory newName = iter.name();
                if (resource != iter.dnstype || !name.equals(newName)) {
                    setDNSRRSet(node, name, resource, data, offset, iter.offset - offset, value.length == 0);
                    resource = iter.dnstype;
                    offset = iter.offset;
                    name = newName;
                    nameHash = keccak256(name);
                    value = bytes(iter.rdata());
                }
            }
        }
        if (name.length > 0) {
            setDNSRRSet(node, name, resource, data, offset, data.length - offset, value.length == 0);
        }
    }

    /**
     * Obtain a DNS record.
     * @param node the namehash of the node for which to fetch the record
     * @param name the keccak-256 hash of the fully-qualified name for which to fetch the record
     * @param resource the ID of the resource as per https://en.wikipedia.org/wiki/List_of_DNS_record_types
     * @return the DNS record in wire format if present, otherwise empty
     */
    function dnsRecord(bytes32 node, bytes32 name, uint16 resource)
        public
        view
        virtual
        override
        ccip
        returns (bytes memory)
    {
        bytes memory response = _read(DNS_RESOLVER_SCHEMA_RECORDS, abi.encode(node, name, resource));
        if (response.length == 0) {
            return "";
        }
        return abi.decode(response, (bytes));
    }

    function dnsRecordsCount(bytes32 node, bytes32 name) public view virtual ccip returns (uint16) {
        bytes memory response = _read(DNS_RESOLVER_SCHEMA_COUNT, abi.encode(node, name));
        if (response.length == 0) {
            return 0;
        }
        return abi.decode(response, (uint16));
    }

    /**
     * Check if a given node has records.
     * @param node the namehash of the node for which to check the records
     * @param name the namehash of the node for which to check the records
     */
    function hasDNSRecords(bytes32 node, bytes32 name) public view virtual returns (bool) {
        return dnsRecordsCount(node, name) != 0;
    }

    /**
     * setZonehash sets the hash for the zone.
     * May only be called by the owner of that node in the ENS registry.
     * @param node The node to update.
     * @param hash The zonehash to set
     */
    function setZonehash(bytes32 node, bytes calldata hash) external virtual authorised(node) {
        bytes memory oldhashRaw = _read(DNS_RESOLVER_SCHEMA_ZONEHASHES, abi.encode(node));
        bytes memory oldhash;
        if (oldhashRaw.length > 0) {
            oldhash = abi.decode(oldhashRaw, (bytes));
        }

        _write(DNS_RESOLVER_SCHEMA_ZONEHASHES, abi.encode(node), abi.encode(hash));
        emit DNSZonehashChanged(node, oldhash, hash);
    }

    /**
     * zonehash obtains the hash for the zone.
     * @param node The ENS node to query.
     * @return result The associated contenthash.
     */
    function zonehash(bytes32 node) external view virtual override ccip returns (bytes memory result) {
        bytes memory response = _read(DNS_RESOLVER_SCHEMA_ZONEHASHES, abi.encode(node));
        if (response.length == 0) return "";
        result = abi.decode(response, (bytes));
    }

    function supportsInterface(bytes4 interfaceID) public view virtual returns (bool) {
        return interfaceID == type(IDNSRecordResolver).interfaceId || interfaceID == type(IDNSZoneResolver).interfaceId;
    }

    function setDNSRRSet(
        bytes32 node,
        bytes memory name,
        uint16 resource,
        bytes memory data,
        uint256 offset,
        uint256 size,
        bool deleteRecord
    ) private {
        bytes32 nameHash = keccak256(name);
        bytes memory rrData = data.substring(offset, size);
        bytes memory oldRecords = dnsRecord(node, nameHash, resource);
        uint16 nameEntriesCount = dnsRecordsCount(node, nameHash);
        if (deleteRecord) {
            if (oldRecords.length != 0) {
                _write(DNS_RESOLVER_SCHEMA_COUNT, abi.encode(node, nameHash), abi.encode(nameEntriesCount - 1));
            }
            _revoke(DNS_RESOLVER_SCHEMA_RECORDS, abi.encode(node, nameHash, resource));
            emit DNSRecordDeleted(node, name, resource);
        } else {
            if (oldRecords.length == 0) {
                _write(DNS_RESOLVER_SCHEMA_COUNT, abi.encode(node, nameHash), abi.encode(nameEntriesCount + 1));
            }
            _write(DNS_RESOLVER_SCHEMA_RECORDS, abi.encode(node, nameHash, resource), abi.encode(rrData));
            emit DNSRecordChanged(node, name, resource, rrData);
        }
    }
}
