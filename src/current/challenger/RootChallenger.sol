pragma solidity ^0.8.8;

contract RootChallenger {
    error NotOperator();
    error NotChallenger();
    error CannotChallenge(bytes32 root);
    error Challenged(bytes32 root);

    event ChallengerRootPublished(address indexed operator, bytes32 indexed root, uint256 challengePeriod);
    event RootChallenged(address indexed challenger, address indexed operator, bytes32 indexed root);
    event OperatorUpdated(address indexed operator, bool enabled, uint256 challengePeriod);
    event ChallengerUpdated(address indexed challenger, bool enabled);

    struct Operator {
        bool enabled;
        uint96 challengePeriod;
        uint128 jailedUntil;
    }

    struct Challenger {
        bool enabled;
        uint128 jailedUntil;
    }

    struct ChallengerRoot {
        uint256 validFrom;
        address operator;
        address challenger;
    }

    mapping(bytes32 => ChallengerRoot) public challengerRoot;
    mapping(address => Operator) public operators;
    mapping(address => Challenger) public challengers;

    function _setOperator(address operator, bool enabled, uint96 challengePeriod) internal {
        operators[operator].enabled = enabled;
        operators[operator].challengePeriod = challengePeriod;
        emit OperatorUpdated(operator, enabled, challengePeriod);
    }

    function _setChallenger(address challenger, bool enabled) internal {
        challengers[challenger].enabled = enabled;
        emit ChallengerUpdated(challenger, enabled);
    }

    function _publishChallengerRoot(address operator, bytes32 root) internal {
        if (!isOperator(operator)) {
            revert NotOperator();
        }

        if (challengerRoot[root].challenger != address(0)) {
            revert Challenged(root);
        }

        challengerRoot[root] = ChallengerRoot({
            validFrom: block.timestamp + operators[operator].challengePeriod,
            operator: operator,
            challenger: address(0)
        });

        emit ChallengerRootPublished(operator, root, operators[operator].challengePeriod);
    }

    function isOperator(address a) public view returns (bool) {
        return operators[a].enabled && block.timestamp > operators[a].jailedUntil;
    }

    function isChallenger(address a) public view returns (bool) {
        return challengers[a].enabled && block.timestamp > challengers[a].jailedUntil;
    }

    function challengeRoot(bytes32 root) external {
        if (!isChallenger(msg.sender)) {
            revert NotChallenger();
        }

        if (challengerRoot[root].challenger != address(0)) {
            revert Challenged(root);
        }

        if (challengerRoot[root].validFrom == 0 || block.timestamp >= challengerRoot[root].validFrom) {
            revert CannotChallenge(root);
        }

        challengerRoot[root].validFrom = 0;
        challengerRoot[root].challenger = msg.sender;
        operators[challengerRoot[root].operator].jailedUntil = uint128(block.timestamp + 1 days);

        emit RootChallenged(msg.sender, challengerRoot[root].operator, root);
    }

    function isValidRoot(bytes32 root) public view returns (bool) {
        return challengerRoot[root].validFrom > 0 && block.timestamp >= challengerRoot[root].validFrom;
    }
}
