// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { AccessControl } from 'lib/openzeppelin-contracts/contracts/access/AccessControl.sol';

import { IAuthBridgeExecutor } from 'src/interfaces/IAuthBridgeExecutor.sol';
import { BridgeExecutorBase }  from './BridgeExecutorBase.sol';

/**
 * @title AuthBridgeExecutor
 * @notice Queue up proposals from an authorized bridge.
 */
contract AuthBridgeExecutor is IAuthBridgeExecutor, AccessControl, BridgeExecutorBase {
    
    /**
     * @dev Constructor
     *
     * @param delay The delay before which an actions set can be executed
     * @param gracePeriod The time period after a delay during which an actions set can be executed
     * @param minimumDelay The minimum bound a delay can be set to
     * @param maximumDelay The maximum bound a delay can be set to
     * @param guardian The address of the guardian, which can cancel queued proposals (can be zero)
     */
    constructor(
        uint256 delay,
        uint256 gracePeriod,
        uint256 minimumDelay,
        uint256 maximumDelay,
        address guardian
    )
        BridgeExecutorBase(
            delay,
            gracePeriod,
            minimumDelay,
            maximumDelay,
            guardian
        )
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /// @inheritdoc IAuthBridgeExecutor
    function queue(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        bool[] memory withDelegatecalls
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _queue(targets, values, signatures, calldatas, withDelegatecalls);
    }
    
}
