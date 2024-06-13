// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import { Address }       from "openzeppelin-contracts/contracts/utils/Address.sol";

import { IExecutor } from './interfaces/IExecutor.sol';

/**
 * @title Executor
 * @author Aave
 * @notice Executor which queues up message calls and executes them after an optional delay
 */
contract Executor is IExecutor, AccessControl {

    using Address for address;

    // Minimum allowed grace period, which reduces the risk of having an actions set expire due to network congestion
    uint256 constant MINIMUM_GRACE_PERIOD = 10 minutes;

    // Time between queuing and execution
    uint256 private _delay;
    // Time after the execution time during which the actions set can be executed
    uint256 private _gracePeriod;
    // Address with the ability of canceling actions sets
    address private _guardian;

    // Number of actions sets
    uint256 private _actionsSetCounter;
    // Map of registered actions sets (id => ActionsSet)
    mapping(uint256 => ActionsSet) private _actionsSets;
    // Map of queued actions (actionHash => isQueued)
    mapping(bytes32 => bool) private _queuedActions;

    /**
    * @dev Only guardian can call functions marked by this modifier.
    **/
    modifier onlyGuardian() {
        if (msg.sender != _guardian) revert NotGuardian();
        _;
    }

    /**
    * @dev Only this contract can call functions marked by this modifier.
    **/
    modifier onlyThis() {
        if (msg.sender != address(this)) revert OnlyCallableByThis();
        _;
    }

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
    ) {
        if (
            gracePeriod < MINIMUM_GRACE_PERIOD
        ) revert InvalidInitParams();

        _updateDelay(delay);
        _updateGracePeriod(gracePeriod);
        _updateGuardian(guardian);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /// @inheritdoc IExecutor
    function queue(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        bool[] memory withDelegatecalls
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (targets.length == 0) revert EmptyTargets();
        uint256 targetsLength = targets.length;
        if (
            targetsLength != values.length ||
            targetsLength != signatures.length ||
            targetsLength != calldatas.length ||
            targetsLength != withDelegatecalls.length
        ) revert InconsistentParamsLength();

        uint256 actionsSetId = _actionsSetCounter;
        uint256 executionTime = block.timestamp + _delay;
        unchecked {
            ++_actionsSetCounter;
        }

        for (uint256 i = 0; i < targetsLength; ) {
            bytes32 actionHash = keccak256(
                abi.encode(
                    targets[i],
                    values[i],
                    signatures[i],
                    calldatas[i],
                    executionTime,
                    withDelegatecalls[i]
                )
            );
            if (isActionQueued(actionHash)) revert DuplicateAction();
            _queuedActions[actionHash] = true;
            unchecked {
                ++i;
            }
        }

        ActionsSet storage actionsSet = _actionsSets[actionsSetId];
        actionsSet.targets = targets;
        actionsSet.values = values;
        actionsSet.signatures = signatures;
        actionsSet.calldatas = calldatas;
        actionsSet.withDelegatecalls = withDelegatecalls;
        actionsSet.executionTime = executionTime;

        emit ActionsSetQueued(
            actionsSetId,
            targets,
            values,
            signatures,
            calldatas,
            withDelegatecalls,
            executionTime
        );
    }

    /// @inheritdoc IExecutor
    function execute(uint256 actionsSetId) external payable override {
        if (getCurrentState(actionsSetId) != ActionsSetState.Queued) revert OnlyQueuedActions();

        ActionsSet storage actionsSet = _actionsSets[actionsSetId];
        if (block.timestamp < actionsSet.executionTime) revert TimelockNotFinished();

        actionsSet.executed = true;
        uint256 actionCount = actionsSet.targets.length;

        bytes[] memory returnedData = new bytes[](actionCount);
        for (uint256 i = 0; i < actionCount; ) {
            returnedData[i] = _executeTransaction(
                actionsSet.targets[i],
                actionsSet.values[i],
                actionsSet.signatures[i],
                actionsSet.calldatas[i],
                actionsSet.executionTime,
                actionsSet.withDelegatecalls[i]
            );
            unchecked {
                ++i;
            }
        }

        emit ActionsSetExecuted(actionsSetId, msg.sender, returnedData);
    }

    /// @inheritdoc IExecutor
    function cancel(uint256 actionsSetId) external override onlyGuardian {
        if (getCurrentState(actionsSetId) != ActionsSetState.Queued) revert OnlyQueuedActions();

        ActionsSet storage actionsSet = _actionsSets[actionsSetId];
        actionsSet.canceled = true;

        uint256 targetsLength = actionsSet.targets.length;
        for (uint256 i = 0; i < targetsLength; ) {
            _cancelTransaction(
                actionsSet.targets[i],
                actionsSet.values[i],
                actionsSet.signatures[i],
                actionsSet.calldatas[i],
                actionsSet.executionTime,
                actionsSet.withDelegatecalls[i]
            );
            unchecked {
                ++i;
            }
        }

        emit ActionsSetCanceled(actionsSetId);
    }

    /// @inheritdoc IExecutor
    function updateGuardian(address guardian) external override onlyThis {
        _updateGuardian(guardian);
    }

    /// @inheritdoc IExecutor
    function updateDelay(uint256 delay) external override onlyThis {
        _updateDelay(delay);
    }

    /// @inheritdoc IExecutor
    function updateGracePeriod(uint256 gracePeriod) external override onlyThis {
        if (gracePeriod < MINIMUM_GRACE_PERIOD) revert GracePeriodTooShort();
        _updateGracePeriod(gracePeriod);
    }

    /// @inheritdoc IExecutor
    function executeDelegateCall(address target, bytes calldata data)
        external
        payable
        override
        onlyThis
        returns (bytes memory)
    {
        return target.functionDelegateCall(data);
    }

    /// @inheritdoc IExecutor
    function receiveFunds() external payable override {}

    /// @inheritdoc IExecutor
    function getDelay() external view override returns (uint256) {
        return _delay;
    }

    /// @inheritdoc IExecutor
    function getGracePeriod() external view override returns (uint256) {
        return _gracePeriod;
    }

    /// @inheritdoc IExecutor
    function getGuardian() external view override returns (address) {
        return _guardian;
    }

    /// @inheritdoc IExecutor
    function getActionsSetCount() external view override returns (uint256) {
        return _actionsSetCounter;
    }

    /// @inheritdoc IExecutor
    function getActionsSetById(uint256 actionsSetId)
        external
        view
        override
        returns (ActionsSet memory)
    {
        return _actionsSets[actionsSetId];
    }

    /// @inheritdoc IExecutor
    function getCurrentState(uint256 actionsSetId) public view override returns (ActionsSetState) {
        if (_actionsSetCounter <= actionsSetId) revert InvalidActionsSetId();
        ActionsSet storage actionsSet = _actionsSets[actionsSetId];
        if (actionsSet.canceled) {
            return ActionsSetState.Canceled;
        } else if (actionsSet.executed) {
            return ActionsSetState.Executed;
        } else if (block.timestamp > actionsSet.executionTime + _gracePeriod) {
            return ActionsSetState.Expired;
        } else {
            return ActionsSetState.Queued;
        }
    }

    /// @inheritdoc IExecutor
    function isActionQueued(bytes32 actionHash) public view override returns (bool) {
        return _queuedActions[actionHash];
    }

    function _updateGuardian(address guardian) internal {
        emit GuardianUpdate(_guardian, guardian);
        _guardian = guardian;
    }

    function _updateDelay(uint256 delay) internal {
        emit DelayUpdate(_delay, delay);
        _delay = delay;
    }

    function _updateGracePeriod(uint256 gracePeriod) internal {
        emit GracePeriodUpdate(_gracePeriod, gracePeriod);
        _gracePeriod = gracePeriod;
    }

    function _executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 executionTime,
        bool withDelegatecall
    ) internal returns (bytes memory) {
        if (address(this).balance < value) revert InsufficientBalance();

        bytes32 actionHash = keccak256(
            abi.encode(target, value, signature, data, executionTime, withDelegatecall)
        );
        _queuedActions[actionHash] = false;

        bytes memory callData;
        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        if (withDelegatecall) {
            return this.executeDelegateCall{value: value}(target, callData);
        } else {
            return target.functionCallWithValue(callData, value);
        }
    }

    function _cancelTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 executionTime,
        bool withDelegatecall
    ) internal {
        bytes32 actionHash = keccak256(
            abi.encode(target, value, signature, data, executionTime, withDelegatecall)
        );
        _queuedActions[actionHash] = false;
    }

}
