// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IVestcrow} from "./interfaces/IVestcrow.sol";
import {IERC20} from "solidstate-solidity/token/ERC20/IERC20.sol";
import {SafeERC20} from "solidstate-solidity/utils/SafeERC20.sol";
import {EnumerableSet} from "solidstate-solidity/utils/EnumerableSet.sol";
import {ABDKMath64x64} from "abdk-libraries-solidity/ABDKMath64x64.sol";

contract Vestcrow is IVestcrow {

    using SafeERC20 for IERC20;
    using ABDKMath64x64 for int128;
    using EnumerableSet for EnumerableSet.UintSet;

    uint internal constant MAX_LOCK = 3600 * 24 * 365 * 2;
    //int128 internal constant ONE_64x64 = 0x10000000000000000;

    address internal immutable TOKEN;
    uint256 internal nextLockId;

    struct Deposit {
        uint at; 
        uint amount;
        uint balance;
        uint bias;
    }

    struct Lock {
        uint end; //until, unlocks
        uint lastModifiedAt;
        uint numberOfDeposits;
        uint totalAmountDeposited;
        uint amountClaimed;
        mapping(uint => Deposit) deposits;
    }

    mapping(uint => Lock) internal idToLock;
    mapping(uint => address) internal accountByLock;
    mapping(address => EnumerableSet.UintSet) internal locksByAccount;

    constructor (address token) {
        TOKEN = token;
    }

    modifier onlyLockOwner(address account, uint lockId) {
        require(accountByLock[lockId] == account, "not owner of lock");
        _;
    }

    //modifier isExpiredAndClaimed() {
    //}

    /*/////////////////////////////////////////////////////////////////////////
                                IVestcrow
    /////////////////////////////////////////////////////////////////////////*/

    function deposit(uint amount, uint duration) external returns (uint) {
        //require(acceptedTokens[token], "not accepted token");
        require(amount > 0, "invalid amount");
        require(duration > 0, "invalid duration");
        require(duration <= MAX_LOCK, "invalid duration");
        uint lockId = _deposit(msg.sender, amount, duration);
        IERC20(TOKEN).safeTransferFrom(msg.sender, address(this), amount);
        //emit Deposit();
        return lockId;
    }

    function depositAndExtend(uint lockId, uint amount, uint duration) external onlyLockOwner(msg.sender, lockId) {
        require(duration > 0, "invalid duration");
//        require(idToLock[lockId].end + duration <= MAX_LOCK, "invalid duration");
        require(idToLock[lockId].end < block.timestamp + duration, "invalid duration");
        _set_unlock_time(lockId, duration);
        _add_deposit(lockId, amount);
        IERC20(TOKEN).safeTransferFrom(msg.sender, address(this), amount);
    }

    function addDeposit(uint lockId, uint amount) external onlyLockOwner(msg.sender, lockId) {
        require(amount > 0, "invalid amount");
        _add_deposit(lockId, amount);
        IERC20(TOKEN).safeTransferFrom(msg.sender, address(this), amount);
    }

    function increaseDuration(uint lockId, uint duration) external onlyLockOwner(msg.sender, lockId) {
        require(duration > 0, "invalid duration");
        require(idToLock[lockId].end + duration <= MAX_LOCK, "invalid duration");
        require(idToLock[lockId].end < block.timestamp + duration, "invalid duration");
        _set_unlock_time(lockId, duration);
    }

    function withdraw() external {}

    ///////////////////////////////////////////////////////////////////////////

    function _deposit(address account, uint amount, uint duration) internal returns (uint) {
        uint lockId = _create_lock(account);
        _add_deposit(lockId, amount);
        _set_unlock_time(lockId, duration);
        return lockId;
    }

    function _create_lock(address account) internal returns (uint) {
        uint lockId = nextLockId;
        accountByLock[lockId] = account;
        locksByAccount[account].add(lockId);
        nextLockId++;
        return lockId;
    }

    function _set_unlock_time(uint lockId, uint duration) internal {
        idToLock[lockId].end = block.timestamp + duration;
        idToLock[lockId].lastModifiedAt = block.timestamp;
    }

    function _add_deposit(uint lockId, uint amount) internal {
        uint depositId = idToLock[lockId].numberOfDeposits;
        Deposit memory newDeposit = Deposit(block.timestamp, amount);
        idToLock[lockId].deposits[depositId] = newDeposit;
        idToLock[lockId].totalAmountDeposited += amount;
        idToLock[lockId].numberOfDeposits++;
    }
    
    function _remove_deposit(uint lockId, uint depositId) internal {
        uint last = idToLock[lockId].numberOfDeposits - 1;

        require(depositId <= last, "depositId out of range");
        
        idToLock[lockId].totalAmountDeposited -= idToLock[lockId].deposits[depositId].amount;

        if (depositId < last) {
            Deposit storage value = idToLock[lockId].deposits[last];
            idToLock[lockId].deposits[depositId] = value;
        }

        delete idToLock[lockId].deposits[last];
        idToLock[lockId].numberOfDeposits--;
    }
   
    function _remove_lock(address account, uint lockId) internal {
        require(idToLock[lockId].numberOfDeposits == 0, "lock contains deposits");
        //require(block.timestamp > idToLock[lockId].end, "lock has not expired"); 
        //require(idToLock[lockId].totalAmountDeposited == idToLock[lockId].amountClaimed, "lock contains vested tokens");
        locksByAccount[account].remove(lockId);
        delete accountByLock[lockId];
    }

    ///////////////////////////////////////////////////////////////////////////

    function _decay_rate(Lock storage lock, uint depositIndex) internal returns (uint) {
        return _value_of_deposit(lock, depositIndex, lock.lastModifiedAt) / ( lock.end - lock.lastModifiedAt ) ; 
    }

    function _bias_weight(Lock storage lock) internal view returns (uint) {
        return lock.end - lock.lastModifiedAt;
    }

    function _value_of_deposit(Lock storage lock, uint depositIndex, uint at) internal returns (uint) {
        uint untill_expire = ( lock.end - at ) * 1e18;
        uint lock_length = lock.end - lock.deposits[depositIndex].at;
        uint value = ( untill_expire / lock_length ) * lock.deposits[depositIndex].amount; 
        return value / 1e18; 
    }
    
    function _valueOfLock(Lock storage lock, uint at) internal returns (uint) {
        uint valueOfLock = 0;
        for (uint i = 0; i < lock.numberOfDeposits; i++) {
            valueOfLock += _value_of_deposit(lock, i, at); 
        }
        return valueOfLock;
    }

    // voting bias should consider amount unclaimed and bias per deposit.
    function _votingPower(Lock storage lock, uint at) internal returns (uint) {
        return _valueOfLock(lock, at) * _bias_weight(lock);
    }

    function _totalDeposited(address account) internal returns (uint) {
        EnumerableSet.UintSet storage userLockIds = locksByAccount[account]; 
        uint totalDeposited = 0;
        for (uint i = 0; i < userLockIds.length(); i++) {
            totalDeposited += idToLock[i].totalAmountDeposited;
        }
        return totalDeposited;
    }

    function _value(address account) internal returns (uint) {
        EnumerableSet.UintSet storage userLockIds = locksByAccount[account]; 
        uint totalValue = 0;
        for (uint i = 0; i < userLockIds.length(); i++) {
            totalValue += _valueOfLock(idToLock[i], block.timestamp);
        }
        return totalValue;
    }

    function _votes(address account) internal returns (uint) {
        EnumerableSet.UintSet storage userLockIds = locksByAccount[account]; 
        uint totalVotes = 0;
        for (uint i = 0; i < userLockIds.length(); i++) {
            totalVotes += _votingPower(idToLock[i], block.timestamp);
        }
        return totalVotes / MAX_LOCK;
    }

    ///////////////////////////////////////////////////////////////////////////

    function value() external returns (uint) {
        return _value(msg.sender);
    }

    function votes() external returns (uint) {
        return _votes(msg.sender);
    }
}
