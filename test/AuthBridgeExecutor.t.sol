// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { AuthBridgeExecutor } from 'src/executors/AuthBridgeExecutor.sol';
import { IExecutorBase }      from 'src/interfaces/IExecutorBase.sol';

contract DefaultPayload {
    event TestEvent();
    function execute() external {
        emit TestEvent();
    }
}

contract PayablePayload {
    event TestEvent();
    function execute() external payable {
        emit TestEvent();
    }
}

contract RevertingPayload {
    function execute() external pure {
        revert("An error occurred");
    }
}

contract AuthBridgeExecutorTest is Test {

    struct Action {
        address[] targets;
        uint256[] values;
        string[]  signatures;
        bytes[]   calldatas;
        bool[]    withDelegatecalls;
    }

    event ActionsSetExecuted(
        uint256 indexed id,
        address indexed initiatorExecution,
        bytes[] returnedData
    );
    event ActionsSetCanceled(uint256 indexed id);
    event GuardianUpdate(address oldGuardian, address newGuardian);
    event DelayUpdate(uint256 oldDelay, uint256 newDelay);
    event GracePeriodUpdate(uint256 oldGracePeriod, uint256 newGracePeriod);
    event TestEvent();

    uint256 constant DELAY        = 1 days;
    uint256 constant GRACE_PERIOD = 30 days;

    address bridge   = makeAddr("bridge");
    address guardian = makeAddr("guardian");

    AuthBridgeExecutor executor;

    function setUp() public {
        executor = new AuthBridgeExecutor({
            delay:        DELAY,
            gracePeriod:  GRACE_PERIOD,
            minimumDelay: 0,         // TODO: removing this in next PR
            maximumDelay: 365 days,  // TODO: removing this in next PR
            guardian:     guardian
        });
        executor.grantRole(executor.AUTHORIZED_BRIDGE_ROLE(), bridge);
        executor.grantRole(executor.DEFAULT_ADMIN_ROLE(),     bridge);
        executor.revokeRole(executor.DEFAULT_ADMIN_ROLE(),    address(this));
    }

    function test_constructor_invalidInitParams() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitParams()"));
        executor = new AuthBridgeExecutor({
            delay:        DELAY,
            gracePeriod:  10 minutes - 1,
            minimumDelay: 0,
            maximumDelay: 365 days,
            guardian:     guardian
        });
    }

    function test_constructor() public {
        executor = new AuthBridgeExecutor({
            delay:        DELAY,
            gracePeriod:  GRACE_PERIOD,
            minimumDelay: 0,
            maximumDelay: 365 days,
            guardian:     guardian
        });

        assertEq(executor.getDelay(),       DELAY);
        assertEq(executor.getGracePeriod(), GRACE_PERIOD);
        assertEq(executor.getGuardian(),    guardian);

        assertEq(executor.hasRole(executor.DEFAULT_ADMIN_ROLE(), address(this)), true);
        assertEq(executor.getRoleAdmin(executor.AUTHORIZED_BRIDGE_ROLE()), executor.DEFAULT_ADMIN_ROLE());
    }

    function test_queue_onlyBridge() public {
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(this), executor.AUTHORIZED_BRIDGE_ROLE()));
        executor.queue(new address[](0), new uint256[](0), new string[](0), new bytes[](0), new bool[](0));
    }

    function test_queue_lengthZero() public {
        vm.expectRevert(abi.encodeWithSignature("EmptyTargets()"));
        vm.prank(bridge);
        executor.queue(new address[](0), new uint256[](0), new string[](0), new bytes[](0), new bool[](0));
    }

    function test_queue_inconsistentParamsLength() public {
        vm.expectRevert(abi.encodeWithSignature("InconsistentParamsLength()"));
        vm.prank(bridge);
        executor.queue(new address[](2), new uint256[](1), new string[](1), new bytes[](1), new bool[](1));

        vm.expectRevert(abi.encodeWithSignature("InconsistentParamsLength()"));
        vm.prank(bridge);
        executor.queue(new address[](1), new uint256[](2), new string[](1), new bytes[](1), new bool[](1));

        vm.expectRevert(abi.encodeWithSignature("InconsistentParamsLength()"));
        vm.prank(bridge);
        executor.queue(new address[](1), new uint256[](1), new string[](2), new bytes[](1), new bool[](1));

        vm.expectRevert(abi.encodeWithSignature("InconsistentParamsLength()"));
        vm.prank(bridge);
        executor.queue(new address[](1), new uint256[](1), new string[](1), new bytes[](2), new bool[](1));

        vm.expectRevert(abi.encodeWithSignature("InconsistentParamsLength()"));
        vm.prank(bridge);
        executor.queue(new address[](1), new uint256[](1), new string[](1), new bytes[](1), new bool[](2));
    }

    function test_queue_duplicateAction() public {
        Action memory action = _getDefaultAction();
        _queueAction(action);

        vm.expectRevert(abi.encodeWithSignature("DuplicateAction()"));
        _queueAction(action);
    }

    function test_queue() public {
        Action memory action = _getDefaultAction();
        bytes32 actionHash1 = _encodeHash(action, block.timestamp + DELAY);
        bytes32 actionHash2 = _encodeHash(action, block.timestamp + DELAY + 1);

        assertEq(executor.getActionsSetCount(),        0);
        assertEq(executor.isActionQueued(actionHash1), false);
        assertEq(executor.isActionQueued(actionHash2), false);

        _queueAction(action);

        assertEq(executor.getActionsSetCount(),        1);
        assertEq(executor.isActionQueued(actionHash1), true);
        assertEq(executor.isActionQueued(actionHash2), false);

        // Can queue up the same action 1 second later
        skip(1);
        _queueAction(action);

        assertEq(executor.getActionsSetCount(),        2);
        assertEq(executor.isActionQueued(actionHash1), true);
        assertEq(executor.isActionQueued(actionHash2), true);
    }

    function test_execute_actionsSetIdTooHigh_boundary() public {
        assertEq(executor.getActionsSetCount(), 0);
        vm.expectRevert(abi.encodeWithSignature("InvalidActionsSetId()"));
        executor.execute(0);

        _queueAction();
        skip(DELAY);

        assertEq(executor.getActionsSetCount(), 1);
        executor.execute(0);
    }

    function test_execute_notQueued_cancelled() public {
        _queueAction();
        vm.prank(guardian);
        executor.cancel(0);
        
        vm.expectRevert(abi.encodeWithSignature("OnlyQueuedActions()"));
        executor.execute(0);
    }

    function test_execute_notQueued_executed() public {
        _queueAction();
        skip(DELAY);

        executor.execute(0);
        
        vm.expectRevert(abi.encodeWithSignature("OnlyQueuedActions()"));
        executor.execute(0);
    }

    function test_execute_notQueued_expired_boundary() public {
        _queueAction();
        skip(DELAY + GRACE_PERIOD + 1);
        
        vm.expectRevert(abi.encodeWithSignature("OnlyQueuedActions()"));
        executor.execute(0);

        vm.warp(block.timestamp - 1);

        executor.execute(0);
    }

    function test_execute_timelock_not_finished_boundary() public {
        _queueAction();
        skip(DELAY - 1);
        
        vm.expectRevert(abi.encodeWithSignature("TimelockNotFinished()"));
        executor.execute(0);

        skip(1);

        executor.execute(0);
    }

    function test_execute_balance_too_low_boundary() public {
        _queueActionWithValue(1 ether);
        skip(DELAY);

        vm.deal(address(executor), 1 ether - 1);
        vm.expectRevert(abi.encodeWithSignature("InsufficientBalance()"));
        executor.execute(0);

        vm.deal(address(executor), 1 ether);

        executor.execute(0);
    }

    function test_execute_evm_error() public {
        // Trigger some evm error like trying to call a non-payable function
        Action memory action = _getDefaultAction();
        action.values[0] = 1 ether;
        _queueAction(action);
        skip(DELAY);
        vm.deal(address(executor), 1 ether);

        vm.expectRevert(abi.encodeWithSignature("FailedActionExecution()"));
        executor.execute(0);
    }

    function test_execute_revert_error() public {
        Action memory action = _getDefaultAction();
        action.targets[0] = address(new RevertingPayload());
        _queueAction(action);
        skip(DELAY);

        // Should return the underlying error message
        vm.expectRevert("An error occurred");
        executor.execute(0);
    }

    function test_execute_delegateCall() public {
        Action memory action = _getDefaultAction();
        bytes32 actionHash = _encodeHash(action, block.timestamp + DELAY);
        _queueAction(action);
        skip(DELAY);

        assertEq(executor.isActionQueued(actionHash),    true);
        assertEq(executor.getActionsSetById(0).executed, false);
        assertEq(uint8(executor.getCurrentState(0)),     uint8(IExecutorBase.ActionsSetState.Queued));

        bytes[] memory returnedData = new bytes[](1);
        returnedData[0] = "";
        vm.expectEmit(address(executor));
        emit TestEvent();
        vm.expectEmit(address(executor));
        emit ActionsSetExecuted(0, address(this), returnedData);
        executor.execute(0);

        assertEq(executor.isActionQueued(actionHash),    false);
        assertEq(executor.getActionsSetById(0).executed, true);
        assertEq(uint8(executor.getCurrentState(0)),     uint8(IExecutorBase.ActionsSetState.Executed));
    }

    function test_execute_call() public {
        Action memory action = _getDefaultAction();
        action.withDelegatecalls[0] = false;
        bytes32 actionHash = _encodeHash(action, block.timestamp + DELAY);
        _queueAction(action);
        skip(DELAY);

        assertEq(executor.isActionQueued(actionHash),    true);
        assertEq(executor.getActionsSetById(0).executed, false);
        assertEq(uint8(executor.getCurrentState(0)),     uint8(IExecutorBase.ActionsSetState.Queued));

        bytes[] memory returnedData = new bytes[](1);
        returnedData[0] = "";
        vm.expectEmit(action.targets[0]);
        emit TestEvent();
        vm.expectEmit(address(executor));
        emit ActionsSetExecuted(0, address(this), returnedData);
        executor.execute(0);

        assertEq(executor.isActionQueued(actionHash),    false);
        assertEq(executor.getActionsSetById(0).executed, true);
        assertEq(uint8(executor.getCurrentState(0)),     uint8(IExecutorBase.ActionsSetState.Executed));
    }

    function test_execute_delegateCallWithCalldata() public {
        Action memory action = _getDefaultAction();
        action.signatures[0] = "";
        action.calldatas[0]  = abi.encodeWithSignature("execute()");
        bytes32 actionHash = _encodeHash(action, block.timestamp + DELAY);
        _queueAction(action);
        skip(DELAY);

        assertEq(executor.isActionQueued(actionHash),    true);
        assertEq(executor.getActionsSetById(0).executed, false);
        assertEq(uint8(executor.getCurrentState(0)),     uint8(IExecutorBase.ActionsSetState.Queued));

        bytes[] memory returnedData = new bytes[](1);
        returnedData[0] = "";
        vm.expectEmit(address(executor));
        emit TestEvent();
        vm.expectEmit(address(executor));
        emit ActionsSetExecuted(0, address(this), returnedData);
        executor.execute(0);

        assertEq(executor.isActionQueued(actionHash),    false);
        assertEq(executor.getActionsSetById(0).executed, true);
        assertEq(uint8(executor.getCurrentState(0)),     uint8(IExecutorBase.ActionsSetState.Executed));
    }

    function test_cancel_notGuardian() public {
        _queueAction();
        skip(DELAY);

        vm.expectRevert(abi.encodeWithSignature("NotGuardian()"));
        executor.cancel(0);
    }

    function test_cancel_actionsSetIdTooHigh_boundary() public {
        assertEq(executor.getActionsSetCount(), 0);
        vm.expectRevert(abi.encodeWithSignature("InvalidActionsSetId()"));
        vm.prank(guardian);
        executor.cancel(0);

        _queueAction();
        skip(DELAY);

        assertEq(executor.getActionsSetCount(), 1);
        vm.prank(guardian);
        executor.cancel(0);
    }

    function test_cancel_notQueued_cancelled() public {
        _queueAction();
        vm.prank(guardian);
        executor.cancel(0);
        
        vm.expectRevert(abi.encodeWithSignature("OnlyQueuedActions()"));
        vm.prank(guardian);
        executor.cancel(0);
    }

    function test_cancel_notQueued_executed() public {
        _queueAction();
        skip(DELAY);

        vm.prank(guardian);
        executor.cancel(0);
        
        vm.expectRevert(abi.encodeWithSignature("OnlyQueuedActions()"));
        vm.prank(guardian);
        executor.cancel(0);
    }

    function test_cancel_notQueued_expired_boundary() public {
        _queueAction();
        skip(DELAY + GRACE_PERIOD + 1);
        
        vm.expectRevert(abi.encodeWithSignature("OnlyQueuedActions()"));
        vm.prank(guardian);
        executor.cancel(0);

        vm.warp(block.timestamp - 1);

        vm.prank(guardian);
        executor.cancel(0);
    }

    function test_cancel() public {
        Action memory action = _getDefaultAction();
        bytes32 actionHash = _encodeHash(action, block.timestamp + DELAY);
        _queueAction(action);

        assertEq(executor.isActionQueued(actionHash),    true);
        assertEq(executor.getActionsSetById(0).canceled, false);
        assertEq(uint8(executor.getCurrentState(0)),     uint8(IExecutorBase.ActionsSetState.Queued));

        vm.expectEmit(address(executor));
        emit ActionsSetCanceled(0);
        vm.prank(guardian);
        executor.cancel(0);

        assertEq(executor.isActionQueued(actionHash),    false);
        assertEq(executor.getActionsSetById(0).canceled, true);
        assertEq(uint8(executor.getCurrentState(0)),     uint8(IExecutorBase.ActionsSetState.Canceled));
    }

    function test_updateGuardian_notSelf() public {
        vm.expectRevert(abi.encodeWithSignature("OnlyCallableByThis()"));
        executor.updateGuardian(guardian);
    }

    function test_updateGuardian() public {
        address newGuardian = makeAddr("newGuardian");

        assertEq(executor.getGuardian(), guardian);

        vm.expectEmit(address(executor));
        emit GuardianUpdate(guardian, newGuardian);
        vm.prank(address(executor));
        executor.updateGuardian(newGuardian);

        assertEq(executor.getGuardian(), newGuardian);
    }

    function test_updateDelay_notSelf() public {
        vm.expectRevert(abi.encodeWithSignature("OnlyCallableByThis()"));
        executor.updateDelay(2 days);
    }

    function test_updateDelay() public {
        assertEq(executor.getDelay(), 1 days);

        vm.expectEmit(address(executor));
        emit DelayUpdate(1 days, 2 days);
        vm.prank(address(executor));
        executor.updateDelay(2 days);

        assertEq(executor.getDelay(), 2 days);
    }

    function test_updateGracePeriod_notSelf() public {
        vm.expectRevert(abi.encodeWithSignature("OnlyCallableByThis()"));
        executor.updateGracePeriod(60 days);
    }

    function test_updateGracePeriod_underMinimum_boundary() public {
        vm.expectRevert(abi.encodeWithSignature("GracePeriodTooShort()"));
        vm.prank(address(executor));
        executor.updateGracePeriod(10 minutes - 1);

        vm.prank(address(executor));
        executor.updateGracePeriod(10 minutes);
    }

    function test_updateGracePeriod() public {
        assertEq(executor.getGracePeriod(), 30 days);

        vm.expectEmit(address(executor));
        emit GracePeriodUpdate(30 days, 60 days);
        vm.prank(address(executor));
        executor.updateGracePeriod(60 days);

        assertEq(executor.getGracePeriod(), 60 days);
    }

    function test_executeDelegateCall_notSelf() public {
        vm.expectRevert(abi.encodeWithSignature("OnlyCallableByThis()"));
        executor.executeDelegateCall(address(0), "");
    }

    function test_executeDelegateCall() public {
        address target = address(new DefaultPayload());

        vm.expectEmit(address(executor));
        emit TestEvent();
        vm.prank(address(executor));
        executor.executeDelegateCall(target, abi.encodeCall(DefaultPayload.execute, ()));
    }

    function test_receiveFunds() public {
        assertEq(address(executor).balance, 0);

        executor.receiveFunds{value:1 ether}();

        assertEq(address(executor).balance, 1 ether);
    }

    function _getDefaultAction() internal returns (Action memory) {
        address[] memory targets = new address[](1);
        targets[0] = address(new DefaultPayload());
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        string[] memory signatures = new string[](1);
        signatures[0] = "execute()";
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";
        bool[] memory withDelegatecalls = new bool[](1);
        withDelegatecalls[0] = true;

        return Action({
            targets:           targets,
            values:            values,
            signatures:        signatures,
            calldatas:         calldatas,
            withDelegatecalls: withDelegatecalls
        });
    }

    function _queueAction(Action memory action) internal {
        vm.prank(bridge);
        executor.queue(
            action.targets,
            action.values,
            action.signatures,
            action.calldatas,
            action.withDelegatecalls
        );
    }

    function _queueAction() internal {
        _queueAction(_getDefaultAction());
    }

    function _queueActionWithValue(uint256 value) internal {
        Action memory action = _getDefaultAction();
        action.targets[0] = address(new PayablePayload());
        action.values[0]  = value;
        _queueAction(action);
    }

    function _encodeHash(Action memory action, uint256 index, uint256 executionTime) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            action.targets[index],
            action.values[index],
            action.signatures[index],
            action.calldatas[index],
            executionTime,
            action.withDelegatecalls[index]
        ));
    }

    function _encodeHash(Action memory action, uint256 executionTime) internal pure returns (bytes32) {
        return _encodeHash(action, 0, executionTime);
    }

}
