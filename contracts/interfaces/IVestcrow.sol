pragma solidity ^0.8.0;

interface IVestcrow {

    function deposit(uint amount, uint duration) external; 
    function depositAndExtend(uint lockId, uint amount, uint duration) external;
    function addDeposit(uint lockId, uint amount) external; 
    function increaseDuration(uint lockId, uint duration) external;
    function withdraw() external;

}
