// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Config {
    string public apiKey = "9CD1MZI2S38S3KPQMEFUUA65R92NRA6B5N";
}
/**
 * @title SC-11 — Final Fungible Token Standard With Customizable Actions
 * @author Katascha White
 *
 * @notice
 * SC-11 is a fixed-supply SC-11-compatible fungible token
 * standard for the EONS (E) token.
 *
 * Features:
 * - Fixed supply of 100 billion E
 * - Entire supply created during deployment
 * - No minting after deployment
 * - Owner/controller identification
 * - Emergency pause mechanism
 * - Circuit breaker (auto-pause on large or rate-limited transfers)
 * - Customizable action registry
 * - Beneficiary registry
 * - Asset trace logging
 */

contract SC11 {

    // =============================================================
    // TOKEN DATA
    // =============================================================

    string public constant name = "EONS";
    string public constant symbol = "E";
    uint8 public constant decimals = 18;

    uint256 public constant TOTAL_SUPPLY =
        100_000_000_000 * 10 ** 18;

    uint256 private _totalSupply;

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256))
        private _allowances;


    // =============================================================
    // OWNER DATA
    // =============================================================

    address private _owner;

    modifier onlyOwner() {
        require(
            msg.sender == _owner,
            "SC-11: Not authorized"
        );
        _;
    }

    modifier notPaused() {
        require(
            !paused,
            "SC-11: Contract paused"
        );
        _;
    }


    // =============================================================
    // BENEFICIARIES
    // =============================================================

    struct Beneficiary {
        string name;
        uint256 percentage;
        address wallet;
    }

    Beneficiary[2] private _beneficiaries;


    // =============================================================
    // CONTRACT STATE
    // =============================================================

    bool public paused;


    // =============================================================
    // BOT BLOCKLIST
    // =============================================================

    mapping(address => bool) private _blocked;

    event AddressBlocked(address indexed account);
    event AddressUnblocked(address indexed account);

    modifier notBlocked(address account) {
        require(
            !_blocked[account],
            "SC-11: Address is blocked"
        );
        _;
    }


    // =============================================================
    // CUSTOM ACTION STORAGE
    // =============================================================

    mapping(bytes32 => bool) private _actions;


    // =============================================================
    // ASSET TRACE LOG
    // =============================================================

    struct AssetTrace {
        address from;
        address to;
        uint256 amount;
        uint256 timestamp;
        bytes32 actionId;
    }

    AssetTrace[] private _assetTraces;


    // =============================================================
    // EVENTS
    // =============================================================

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event ActionRegistered(bytes32 indexed actionId, string actionName);
    event AssetTraced(
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes32 indexed actionId,
        uint256 timestamp
    );


    // =============================================================
    // CONSTRUCTOR
    // =============================================================

    constructor(address kataschaWallet) {
        address initialOwner = 0x8eB93b429CEaf9EE2E3b1a6A9fb2eaFa91C4723f;

        require(
            initialOwner != address(0),
            "SC-11: Invalid owner"
        );

        require(
            kataschaWallet != address(0),
            "SC-11: Invalid Katascha wallet"
        );

        _owner = initialOwner;

        // Fixed supply created exactly once.
        _totalSupply = TOTAL_SUPPLY;

        // Assign supply to owner.
        _balances[initialOwner] = TOTAL_SUPPLY;

        _beneficiaries[0] = Beneficiary(
            "Katascha White",
            50,
            kataschaWallet
        );

        _beneficiaries[1] = Beneficiary(
            "Eon's Global Foundation",
            50,
            kataschaWallet
        );

        uint256 totalPercentage =
            _beneficiaries[0].percentage +
            _beneficiaries[1].percentage;

        require(
            totalPercentage == 100,
            "SC-11: Beneficiary total must equal 100"
        );

        emit OwnershipTransferred(
            address(0),
            initialOwner
        );

        // Pre-block known bot/sybil address.
        _blocked[0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045] = true;
        emit AddressBlocked(0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045);

        emit Transfer(
            address(0),
            initialOwner,
            TOTAL_SUPPLY
        );
    }


    // =============================================================
    // TOKEN FUNCTIONS
    // =============================================================

    function totalSupply()
        external
        view
        returns (uint256)
    {
        return _totalSupply;
    }

    function balanceOf(
        address account
    )
        external
        view
        returns (uint256)
    {
        return _balances[account];
    }

    function transfer(
        address to,
        uint256 amount
    )
        external
        notPaused
        returns (bool)
    {
        _transfer(
            msg.sender,
            to,
            amount
        );

        return true;
    }

    function allowance(
        address tokenOwner,
        address spender
    )
        external
        view
        returns (uint256)
    {
        return _allowances[tokenOwner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    )
        external
        notPaused
        returns (bool)
    {
        require(
            spender != address(0),
            "SC-11: Invalid spender"
        );

        _allowances[msg.sender][spender] =
            amount;

        emit Approval(
            msg.sender,
            spender,
            amount
        );

        return true;
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    )
        external
        notPaused
        returns (bool)
    {
        require(
            spender != address(0),
            "SC-11: Invalid spender"
        );

        uint256 newAllowance =
            _allowances[msg.sender][spender] +
            addedValue;

        _allowances[msg.sender][spender] =
            newAllowance;

        emit Approval(
            msg.sender,
            spender,
            newAllowance
        );

        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    )
        external
        notPaused
        returns (bool)
    {
        uint256 currentAllowance =
            _allowances[msg.sender][spender];

        require(
            currentAllowance >= subtractedValue,
            "SC-11: Allowance below zero"
        );

        uint256 newAllowance =
            currentAllowance - subtractedValue;

        _allowances[msg.sender][spender] =
            newAllowance;

        emit Approval(
            msg.sender,
            spender,
            newAllowance
        );

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    )
        external
        notPaused
        returns (bool)
    {
        uint256 currentAllowance =
            _allowances[from][msg.sender];

        require(
            currentAllowance >= amount,
            "SC-11: Insufficient allowance"
        );

        _transfer(from, to, amount);

        _allowances[from][msg.sender] =
            currentAllowance - amount;

        emit Approval(
            from,
            msg.sender,
            _allowances[from][msg.sender]
        );

        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    )
        internal
    {
        require(
            from != address(0),
            "SC-11: Invalid sender"
        );

        require(
            to != address(0),
            "SC-11: Invalid receiver"
        );

        require(
            !_blocked[from],
            "SC-11: Sender is blocked"
        );

        require(
            !_blocked[to],
            "SC-11: Receiver is blocked"
        );

        uint256 fromBalance = _balances[from];

        require(
            fromBalance >= amount,
            "SC-11: Insufficient balance"
        );

        _enforceCircuitBreaker(from, to, amount);

        _balances[from] = fromBalance - amount;
        _balances[to] = _balances[to] + amount;

        emit Transfer(from, to, amount);
    }


    // =============================================================
    // OWNER FUNCTIONS
    // =============================================================

    function owner()
        external
        view
        returns (address)
    {
        return _owner;
    }

    function transferOwnership(
        address newOwner
    )
        external
        onlyOwner
    {
        require(
            newOwner != address(0),
            "SC-11: Invalid new owner"
        );

        emit OwnershipTransferred(
            _owner,
            newOwner
        );

        _owner = newOwner;
    }

    function renounceOwnership()
        external
        onlyOwner
    {
        emit OwnershipTransferred(
            _owner,
            address(0)
        );

        _owner = address(0);
    }


    // =============================================================
    // BOT BLOCKLIST FUNCTIONS
    // =============================================================

    function blockAddress(address account)
        external
        onlyOwner
    {
        require(
            account != address(0),
            "SC-11: Invalid address"
        );

        require(
            !_blocked[account],
            "SC-11: Address already blocked"
        );

        _blocked[account] = true;

        emit AddressBlocked(account);
    }

    function unblockAddress(address account)
        external
        onlyOwner
    {
        require(
            _blocked[account],
            "SC-11: Address not blocked"
        );

        _blocked[account] = false;

        emit AddressUnblocked(account);
    }

    function isBlocked(address account)
        external
        view
        returns (bool)
    {
        return _blocked[account];
    }


    // =============================================================
    // PAUSE / UNPAUSE
    // =============================================================

    function pause()
        external
        onlyOwner
    {
        require(
            !paused,
            "SC-11: Already paused"
        );

        paused = true;

        emit Paused(msg.sender);
    }

    function unpause()
        external
        onlyOwner
    {
        require(
            paused,
            "SC-11: Not paused"
        );

        paused = false;

        emit Unpaused(msg.sender);
    }


    // =============================================================
    // CIRCUIT BREAKER
    // =============================================================

    /// @dev When enabled, the circuit breaker auto-triggers a full
    ///      pause if a single transfer exceeds the threshold, and
    ///      optionally limits transfers per account per window.
    uint256 public circuitBreakerThreshold;   // 0 = disabled
    uint256 public circuitBreakerWindow;      // time window in seconds
    uint256 public circuitBreakerLimit;       // max per-account amount per window; 0 = unlimited

    bool public circuitBreakerTripped;

    mapping(address => uint256) private _cbWindowStart;
    mapping(address => uint256) private _cbWindowSpent;

    event CircuitBreakerTriggered(address indexed from, address indexed to, uint256 amount);
    event CircuitBreakerThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
    event CircuitBreakerLimitUpdated(uint256 oldLimit, uint256 newLimit);
    event CircuitBreakerWindowUpdated(uint256 oldWindow, uint256 newWindow);
    event CircuitBreakerReset();

    function setCircuitBreaker(
        uint256 threshold,
        uint256 window,
        uint256 limit
    )
        external
        onlyOwner
    {
        emit CircuitBreakerThresholdUpdated(circuitBreakerThreshold, threshold);
        emit CircuitBreakerLimitUpdated(circuitBreakerLimit, limit);
        emit CircuitBreakerWindowUpdated(circuitBreakerWindow, window);

        circuitBreakerThreshold = threshold;
        circuitBreakerWindow = window;
        circuitBreakerLimit = limit;
    }

    function resetCircuitBreaker()
        external
        onlyOwner
    {
        circuitBreakerTripped = false;
        emit CircuitBreakerReset();
    }

    /// @dev Call from _transfer to enforce circuit-breaker rules.
    function _enforceCircuitBreaker(
        address from,
        address to,
        uint256 amount
    )
        internal
    {
        // Threshold check: trip if a single transfer is too large.
        if (
            circuitBreakerThreshold > 0 &&
            amount >= circuitBreakerThreshold
        ) {
            circuitBreakerTripped = true;
            paused = true;
            emit CircuitBreakerTriggered(from, to, amount);
            emit Paused(msg.sender);
            return;
        }

        // Per-account rate limit within the rolling window.
        if (circuitBreakerLimit > 0 && circuitBreakerWindow > 0) {
            uint256 windowStart = _cbWindowStart[from];
            uint256 now_ = block.timestamp;

            if (windowStart == 0 || now_ >= windowStart + circuitBreakerWindow) {
                _cbWindowStart[from] = now_;
                _cbWindowSpent[from] = 0;
            }

            uint256 newSpent = _cbWindowSpent[from] + amount;

            if (newSpent > circuitBreakerLimit) {
                circuitBreakerTripped = true;
                paused = true;
                emit CircuitBreakerTriggered(from, to, amount);
                emit Paused(msg.sender);
                return;
            }

            _cbWindowSpent[from] = newSpent;
        }
    }


    // =============================================================
    // CUSTOMIZABLE ACTION REGISTRY
    // =============================================================

    function registerAction(
        bytes32 actionId
    )
        external
        onlyOwner
    {
        require(
            actionId != bytes32(0),
            "SC-11: Invalid action ID"
        );

        require(
            !_actions[actionId],
            "SC-11: Action already registered"
        );

        _actions[actionId] = true;

        emit ActionRegistered(
            actionId,
            ""
        );
    }

    function removeAction(
        bytes32 actionId
    )
        external
        onlyOwner
    {
        require(
            _actions[actionId],
            "SC-11: Action not registered"
        );

        _actions[actionId] = false;
    }

    function isActionRegistered(
        bytes32 actionId
    )
        external
        view
        returns (bool)
    {
        return _actions[actionId];
    }


    // =============================================================
    // BENEFICIARY FUNCTIONS
    // =============================================================

    function getBeneficiaries()
        external
        view
        returns (Beneficiary[2] memory)
    {
        return _beneficiaries;
    }

    function getBeneficiary(
        uint256 index
    )
        external
        view
        returns (Beneficiary memory)
    {
        require(
            index < 2,
            "SC-11: Invalid beneficiary index"
        );

        return _beneficiaries[index];
    }


    // =============================================================
    // ASSET TRACE LOGGING
    // =============================================================

    function logAssetTrace(
        address from,
        address to,
        uint256 amount,
        bytes32 actionId
    )
        external
        onlyOwner
    {
        require(
            _actions[actionId],
            "SC-11: Action not registered"
        );

        _assetTraces.push(AssetTrace(
            from,
            to,
            amount,
            block.timestamp,
            actionId
        ));

        emit AssetTraced(
            from,
            to,
            amount,
            actionId,
            block.timestamp
        );
    }

    function getAssetTraceCount()
        external
        view
        returns (uint256)
    {
        return _assetTraces.length;
    }

    function getAssetTrace(
        uint256 index
    )
        external
        view
        returns (AssetTrace memory)
    {
        require(
            index < _assetTraces.length,
            "SC-11: Invalid trace index"
        );

        return _assetTraces[index];
    }


    // =============================================================
    // TRACEABLE ASSETS
    // =============================================================

    /// @notice Returns all trace entries where `account` is sender or receiver.
    function getAssetTracesForAddress(
        address account
    )
        external
        view
        returns (AssetTrace[] memory)
    {
        uint256 count;
        for (uint256 i = 0; i < _assetTraces.length; i++) {
            if (_assetTraces[i].from == account || _assetTraces[i].to == account) {
                count++;
            }
        }

        AssetTrace[] memory result = new AssetTrace[](count);
        uint256 idx;
        for (uint256 i = 0; i < _assetTraces.length; i++) {
            if (_assetTraces[i].from == account || _assetTraces[i].to == account) {
                result[idx] = _assetTraces[i];
                idx++;
            }
        }

        return result;
    }

    /// @notice Returns all trace entries associated with a given action ID.
    function getAssetTracesByAction(
        bytes32 actionId
    )
        external
        view
        returns (AssetTrace[] memory)
    {
        uint256 count;
        for (uint256 i = 0; i < _assetTraces.length; i++) {
            if (_assetTraces[i].actionId == actionId) {
                count++;
            }
        }

        AssetTrace[] memory result = new AssetTrace[](count);
        uint256 idx;
        for (uint256 i = 0; i < _assetTraces.length; i++) {
            if (_assetTraces[i].actionId == actionId) {
                result[idx] = _assetTraces[i];
                idx++;
            }
        }

        return result;
    }

    /// @notice Returns a page of trace entries for large log retrieval.
    function getAssetTracesPaginated(
        uint256 offset,
        uint256 limit
    )
        external
        view
        returns (AssetTrace[] memory)
    {
        require(
            offset < _assetTraces.length,
            "SC-11: Offset out of range"
        );

        uint256 end = offset + limit;
        if (end > _assetTraces.length) {
            end = _assetTraces.length;
        }

        AssetTrace[] memory result = new AssetTrace[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            result[i - offset] = _assetTraces[i];
        }

        return result;
    }

    /// @notice Returns the full trace history for an address as parallel arrays.
    function getTraceableAssetHistory(
        address account
    )
        external
        view
        returns (
            address[] memory from,
            address[] memory to,
            uint256[] memory amounts,
            uint256[] memory timestamps,
            bytes32[] memory actionIds
        )
    {
        uint256 count;
        for (uint256 i = 0; i < _assetTraces.length; i++) {
            if (_assetTraces[i].from == account || _assetTraces[i].to == account) {
                count++;
            }
        }

        from = new address[](count);
        to = new address[](count);
        amounts = new uint256[](count);
        timestamps = new uint256[](count);
        actionIds = new bytes32[](count);

        uint256 idx;
        for (uint256 i = 0; i < _assetTraces.length; i++) {
            if (_assetTraces[i].from == account || _assetTraces[i].to == account) {
                from[idx] = _assetTraces[i].from;
                to[idx] = _assetTraces[i].to;
                amounts[idx] = _assetTraces[i].amount;
                timestamps[idx] = _assetTraces[i].timestamp;
                actionIds[idx] = _assetTraces[i].actionId;
                idx++;
            }
        }
    }

    /// @notice Computes the total volume of traced assets for an account.
    function getTracedVolumeForAddress(
        address account
    )
        external
        view
        returns (uint256 sent, uint256 received)
    {
        for (uint256 i = 0; i < _assetTraces.length; i++) {
            if (_assetTraces[i].from == account) {
                sent += _assetTraces[i].amount;
            }
            if (_assetTraces[i].to == account) {
                received += _assetTraces[i].amount;
            }
        }
    }
}

