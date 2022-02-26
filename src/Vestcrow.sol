// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IVestcrow} from "./interfaces/IVestcrow.sol";
import {IERC20} from "solidstate-solidity/token/ERC20/IERC20.sol"; import {SafeERC20} from "solidstate-solidity/utils/SafeERC20.sol";
import {EnumerableSet} from "solidstate-solidity/utils/EnumerableSet.sol";
//import {ABDKMath64x64} from "abdk-libraries-solidity/ABDKMath64x64.sol";

contract Vestcrow is IVestcrow {

    using SafeERC20 for IERC20;
    //using ABDKMath64x64 for int128;
    using EnumerableSet for EnumerableSet.UintSet;

    uint internal constant MAX_LOCK = 3600* 365 * 2;
    //int128 internal constant ONE_64x64 = 0x10000000000000000;

    address internal immutable TOKEN;
    uint256 internal nextLockId;

    struct Deposit {
        uint at; 
        uint amount;
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

    /*/////////////////////////////////////////////////////////////////////////
                                IVestcrow
    /////////////////////////////////////////////////////////////////////////*/

    function deposit(uint amount, uint duration) external {
        //require(acceptedTokens[token], "not accepted token");
        require(amount > 0, "invalid amount");
        require(duration > 0, "invalid duration");
        require(duration <= MAX_LOCK, "invalid duration");
        _deposit(msg.sender, amount, duration);
    }

    function depositAndExtend(uint lockId, uint amount, uint duration) external onlyLockOwner(msg.sender, lockId) {
        _increase_duration(lockId, duration);
        _add_deposit(lockId, amount);
    }

    function addDeposit(uint lockId, uint amount) external onlyLockOwner(msg.sender, lockId) {
        require(amount > 0, "invalid amount");
        _add_deposit(lockId, amount);
    }

    function increaseDuration(uint lockId, uint duration) external onlyLockOwner(msg.sender, lockId) {
        require(duration > 0, "invalid duration");
        _increase_duration(lockId, duration);
    }

    function withdraw() external {}

    ///////////////////////////////////////////////////////////////////////////

    function _deposit(address account, uint amount, uint duration) internal {
        uint lockId = _create_lock(account, duration);
        _add_deposit(lockId, amount);
        IERC20(TOKEN).safeTransferFrom(account, address(this), amount);
        //emit Deposit();
    }

    function _create_lock(address account, uint duration) internal returns (uint) {
        uint lockId = nextLockId;
        idToLock[lockId].end = block.timestamp + duration;
        idToLock[lockId].lastModifiedAt = block.timestamp;
        accountByLock[lockId] = account;
        locksByAccount[account].add(lockId);
        nextLockId++;
        return lockId;
    }

    function _add_deposit(uint lockId, uint amount) internal {
        uint depositId = idToLock[lockId].numberOfDeposits;
        Deposit memory newDeposit = Deposit(block.timestamp, amount);
        idToLock[lockId].deposits[depositId] = newDeposit;
        idToLock[lockId].totalAmountDeposited += amount;
        idToLock[lockId].numberOfDeposits++;
    }

    function _increase_duration(uint lockId, uint duration) internal {
        require(idToLock[lockId].end + duration <= MAX_LOCK, "invalid duration");
        require(idToLock[lockId].end < block.timestamp + duration, "invalid duration");
        idToLock[lockId].end = block.timestamp + duration;
    }
   
    function _remove_lock(address account, uint lockId) internal {
        require(block.timestamp > idToLock[lockId].end, "lock has not expired"); 
        require(idToLock[lockId].totalAmountDeposited == idToLock[lockId].amountClaimed, "lock contains vested tokens");
        locksByAccount[account].remove(lockId);
        delete accountByLock[lockId];
    }

    ///////////////////////////////////////////////////////////////////////////

    function _value_of_deposit(Lock storage lock, uint depositIndex, uint at) internal returns (uint) {
        uint untill_expire = ( lock.end - at ) * 1e18;
        uint lock_length = lock.end - lock.deposits[depositIndex].at;
        uint value = ( untill_expire / lock_length ) * lock.deposits[depositIndex].amount; 
        return value / 1e18; 
    }

    function _bias_weight(Lock storage lock, uint at) internal view returns (uint) {
        return ( lock.end - at ) / MAX_LOCK;
    }

    function _decay_rate(Lock storage lock, uint depositIndex) internal returns (uint) {
        return _value_of_deposit(lock, depositIndex, lock.lastModifiedAt) / ( lock.end - lock.lastModifiedAt ) ; 
    }
    
    function _valueOfLock(Lock storage lock, uint at) internal returns (uint) {
        uint valueOfLock = 0;
        for (uint i = 0; i < lock.numberOfDeposits; i++) {
            valueOfLock += _value_of_deposit(lock, i, at); 
        }
        return valueOfLock;
    }

    function _votingPower(Lock storage lock, uint at) internal returns (uint) {
        return _valueOfLock(lock, at) * _bias_weight(lock, at);
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
        return totalVotes;
    }
}
