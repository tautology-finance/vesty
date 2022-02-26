pragma solidity ^0.8.0;

import {IVestcrow} from "./../../interfaces/IVestcrow.sol";

contract VestcrowUser {

    address vestcrow;

    constructor (address _vestcrow) {
        vestcrow = _vestcrow;
    }

    function deposit(uint amount, uint duration) public { 
        IVestcrow(vestcrow).deposit(amount, duration);
    }

    function withdraw() public {
        IVestcrow(vestcrow).withdraw();
    }

    function increaseDuration(uint lockId, uint duration) public {
        IVestcrow(vestcrow).increaseDuration(lockId, duration);
    }

    function addDeposit(uint lockId, uint amount) public {
        IVestcrow(vestcrow).addDeposit(lockId, amount);
    }

    function depositAndExtend(uint lockId, uint amount, uint duration) public {
        IVestcrow(vestcrow).depositAndExtend(lockId, amount, duration);
    }
}
