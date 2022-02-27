pragma solidity ^0.8.0;

import {Vestcrow} from "../../Vestcrow.sol";
import {EnumerableSet} from "solidstate-solidity/utils/EnumerableSet.sol";

contract VestcrowMock is Vestcrow {

    using EnumerableSet for EnumerableSet.UintSet;

    constructor (address token) 
        Vestcrow(token) 
        { }

    function LOCK_END(uint _lockId) external returns (uint) {
        return idToLock[_lockId].end;
    }
    function LOCK_LAST_MODIFIED_AT(uint _lockId) external returns (uint) {
        return idToLock[_lockId].lastModifiedAt;
    }
    function LOCK_NUMBER_OF_DEPOSITS(uint _lockId) external returns (uint) {
        return idToLock[_lockId].numberOfDeposits;
    }
    function LOCK_TOTAL_AMOUNT_DEPOSITED(uint _lockId) external returns (uint) {
        return idToLock[_lockId].totalAmountDeposited;
    }
    function LOCK_AMOUNT_CLAIMED(uint _lockId) external returns (uint) {
        return idToLock[_lockId].amountClaimed;
    }
    function LOCK_DEPOSITS(uint _lockId, uint _depositId) external returns (Deposit memory) {
        return idToLock[_lockId].deposits[_depositId];
    }

    function NEXT_LOCK_ID() external view returns (uint) {
        return nextLockId;
    }
    function ACCOUNT_BY_LOCK(uint _lockId) external view returns (address) {
        return accountByLock[_lockId];
    }
    function LOCKS_BY_ACCOUNT_CONTAINS(address account, uint _lockId) external view returns (bool) {
        return locksByAccount[account].contains(_lockId);
    }
    function LOCKS_BY_ACCOUNT_LENGTH(address account) external view returns (uint) {
        return locksByAccount[account].length();
    }

    function create_lock(address account) external returns (uint) {
        return _create_lock(account);
    }

    function add_deposit(uint lockId, uint amount) external {
        _add_deposit(lockId, amount);
    }
    function remove_deposit(uint lockId, uint depositId) external {
        _remove_deposit(lockId, depositId);
    }

    function set_unlock_time(uint lockId, uint duration) external {
        _set_unlock_time(lockId, duration);
    }

    function remove_lock(address account, uint lockId) external {
        _remove_lock(account, lockId);
    }

    function value_of_deposit(uint _lockId, uint depositIndex, uint at) external returns (uint) {
        return _value_of_deposit(idToLock[_lockId], depositIndex, at); 
    }

    function bias_weight(uint _lockId, uint at) external view returns (uint) {
        return _bias_weight(idToLock[_lockId]);
    }

    function decay_rate(uint _lockId, uint depositIndex) external returns (uint) {
        return _decay_rate(idToLock[_lockId], depositIndex); 
    }
    
    function valueOfLock(uint _lockId, uint at) external returns (uint) {
        return _valueOfLock(idToLock[_lockId], at);
    }

    function votingPower(uint _lockId, uint at) external returns (uint) {
        return _votingPower(idToLock[_lockId],at);
    }

    function totalDeposited(address account) external returns (uint) {
        return _totalDeposited(account);
    }

    function value(address account) external returns (uint) {
        return _value(account);
    }
    function votes(address account) external returns (uint) {
        return _votes(account);
    }
}
