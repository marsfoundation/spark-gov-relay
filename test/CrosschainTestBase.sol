// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { BridgedDomain } from 'xchain-helpers/testing/BridgedDomain.sol';
import { Domain }        from 'xchain-helpers/testing/Domain.sol';

import { IAuthBridgeExecutor } from 'src/interfaces/IAuthBridgeExecutor.sol';
import { IExecutorBase }       from 'src/interfaces/IExecutorBase.sol';
import { AuthBridgeExecutor }  from 'src/executors/AuthBridgeExecutor.sol';

import { IL1Executor } from './interfaces/IL1Executor.sol';
import { IPayload }    from './interfaces/IPayload.sol';

import { PayloadWithEmit }        from './mocks/PayloadWithEmit.sol';
import { ReconfigurationPayload } from './mocks/ReconfigurationPayload.sol';

struct L2BridgeExecutorArguments {
    address ethereumGovernanceExecutor;
    uint256 delay;
    uint256 gracePeriod;
    address guardian;
}

abstract contract CrosschainPayload is IPayload {

    IPayload immutable targetPayload;
    address immutable bridgeReceiver;

    constructor(IPayload _targetPayload, address _bridgeReceiver) {
        targetPayload  = _targetPayload;
        bridgeReceiver = _bridgeReceiver;
    }

    function execute() external virtual;

    function encodeCrosschainExecutionMessage() internal view returns (bytes memory) {
        address[] memory targets = new address[](1);
        targets[0] = address(targetPayload);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        string[] memory signatures = new string[](1);
        signatures[0] = 'execute()';
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = '';
        bool[] memory withDelegatecalls = new bool[](1);
        withDelegatecalls[0] = true;

        return abi.encodeWithSelector(
            IAuthBridgeExecutor.queue.selector,
            targets,
            values,
            signatures,
            calldatas,
            withDelegatecalls
        );
    }

}

abstract contract CrosschainTestBase is Test {
    event TestEvent();

    address public constant L1_EXECUTOR    = 0x3300f198988e4C9C63F75dF86De36421f06af8c4;
    address public constant L1_PAUSE_PROXY = 0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB;
    address public GUARDIAN                = makeAddr('guardian');

    L2BridgeExecutorArguments public defaultL2BridgeExecutorArgs = L2BridgeExecutorArguments({
        ethereumGovernanceExecutor: L1_EXECUTOR,
        delay:                      600,
        gracePeriod:                1200,
        guardian:                   GUARDIAN
    });

    Domain        public hostDomain;
    BridgedDomain public bridgedDomain;

    AuthBridgeExecutor public bridgeExecutor;
    address            public bridgeReceiver;

    function deployCrosschainPayload(IPayload targetPayload, address bridgeReceiver) public virtual returns (IPayload);

    function preparePayloadExecution() public {
        bridgedDomain.selectFork();

        IPayload targetPayload = IPayload(new PayloadWithEmit());

        hostDomain.selectFork();

        IPayload crosschainPayload = deployCrosschainPayload(
            targetPayload,
            bridgeReceiver
        );

        vm.prank(L1_PAUSE_PROXY);
        IL1Executor(L1_EXECUTOR).exec(
            address(crosschainPayload),
            abi.encodeWithSelector(IPayload.execute.selector)
        );

        bridgedDomain.relayFromHost(true);
    }

    function testFuzz_basicCrosschainPayloadExecution(uint256 delay) public {
        delay = bound(
            delay,
            defaultL2BridgeExecutorArgs.delay,
            defaultL2BridgeExecutorArgs.delay + defaultL2BridgeExecutorArgs.gracePeriod
        );

        preparePayloadExecution();

        skip(delay);

        vm.expectEmit(address(bridgeExecutor));
        emit TestEvent();
        bridgeExecutor.execute(0);
    }

    function testFuzz_actionExecutionFailsAfterGracePeriod(uint delay) public {
        delay = bound(
            delay,
            defaultL2BridgeExecutorArgs.delay + defaultL2BridgeExecutorArgs.gracePeriod + 1,
            10_000_000
        );

        preparePayloadExecution();

        skip(delay);

        vm.expectRevert(IExecutorBase.OnlyQueuedActions.selector);
        bridgeExecutor.execute(0);
    }

    function testFuzz_actionExecutionFailsBeforeTimelock(uint delay) public {
        delay = bound(delay, 0, defaultL2BridgeExecutorArgs.delay - 1);

        preparePayloadExecution();

        skip(delay);

        vm.expectRevert(IExecutorBase.TimelockNotFinished.selector);
        bridgeExecutor.execute(0);
    }

    function test_nonExistentActionExecutionFails() public {
        vm.expectRevert();
        bridgeExecutor.execute(0);

        preparePayloadExecution();

        skip(defaultL2BridgeExecutorArgs.delay);

        vm.expectRevert();
        bridgeExecutor.execute(1);

        vm.expectEmit(address(bridgeExecutor));
        emit TestEvent();
        bridgeExecutor.execute(0);
    }

    function test_onlyGuardianCanCancel() public {
        address notGuardian = makeAddr('notGuardian');

        preparePayloadExecution();

        assertEq(
            bridgeExecutor.getActionsSetById(0).canceled,
            false
        );

        vm.expectRevert();
        vm.prank(notGuardian);
        bridgeExecutor.cancel(0);

        assertEq(
            bridgeExecutor.getActionsSetById(0).canceled,
            false
        );

        vm.prank(defaultL2BridgeExecutorArgs.guardian);
        bridgeExecutor.cancel(0);

        assertEq(
            bridgeExecutor.getActionsSetById(0).canceled,
            true
        );
    }

    function test_canceledActionCannotBeCanceled() public {
        preparePayloadExecution();

        vm.prank(defaultL2BridgeExecutorArgs.guardian);
        bridgeExecutor.cancel(0);

        vm.expectRevert(IExecutorBase.OnlyQueuedActions.selector);
        vm.prank(defaultL2BridgeExecutorArgs.guardian);
        bridgeExecutor.cancel(0);
    }

    function test_executedActionCannotBeCanceled() public {
        preparePayloadExecution();

        skip(defaultL2BridgeExecutorArgs.delay);

        bridgeExecutor.execute(0);

        vm.expectRevert(IExecutorBase.OnlyQueuedActions.selector);
        vm.prank(defaultL2BridgeExecutorArgs.guardian);
        bridgeExecutor.cancel(0);
    }

    function test_expiredActionCannotBeCanceled() public {
        preparePayloadExecution();

        skip(defaultL2BridgeExecutorArgs.delay + defaultL2BridgeExecutorArgs.gracePeriod + 1);

        vm.expectRevert(IExecutorBase.OnlyQueuedActions.selector);
        vm.prank(defaultL2BridgeExecutorArgs.guardian);
        bridgeExecutor.cancel(0);
    }

    function test_canceledActionCannotBeExecuted() public {
        preparePayloadExecution();

        skip(defaultL2BridgeExecutorArgs.delay);

        vm.prank(defaultL2BridgeExecutorArgs.guardian);
        bridgeExecutor.cancel(0);

        vm.expectRevert(IExecutorBase.OnlyQueuedActions.selector);
        bridgeExecutor.execute(0);
    }

    function test_executingMultipleActions() public {
        preparePayloadExecution();
        skip(1);
        preparePayloadExecution();
        skip(1);
        preparePayloadExecution();

        skip(defaultL2BridgeExecutorArgs.delay);

        assertEq(
            bridgeExecutor.getActionsSetById(0).executed,
            false
        );
        assertEq(
            bridgeExecutor.getActionsSetById(1).executed,
            false
        );
        assertEq(
            bridgeExecutor.getActionsSetById(2).executed,
            false
        );

        bridgeExecutor.execute(1);

        assertEq(
            bridgeExecutor.getActionsSetById(0).executed,
            false
        );
        assertEq(
            bridgeExecutor.getActionsSetById(1).executed,
            true
        );
        assertEq(
            bridgeExecutor.getActionsSetById(2).executed,
            false
        );

        bridgeExecutor.execute(2);

        assertEq(
            bridgeExecutor.getActionsSetById(0).executed,
            false
        );
        assertEq(
            bridgeExecutor.getActionsSetById(1).executed,
            true
        );
        assertEq(
            bridgeExecutor.getActionsSetById(2).executed,
            true
        );

        bridgeExecutor.execute(0);

        assertEq(
            bridgeExecutor.getActionsSetById(0).executed,
            true
        );
        assertEq(
            bridgeExecutor.getActionsSetById(1).executed,
            true
        );
        assertEq(
            bridgeExecutor.getActionsSetById(2).executed,
            true
        );
    }

    function test_selfReconfiguration() public {
        bridgedDomain.selectFork();

        assertEq(
            bridgeExecutor.getDelay(),
            defaultL2BridgeExecutorArgs.delay
        );
        assertEq(
            bridgeExecutor.getGracePeriod(),
            defaultL2BridgeExecutorArgs.gracePeriod
        );
        assertEq(
            bridgeExecutor.getGuardian(),
            defaultL2BridgeExecutorArgs.guardian
        );

        L2BridgeExecutorArguments memory newL2BridgeExecutorParams = L2BridgeExecutorArguments({
            ethereumGovernanceExecutor: defaultL2BridgeExecutorArgs.ethereumGovernanceExecutor,
            delay:                      1200,
            gracePeriod:                1800,
            guardian:                   makeAddr('newGuardian')
        });

        IPayload reconfigurationPayload = IPayload(new ReconfigurationPayload(
            newL2BridgeExecutorParams.delay,
            newL2BridgeExecutorParams.gracePeriod,
            newL2BridgeExecutorParams.guardian
        ));

        hostDomain.selectFork();

        IPayload crosschainPayload = deployCrosschainPayload(
            reconfigurationPayload,
            bridgeReceiver
        );

        vm.prank(L1_PAUSE_PROXY);
        IL1Executor(L1_EXECUTOR).exec(
            address(crosschainPayload),
            abi.encodeWithSelector(IPayload.execute.selector)
        );

        bridgedDomain.relayFromHost(true);

        skip(defaultL2BridgeExecutorArgs.delay);

        bridgeExecutor.execute(0);

        assertEq(
            bridgeExecutor.getDelay(),
            newL2BridgeExecutorParams.delay
        );
        assertEq(
            bridgeExecutor.getGracePeriod(),
            newL2BridgeExecutorParams.gracePeriod
        );
        assertEq(
            bridgeExecutor.getGuardian(),
            newL2BridgeExecutorParams.guardian
        );
    }
}
