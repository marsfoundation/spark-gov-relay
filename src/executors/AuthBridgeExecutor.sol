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

    bytes32 public constant AUTHORIZED_BRIDGE_ROLE = keccak256('AUTHORIZED_BRIDGE_ROLE');
    
    /**
     * @dev Constructor
     *
     * @param delay The delay before which an actions set can be executed
     * @param gracePeriod The time period after a delay during which an actions set can be executed
     * @param guardian The address of the guardian, which can cancel queued proposals (can be zero)
     */
    constructor(
        uint256 delay,
        uint256 gracePeriod,
        address guardian
    )
        BridgeExecutorBase(
            delay,
            gracePeriod,
            guardian
        )
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(AUTHORIZED_BRIDGE_ROLE, DEFAULT_ADMIN_ROLE);
    }

    /// @inheritdoc IAuthBridgeExecutor
    function queue(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        bool[] memory withDelegatecalls
    ) external onlyRole(AUTHORIZED_BRIDGE_ROLE) {
        _queue(targets, values, signatures, calldatas, withDelegatecalls);
    }
    
}
