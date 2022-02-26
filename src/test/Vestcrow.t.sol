// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import {ERC20Mock} from "solidstate-solidity/token/ERC20/ERC20Mock.sol";
import {VestcrowMock} from "./utils/VestcrowMock.sol";
import {VestcrowUser} from "./utils/VestcrowUser.sol";

contract VestcrowTest is DSTest {

    ERC20Mock mock20;

    VestcrowMock vestcrowMock;

    VestcrowUser alice;
    VestcrowUser bob;

    function setUp() public {
        mock20 = new ERC20Mock("Mock20", "M20", 18, 1000000000000000);
        mock20.__mint(address(this), 1e18);
    }

    function testCreateLock() public {
        vestcrowMock = new VestcrowMock(address(mock20));

        assertTrue(!vestcrowMock.LOCKS_BY_ACCOUNT_CONTAINS(address(this), 0));
        assertTrue(!vestcrowMock.LOCKS_BY_ACCOUNT_CONTAINS(address(this), 1));

        uint lock_0 = vestcrowMock.create_lock(address(this), 1000000000);
        assertTrue(vestcrowMock.LOCKS_BY_ACCOUNT_CONTAINS(address(this), 0));
        assertEq(vestcrowMock.LOCKS_BY_ACCOUNT_LENGTH(address(this)), 1);

        uint lockDuration = vestcrowMock.LOCK_END(0) - vestcrowMock.LOCK_LAST_MODIFIED_AT(0); 
        assertEq(lockDuration, 1000000000);

        assertEq(lock_0, 0);
        assertTrue(!vestcrowMock.LOCKS_BY_ACCOUNT_CONTAINS(address(this), 1));
        uint lock_1 = vestcrowMock.create_lock(address(this), 1000000000);
        assertEq(vestcrowMock.LOCKS_BY_ACCOUNT_LENGTH(address(this)), 2);
        assertTrue(vestcrowMock.LOCKS_BY_ACCOUNT_CONTAINS(address(this), 1));

        lockDuration = vestcrowMock.LOCK_END(1) - vestcrowMock.LOCK_LAST_MODIFIED_AT(1); 
        assertEq(lockDuration, 1000000000);

        assertEq(lock_1, 1);
        assertEq(vestcrowMock.NEXT_LOCK_ID(), 2);
    }

    /*
    function testRemoveLock() public {}
    function testAddDeposit() public {}
    function testDeposit() public {}
    function testIncreaseDuration() public {}
    function testValueOfDeposit() public {}
    function testBiasWeight() public {}
    function testDecayRate() public {}
    function testValueOfLock() public {}
    function testVotingPower() public {}
    function testTotalDeposited() public {}
    function testValue() public {}
    function testVotes() public {}
    function testWithdraw() public {}
    */
}
