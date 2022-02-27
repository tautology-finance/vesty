// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import {ERC20Mock} from "solidstate-solidity/token/ERC20/ERC20Mock.sol";
import {VestcrowMock} from "./utils/VestcrowMock.sol";
import {VestcrowUser} from "./utils/VestcrowUser.sol";

interface CheatCodes {
    function warp(uint) external;
}

contract VestcrowTest is DSTest {

    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);


    ERC20Mock mock20;

    VestcrowMock vestcrowMock;

    VestcrowUser alice;
    VestcrowUser bob;
    uint256 constant public MAX_UINT = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    uint256 constant public TWO_YEARS = 3600 * 24 * 365 * 2; 


    function setUp() public {
        mock20 = new ERC20Mock("Mock20", "M20", 18, 0);
    }

    /////////////// IVestcrow ////////////////////////
    function testDeposit() public {
        // sanity checks for requires
        vestcrowMock = new VestcrowMock(address(mock20));
        mock20.__mint(address(this), 1e18);
        mock20.approve(address(vestcrowMock), 1000);
        vestcrowMock.deposit(1000, 1);
    }
    function testFailDepositZeroAmount() public {
        vestcrowMock = new VestcrowMock(address(mock20));
        vestcrowMock.deposit(0, 1);
    }
    function testFailDepositZeroDuration() public {
        vestcrowMock = new VestcrowMock(address(mock20));
        vestcrowMock.deposit(1, 0);
    }
    function testFailDepositDurationTooLarge() public {
        vestcrowMock = new VestcrowMock(address(mock20));
        vestcrowMock.deposit(1, (3600 * 24 * 365 * 2) +1);
    }
    function testFailDepositBlanceGreaterThanHoldings() public {
        vestcrowMock = new VestcrowMock(address(mock20));
        vestcrowMock.deposit(1, 3600 * 24 * 365 * 2);
    }

    function testFailDepositIntoAnothersLock() public {
        vestcrowMock = new VestcrowMock(address(mock20));
        alice = new VestcrowUser(address(vestcrowMock));
        mock20.__mint(address(this), 1e18);
        uint lockId = vestcrowMock.create_lock(address(this));
        alice.addDeposit(0, 1000);
    }

    function testAddDepositExternal() public {
        vestcrowMock = new VestcrowMock(address(mock20));
        mock20.__mint(address(this), 1e18);
        mock20.approve(address(vestcrowMock), 2000);
        uint lockId = vestcrowMock.deposit(1000, 1000);
        vestcrowMock.addDeposit(lockId, 1000);
    }

    function testFailDepositAndExtendedAnothersLock() public {
        vestcrowMock = new VestcrowMock(address(mock20));
        alice = new VestcrowUser(address(vestcrowMock));
        mock20.__mint(address(this), 1e18);
        uint lockId = vestcrowMock.deposit(100, 100);
        alice.depositAndExtend(lockId, 1000, 100);
    }
    function testDepositAndExtend() public {
        vestcrowMock = new VestcrowMock(address(mock20));
        mock20.__mint(address(this), 1e18);
        mock20.approve(address(vestcrowMock), 200);
        uint lockId = vestcrowMock.deposit(100, 100);
        vestcrowMock.depositAndExtend(lockId, 100, 10000);
    }

    function testWithdraw() public {
        // access
        // sanity check
    }

    //////////////////// Internal Lock Mechanics ///////////////////////////

    function testCreateLock() public {
        vestcrowMock = new VestcrowMock(address(mock20));
        uint currentLockId = vestcrowMock.NEXT_LOCK_ID();
        uint lockId = vestcrowMock.create_lock(address(this));
        assertEq(lockId, currentLockId);
        assertEq(currentLockId+1, vestcrowMock.NEXT_LOCK_ID());
        assertTrue(vestcrowMock.LOCKS_BY_ACCOUNT_CONTAINS(address(this), lockId));
        assertEq(vestcrowMock.LOCKS_BY_ACCOUNT_LENGTH(address(this)), 1);
        assertEq(vestcrowMock.ACCOUNT_BY_LOCK(lockId), address(this));
    }

    function testAddDepositInternal() public {
        // numberOfDeposit is incremented
        // deposit amount/at is correct 
        // lock total deposited is updated by amount
        // lock continas new deposit
        vestcrowMock = new VestcrowMock(address(mock20));
        uint amount_0 = 100000;
        uint amount_1 = 1234567890;

        uint lockId = vestcrowMock.create_lock(address(this));

        assertEq(vestcrowMock.LOCK_TOTAL_AMOUNT_DEPOSITED(lockId), 0);
        assertEq(vestcrowMock.LOCK_NUMBER_OF_DEPOSITS(lockId), 0);
        assertEq(vestcrowMock.LOCK_DEPOSITS(lockId, 0).amount, 0);
        assertEq(vestcrowMock.LOCK_DEPOSITS(lockId, 0).at, 0);

        vestcrowMock.add_deposit(lockId, amount_0);
        
        assertEq(vestcrowMock.LOCK_TOTAL_AMOUNT_DEPOSITED(lockId), amount_0);
        assertEq(vestcrowMock.LOCK_NUMBER_OF_DEPOSITS(lockId), 1);
        assertEq(vestcrowMock.LOCK_DEPOSITS(lockId, 0).amount, amount_0);
        assertEq(vestcrowMock.LOCK_DEPOSITS(lockId, 0).at, block.timestamp);

        // cheat to pass time
        cheats.warp(3600 * 24 * 365);

        vestcrowMock.add_deposit(lockId, amount_1);

        assertEq(vestcrowMock.LOCK_TOTAL_AMOUNT_DEPOSITED(lockId), amount_0+amount_1);
        assertEq(vestcrowMock.LOCK_NUMBER_OF_DEPOSITS(lockId), 2);
        assertEq(vestcrowMock.LOCK_DEPOSITS(lockId, 1).amount, amount_1);
        assertEq(vestcrowMock.LOCK_DEPOSITS(lockId, 1).at, block.timestamp);
        
    }
    function testIncreaseDuration() public {
        // lock end is set to block.timstamp + duration
        // lastmodifiedAt + duration = end

        vestcrowMock = new VestcrowMock(address(mock20));
        uint duration = 3600 * 24;

        uint lockId = vestcrowMock.create_lock(address(this));

        assertEq(vestcrowMock.LOCK_LAST_MODIFIED_AT(lockId), 0);
        assertEq(vestcrowMock.LOCK_END(lockId), 0);

        vestcrowMock.set_unlock_time(lockId, duration);

        assertEq(vestcrowMock.LOCK_LAST_MODIFIED_AT(lockId), block.timestamp);
        assertEq(vestcrowMock.LOCK_END(lockId), block.timestamp+duration);

        // cheat to pass time 
        cheats.warp(3600 * 12);

        vestcrowMock.set_unlock_time(lockId, duration);

        assertEq(vestcrowMock.LOCK_LAST_MODIFIED_AT(lockId), block.timestamp);
        assertEq(vestcrowMock.LOCK_END(lockId), block.timestamp+duration);
    }


    function testFailRemoveDepositIdOutOfRange() public {
        vestcrowMock = new VestcrowMock(address(mock20));
        uint lockId = vestcrowMock.create_lock(address(this));
        vestcrowMock.remove_deposit(lockId, 0);
    }

    function testRemoveDeposit() public {
        vestcrowMock = new VestcrowMock(address(mock20));
        uint lockId = vestcrowMock.create_lock(address(this));

        uint[] memory amounts = new uint[](3);
        amounts[0] = 1;
        amounts[1] = 2;
        amounts[2] = 3;

        vestcrowMock.add_deposit(lockId, amounts[0]);
        vestcrowMock.remove_deposit(lockId, 0);
        assertEq(vestcrowMock.LOCK_NUMBER_OF_DEPOSITS(lockId), 0);
        assertEq(vestcrowMock.LOCK_TOTAL_AMOUNT_DEPOSITED(lockId), 0);

        vestcrowMock.add_deposit(lockId, amounts[0]);
        cheats.warp(1);
        vestcrowMock.add_deposit(lockId, amounts[1]);
        vestcrowMock.add_deposit(lockId, amounts[2]);

        vestcrowMock.remove_deposit(lockId, 0);
        assertEq(vestcrowMock.LOCK_NUMBER_OF_DEPOSITS(lockId), 2);
        assertEq(vestcrowMock.LOCK_TOTAL_AMOUNT_DEPOSITED(lockId), amounts[1]+amounts[2]);
        assertEq(vestcrowMock.LOCK_DEPOSITS(lockId, 0).amount, amounts[2]);
        assertEq(vestcrowMock.LOCK_DEPOSITS(lockId, 0).at, 1);
        assertEq(vestcrowMock.LOCK_DEPOSITS(lockId, 1).amount, amounts[1]);
        assertEq(vestcrowMock.LOCK_DEPOSITS(lockId, 1).at, 1);

        vestcrowMock.remove_deposit(lockId, 1);
        assertEq(vestcrowMock.LOCK_NUMBER_OF_DEPOSITS(lockId), 1);
        assertEq(vestcrowMock.LOCK_TOTAL_AMOUNT_DEPOSITED(lockId), amounts[2]);
        assertEq(vestcrowMock.LOCK_DEPOSITS(lockId,0).amount, amounts[2]);
        assertEq(vestcrowMock.LOCK_DEPOSITS(lockId,0).at, 1);
    }

    function testFailRemoveLockWithDeposits() public {
        vestcrowMock = new VestcrowMock(address(mock20));
        uint lockId = vestcrowMock.create_lock(address(this));
        vestcrowMock.add_deposit(lockId, 100000);
        vestcrowMock.remove_lock(address(this), lockId);
    }

    function testRemoveLock() public {
        // locksByAccount does not contain lockId
        // accountByLock contains empty address (unset) 

        vestcrowMock = new VestcrowMock(address(mock20));
        uint lockId = vestcrowMock.create_lock(address(this));
        vestcrowMock.remove_lock(address(this), lockId);

        assertTrue(!vestcrowMock.LOCKS_BY_ACCOUNT_CONTAINS(address(this), lockId));
        assertEq(vestcrowMock.LOCKS_BY_ACCOUNT_LENGTH(address(this)), 0);
        assertEq(vestcrowMock.ACCOUNT_BY_LOCK(lockId), address(0));
    }
    
    /**/
    

    function testValueOfDeposit() public {
    }
    function testBiasWeight() public {
    }
    function testDecayRate() public {
    }
    function testValueOfLock() public {
    }
    function testVotingPower() public {
    }
    function testTotalDeposited() public {
    }
    function testValue() public {
    }
    function testVotes() public {
        vestcrowMock = new VestcrowMock(address(mock20));
        uint balance = TWO_YEARS;
        mock20.__mint(address(this), 2*balance);
        mock20.approve(address(vestcrowMock), 2*balance);
       
        vestcrowMock.deposit(balance, TWO_YEARS);

        emit log_uint(vestcrowMock.value());
        emit log_uint(vestcrowMock.votes());

        cheats.warp(TWO_YEARS/2);

        vestcrowMock.depositAndExtend(0, balance/2, TWO_YEARS);

        emit log_uint(vestcrowMock.value());
        emit log_uint(vestcrowMock.votes());

        cheats.warp(TWO_YEARS);

        emit log_uint(vestcrowMock.value());
        emit log_uint(vestcrowMock.votes());

    }
}
