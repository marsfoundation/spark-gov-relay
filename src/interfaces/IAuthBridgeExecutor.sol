// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { IAccessControl } from 'lib/openzeppelin-contracts/contracts/access/IAccessControl.sol';

import { IExecutorBase } from './IExecutorBase.sol';

/**
 * @title IAuthBridgeExecutor
 * @notice Defines the basic interface for the AuthBridgeExecutor contract.
 */
interface IAuthBridgeExecutor is IAccessControl, IExecutorBase {

    /**
     * @notice Queue an ActionsSet
     * @dev If a signature is empty, calldata is used for the execution, calldata is appended to signature otherwise
     * @param targets Array of targets to be called by the actions set
     * @param values Array of values to pass in each call by the actions set
     * @param signatures Array of function signatures to encode in each call by the actions (can be empty)
     * @param calldatas Array of calldata to pass in each call by the actions set
     * @param withDelegatecalls Array of whether to delegatecall for each call of the actions set
     **/
    function queue(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        bool[] memory withDelegatecalls
    ) external;
    
}
