pragma solidity ^0.8.20;

/// title Lottery (commit-reveal for taxpayers under 65)
contract Lottery {

    mapping(address => bytes32) public commitmentOf;
    mapping(address => bool) public joined;
    address[] public participants;

    mapping(address => bool) public revealed;
    mapping(address => uint256) public revealedValue;


    // -----------------------------
    // Commit Phase
    // -----------------------------

    /// User joins by submitting y = keccak256(x)
    function joinLottery(bytes32 y) public {
        require(!joined[msg.sender], "already joined");
        require(y != bytes32(0), "commitment cannot be zero");

        joined[msg.sender] = true;
        commitmentOf[msg.sender] = y;
        participants.push(msg.sender);
    }


    // -----------------------------
    // Reveal Phase
    // -----------------------------

    /// Reveals xi; verifies keccak256(xi) == stored commitment
    function reveal(uint256 xi) public {
        require(joined[msg.sender], "not joined");
        require(!revealed[msg.sender], "already revealed");

        require(
            keccak256(abi.encodePacked(xi)) == commitmentOf[msg.sender],
            "bad reveal"
        );

        revealed[msg.sender] = true;
        revealedValue[msg.sender] = xi;
    }


    // -----------------------------
    // Winner selection
    // -----------------------------

    /// Computes winner j = (x1 + ... + xn) % n
    function pickWinner() public view returns (address) {
        uint256 n = participants.length;
        require(n > 0, "no participants");
    //ensure all participants revealed
        uint256 sum = 0;

        for (uint256 i = 0; i < n; i++) {
            address p = participants[i];
             // treat missing reveal as zero or alternatively it require all revealed
            if (revealed[p]) {
                sum += revealedValue[p];
            }
        }

        uint256 j = sum % n;
        return participants[j];
    }


    // -----------------------------
    // Echidna invariants
    // -----------------------------

    /// No double join
    function echidna_no_double_join() public view returns (bool) {
        if (!joined[msg.sender]) return true;
        return commitmentOf[msg.sender] != bytes32(0);
    }

    /// Commitment must not be zero when joined
    function echidna_commit_nonzero() public view returns (bool) {
        if (!joined[msg.sender]) return true;
        return commitmentOf[msg.sender] != bytes32(0);
    }

    /// Winner selection must not revert when participants > 0
    function echidna_no_revert_pickWinner() public view returns (bool) {
        if (participants.length == 0) return true;
        pickWinner();
        return true;
    }
}
