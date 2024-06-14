// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.22;

import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import { Address }       from "openzeppelin-contracts/contracts/utils/Address.sol";

import { IExecutor } from './interfaces/IExecutor.sol';

/**
 * @title  Executor
 * @author Aave
 * @notice Executor which queues up message calls and executes them after an optional delay
 */
contract Executor is IExecutor, AccessControl {

    using Address for address;

    /******************************************************************************************************************/
    /*** State variables and constructor                                                                            ***/
    /******************************************************************************************************************/

    bytes32 public constant SUBMISSION_ROLE = keccak256('SUBMISSION_ROLE');
    bytes32 public constant GUARDIAN_ROLE   = keccak256('GUARDIAN_ROLE');

    uint256 public constant MINIMUM_GRACE_PERIOD = 10 minutes;

    // Map of registered actions sets (id => ActionsSet)
    mapping(uint256 => ActionsSet) private _actionsSets;

    uint256 public override actionsSetCount;  // Number of actions sets
    uint256 public override delay;            // Time between queuing and execution
    uint256 public override gracePeriod;      // Time after delay during which an actions set can be executed

    mapping(bytes32 => bool) public override isActionQueued;

    /**
    *  @dev   Constructor
    *  @param delay_       The delay before which an actions set can be executed.
    *  @param gracePeriod_ The time period after a delay during which an actions set can be executed.
    */
    constructor(
        uint256 delay_,
        uint256 gracePeriod_
    ) {
        if (
            gracePeriod_ < MINIMUM_GRACE_PERIOD
        ) revert InvalidInitParams();

        _updateDelay(delay_);
        _updateGracePeriod(gracePeriod_);

        _setRoleAdmin(SUBMISSION_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(GUARDIAN_ROLE,   DEFAULT_ADMIN_ROLE);

        // Necessary for self-referential calls to change configuration
        _grantRole(DEFAULT_ADMIN_ROLE, address(this));
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /******************************************************************************************************************/
    /*** ActionSet functions                                                                                        ***/
    /******************************************************************************************************************/

    /// @inheritdoc IExecutor
    function queue(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        bool[] memory withDelegatecalls
    ) external override onlyRole(SUBMISSION_ROLE) {
        if (targets.length == 0) revert EmptyTargets();

        uint256 targetsLength = targets.length;
        if (
            targetsLength != values.length     ||
            targetsLength != signatures.length ||
            targetsLength != calldatas.length  ||
            targetsLength != withDelegatecalls.length
        ) revert InconsistentParamsLength();

        uint256 actionsSetId  = actionsSetCount;
        uint256 executionTime = block.timestamp + delay;

        unchecked { ++actionsSetCount; }

        for (uint256 i = 0; i < targetsLength; ++i) {
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
            if (isActionQueued[actionHash]) revert DuplicateAction();

            isActionQueued[actionHash] = true;
        }

        ActionsSet storage actionsSet = _actionsSets[actionsSetId];

        actionsSet.targets           = targets;
        actionsSet.values            = values;
        actionsSet.signatures        = signatures;
        actionsSet.calldatas         = calldatas;
        actionsSet.withDelegatecalls = withDelegatecalls;
        actionsSet.executionTime     = executionTime;

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
        for (uint256 i = 0; i < actionCount; ++i) {
            returnedData[i] = _executeTransaction(
                actionsSet.targets[i],
                actionsSet.values[i],
                actionsSet.signatures[i],
                actionsSet.calldatas[i],
                actionsSet.executionTime,
                actionsSet.withDelegatecalls[i]
            );
        }

        emit ActionsSetExecuted(actionsSetId, msg.sender, returnedData);
    }

    /// @inheritdoc IExecutor
    function cancel(uint256 actionsSetId) external override onlyRole(GUARDIAN_ROLE) {
        if (getCurrentState(actionsSetId) != ActionsSetState.Queued) revert OnlyQueuedActions();

        ActionsSet storage actionsSet =_actionsSets[actionsSetId];
        actionsSet.canceled = true;

        uint256 targetsLength = actionsSet.targets.length;
        for (uint256 i = 0; i < targetsLength; ++i) {
            _removeActionFromQueue(
                actionsSet.targets[i],
                actionsSet.values[i],
                actionsSet.signatures[i],
                actionsSet.calldatas[i],
                actionsSet.executionTime,
                actionsSet.withDelegatecalls[i]
            );
        }

        emit ActionsSetCanceled(actionsSetId);
    }

    /******************************************************************************************************************/
    /*** Admin functions                                                                                            ***/
    /******************************************************************************************************************/

    /// @inheritdoc IExecutor
    function updateDelay(uint256 newDelay) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _updateDelay(newDelay);
    }

    /// @inheritdoc IExecutor
    function updateGracePeriod(uint256 newGracePeriod)
        external override onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (newGracePeriod < MINIMUM_GRACE_PERIOD) revert GracePeriodTooShort();
        _updateGracePeriod(newGracePeriod);
    }

    /******************************************************************************************************************/
    /*** External misc functions                                                                                    ***/
    /******************************************************************************************************************/

    /// @inheritdoc IExecutor
    function executeDelegateCall(address target, bytes calldata data)
        external
        payable
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (bytes memory)
    {
        return target.functionDelegateCall(data);
    }

    /// @inheritdoc IExecutor
    function receiveFunds() external payable override {}

    /******************************************************************************************************************/
    /*** External view functions                                                                                    ***/
    /******************************************************************************************************************/

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
        if (actionsSetCount <= actionsSetId) revert InvalidActionsSetId();

        ActionsSet storage actionsSet =_actionsSets[actionsSetId];

        if      (actionsSet.canceled) return ActionsSetState.Canceled;
        else if (actionsSet.executed) return ActionsSetState.Executed;
        else if (block.timestamp > actionsSet.executionTime + gracePeriod) return ActionsSetState.Expired;
        else return ActionsSetState.Queued;
    }

    /******************************************************************************************************************/
    /*** Internal ActionSet helper functions                                                                        ***/
    /******************************************************************************************************************/

    function _executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 executionTime,
        bool withDelegatecall
    ) internal returns (bytes memory) {
        if (address(this).balance < value) revert InsufficientBalance();

        _removeActionFromQueue(target, value, signature, data, executionTime, withDelegatecall);

        bytes memory callData = bytes(signature).length == 0
            ? data
            : abi.encodePacked(bytes4(keccak256(bytes(signature))), data);

        if (withDelegatecall) return this.executeDelegateCall{value: value}(target, callData);

        return target.functionCallWithValue(callData, value);
    }

    function _removeActionFromQueue(
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
        isActionQueued[actionHash] = false;
    }

    /******************************************************************************************************************/
    /*** Internal admin helper functions                                                                            ***/
    /******************************************************************************************************************/

    function _updateDelay(uint256 newDelay) internal {
        emit DelayUpdate(delay, newDelay);
        delay = newDelay;
    }

    function _updateGracePeriod(uint256 newGracePeriod) internal {
        emit GracePeriodUpdate(gracePeriod, newGracePeriod);
        gracePeriod = newGracePeriod;
    }

}
