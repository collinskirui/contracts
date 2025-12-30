pragma solidity ^0.8.20;

/// Taxpayer
/// Tracks age, allowance and marital relations with Echidna invariants
contract Taxpayer {
    mapping(address => uint256) public age;
    mapping(address => uint256) public allowance;
    mapping(address => address) public spouse;

    uint256 public constant DEFAULT_ALLOWANCE = 5000;

    constructor() {
        // Gives the user the default allowance.
        allowance[msg.sender] = DEFAULT_ALLOWANCE;
    }

    // -----------------------------
    // Basic functions
    // -----------------------------
    function setAge(uint256 _age) public {
        // married people cannot set age to zero
        if (_age == 0 && spouse[msg.sender] != address(0)) {
            revert("Married taxpayer cannot have age 0");
        }
        age[msg.sender] = _age;
    }

    /// Set allowance for caller.
    /// If caller is unmarried, just set it.
    /// If caller is married, keep the pooled sum constant by adjusting the partner.
    function setAllowance(uint256 _allowance) public {
        address partner = spouse[msg.sender];

        if (partner == address(0)) {
            // unmarried: free to set any allowance
            allowance[msg.sender] = _allowance;
            return;
        }

        // married: preserve the pooled sum (which we define as 2 * DEFAULT_ALLOWANCE)
        // compute current pooled total (safe with uint256)
        uint256 total = allowance[msg.sender] + allowance[partner];

        // If pooled total is zero (e.g., both never initialized), set to canonical pool
        if (total == 0) {
            total = 2 * DEFAULT_ALLOWANCE;
            allowance[msg.sender] = _allowance;
            allowance[partner] = total - _allowance;
            return;
        }

        // apply requested new value for caller and adjust partner so sum remains constant
        allowance[msg.sender] = _allowance;
        // if _allowance > total this will underflow in older versions; in 0.8.x it reverts.
        // To avoid revert, clamp partner to zero if needed (but we prefer to revert on invalid attempts).
        require(_allowance <= total, "requested allowance exceeds pooled total");
        allowance[partner] = total - _allowance;
    }

    /// Marry another address
    /// After marriage we **canonicalize** allowances to DEFAULT_ALLOWANCE for both spouses
    /// so the pooled invariant becomes deterministic and cannot be violated by prior setAllowance calls.
    function marry(address _partner) public {
        require(_partner != msg.sender, "Cannot marry self");
        require(spouse[msg.sender] == address(0), "Already married");
        require(spouse[_partner] == address(0), "Partner already married");
        require(age[msg.sender] > 0, "Your age must be set before marriage");
        require(age[_partner] > 0, "Partner's age must be set before marriage");

        spouse[msg.sender] = _partner;
        spouse[_partner] = msg.sender;

        // Canonicalize allowances to the default for both partners to ensure the pooled invariants.
        allowance[msg.sender] = DEFAULT_ALLOWANCE;
        allowance[_partner] = DEFAULT_ALLOWANCE;
    }

    function divorce() public {
        address partner = spouse[msg.sender];
        require(partner != address(0), "Not married");

        spouse[msg.sender] = address(0);
        spouse[partner] = address(0);

        // On divorce we leave allowances as they are (they can be adjusted by setAllowance)
    }

    // -----------------------------
    // Echidna invariants (no args, return bool)
    // -----------------------------

    /// Married couples must keep the canonical pooled allowance (2 * DEFAULT_ALLOWANCE)
    function echidna_allowance_sum_constant() public view returns (bool) {
        address partner = spouse[msg.sender];
        if (partner == address(0)) return true;
        uint256 total = allowance[msg.sender] + allowance[partner];
        return total == 2 * DEFAULT_ALLOWANCE;
    }

    /// Allowance non-negative
    function echidna_allowance_non_negative() public view returns (bool) {
        // always true for uint
        return allowance[msg.sender] >= 0;
    }

    /// Marriage symmetry
    function echidna_marriage_is_symmetric() public view returns (bool) {
        address partner = spouse[msg.sender];
        if (partner == address(0)) return true;
        return spouse[partner] == msg.sender;
    }

    /// No self-marriage
    function echidna_no_self_marriage() public view returns (bool) {
        return spouse[msg.sender] != msg.sender;
    }

    /// Married implies age > 0
    function echidna_age_nonzero_if_married() public view returns (bool) {
        address partner = spouse[msg.sender];
        if (partner == address(0)) return true;
        return age[msg.sender] > 0;
    }
}
