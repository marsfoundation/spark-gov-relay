// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import "forge-std/console.sol";

import { Domain } from 'xchain-helpers/Domain.sol';
import { BridgedDomain } from 'xchain-helpers/BridgedDomain.sol';

import { IL2BridgeExecutor, IExecutorBase } from '../src/interfaces/IL2BridgeExecutor.sol';

import { IBaseCrosschainForwarder } from './interfaces/IBaseCrosschainForwarder.sol';
import { IExecutor }                from './interfaces/IExecutor.sol';

import { PayloadWithEmit }        from './mocks/PayloadWithEmit.sol';
import { ReconfigurationPayload } from './mocks/ReconfigurationPayload.sol';

struct L2BridgeExecutorArguments {
    address ethereumGovernanceExecutor;
    uint256 delay;
    uint256 gracePeriod;
    uint256 minimumDelay;
    uint256 maximumDelay;
    address guardian;
}

abstract contract CrosschainTestBase is Test  {
    event TestEvent();

    address public constant L1_EXECUTOR    = 0x3300f198988e4C9C63F75dF86De36421f06af8c4;
    address public constant L1_PAUSE_PROXY = 0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB;
    address public GUARDIAN                = makeAddr("guardian");

    L2BridgeExecutorArguments public defaultL2BridgeExecutorArgs = L2BridgeExecutorArguments({
        ethereumGovernanceExecutor: L1_EXECUTOR,
        delay:                      600,
        gracePeriod:                1200,
        minimumDelay:               0,
        maximumDelay:               2400,
        guardian:                   GUARDIAN
    });

    Domain public hostDomain;
    BridgedDomain public bridgedDomain;

    address public forwarder;
    address public bridgeExecutor;

    function preparePayloadExecution() public {
        bridgedDomain.selectFork();

        bytes memory encodedPayloadData = abi.encodeWithSelector(
            IBaseCrosschainForwarder.execute.selector,
            address(new PayloadWithEmit())
        );

        hostDomain.selectFork();

        vm.prank(L1_PAUSE_PROXY);
        IExecutor(L1_EXECUTOR).exec(
            forwarder,
            encodedPayloadData
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

        vm.expectEmit(bridgeExecutor);
        emit TestEvent();
        IL2BridgeExecutor(bridgeExecutor).execute(0);
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
        IL2BridgeExecutor(bridgeExecutor).execute(0);
    }

    function testFuzz_actionExecutionFailsBeforeTimelock(uint delay) public {
        delay = bound(
            delay,
            0,
            defaultL2BridgeExecutorArgs.delay - 1
        );

        preparePayloadExecution();

        skip(delay);

        vm.expectRevert(IExecutorBase.TimelockNotFinished.selector);
        IL2BridgeExecutor(bridgeExecutor).execute(0);
    }

    function test_nonExistentActionExecutionFails() public {
        vm.expectRevert();
        IL2BridgeExecutor(bridgeExecutor).execute(0);

        preparePayloadExecution();

        skip(defaultL2BridgeExecutorArgs.delay);

        vm.expectRevert();
        IL2BridgeExecutor(bridgeExecutor).execute(1);

        vm.expectEmit(bridgeExecutor);
        emit TestEvent();
        IL2BridgeExecutor(bridgeExecutor).execute(0);
    }

    function test_onlyGuardianCanCancel() public {
        address notGuardian = makeAddr("notGuardian");

        preparePayloadExecution();

        assertEq(IL2BridgeExecutor(bridgeExecutor).getActionsSetById(0).canceled, false);

        vm.expectRevert();
        vm.prank(notGuardian);
        IL2BridgeExecutor(bridgeExecutor).cancel(0);

        assertEq(IL2BridgeExecutor(bridgeExecutor).getActionsSetById(0).canceled, false);

        vm.prank(defaultL2BridgeExecutorArgs.guardian);
        IL2BridgeExecutor(bridgeExecutor).cancel(0);

        assertEq(IL2BridgeExecutor(bridgeExecutor).getActionsSetById(0).canceled, true);
    }

    function test_canceledActionCannotBeCanceled() public {
        preparePayloadExecution();

        vm.prank(defaultL2BridgeExecutorArgs.guardian);
        IL2BridgeExecutor(bridgeExecutor).cancel(0);

        vm.expectRevert(IExecutorBase.OnlyQueuedActions.selector);
        vm.prank(defaultL2BridgeExecutorArgs.guardian);
        IL2BridgeExecutor(bridgeExecutor).cancel(0);
    }

    function test_executedActionCannotBeCanceled() public {
        preparePayloadExecution();

        skip(defaultL2BridgeExecutorArgs.delay);

        IL2BridgeExecutor(bridgeExecutor).execute(0);

        vm.expectRevert(IExecutorBase.OnlyQueuedActions.selector);
        vm.prank(defaultL2BridgeExecutorArgs.guardian);
        IL2BridgeExecutor(bridgeExecutor).cancel(0);
    }

    function test_expiredActionCannotBeCanceled() public {
        preparePayloadExecution();

        skip(defaultL2BridgeExecutorArgs.delay + defaultL2BridgeExecutorArgs.gracePeriod + 1);

        vm.expectRevert(IExecutorBase.OnlyQueuedActions.selector);
        vm.prank(defaultL2BridgeExecutorArgs.guardian);
        IL2BridgeExecutor(bridgeExecutor).cancel(0);
    }

    function test_canceledActionCannotBeExecuted() public {
        preparePayloadExecution();

        skip(defaultL2BridgeExecutorArgs.delay);

        vm.prank(defaultL2BridgeExecutorArgs.guardian);
        IL2BridgeExecutor(bridgeExecutor).cancel(0);

        vm.expectRevert(IExecutorBase.OnlyQueuedActions.selector);
        IL2BridgeExecutor(bridgeExecutor).execute(0);
    }

    function test_executingMultipleActions() public {
        preparePayloadExecution();
        skip(1);
        preparePayloadExecution();
        skip(1);
        preparePayloadExecution();

        skip(defaultL2BridgeExecutorArgs.delay);

        assertEq(IL2BridgeExecutor(bridgeExecutor).getActionsSetById(0).executed, false);
        assertEq(IL2BridgeExecutor(bridgeExecutor).getActionsSetById(1).executed, false);
        assertEq(IL2BridgeExecutor(bridgeExecutor).getActionsSetById(2).executed, false);

        IL2BridgeExecutor(bridgeExecutor).execute(1);

        assertEq(IL2BridgeExecutor(bridgeExecutor).getActionsSetById(0).executed, false);
        assertEq(IL2BridgeExecutor(bridgeExecutor).getActionsSetById(1).executed, true);
        assertEq(IL2BridgeExecutor(bridgeExecutor).getActionsSetById(2).executed, false);

        IL2BridgeExecutor(bridgeExecutor).execute(2);

        assertEq(IL2BridgeExecutor(bridgeExecutor).getActionsSetById(0).executed, false);
        assertEq(IL2BridgeExecutor(bridgeExecutor).getActionsSetById(1).executed, true);
        assertEq(IL2BridgeExecutor(bridgeExecutor).getActionsSetById(2).executed, true);

        IL2BridgeExecutor(bridgeExecutor).execute(0);

        assertEq(IL2BridgeExecutor(bridgeExecutor).getActionsSetById(0).executed, true);
        assertEq(IL2BridgeExecutor(bridgeExecutor).getActionsSetById(1).executed, true);
        assertEq(IL2BridgeExecutor(bridgeExecutor).getActionsSetById(2).executed, true);
    }

    function test_selfReconfiguration() public {
        bridgedDomain.selectFork();

        assertEq(
            IL2BridgeExecutor(bridgeExecutor).getDelay(),
            defaultL2BridgeExecutorArgs.delay
        );
        assertEq(
            IL2BridgeExecutor(bridgeExecutor).getGracePeriod(),
            defaultL2BridgeExecutorArgs.gracePeriod
        );
        assertEq(
            IL2BridgeExecutor(bridgeExecutor).getMinimumDelay(),
            defaultL2BridgeExecutorArgs.minimumDelay
        );
        assertEq(
            IL2BridgeExecutor(bridgeExecutor).getMaximumDelay(),
            defaultL2BridgeExecutorArgs.maximumDelay
        );
        assertEq(
            IL2BridgeExecutor(bridgeExecutor).getGuardian(),
            defaultL2BridgeExecutorArgs.guardian
        );

        L2BridgeExecutorArguments memory newL2BridgeExecutorParams = L2BridgeExecutorArguments({
            ethereumGovernanceExecutor: defaultL2BridgeExecutorArgs.ethereumGovernanceExecutor,
            delay:                      1200,
            gracePeriod:                1800,
            minimumDelay:               100,
            maximumDelay:               3600,
            guardian:                   makeAddr("newGuardian")
        });

        ReconfigurationPayload reconfigurationPayload = new ReconfigurationPayload(
            newL2BridgeExecutorParams.delay,
            newL2BridgeExecutorParams.gracePeriod,
            newL2BridgeExecutorParams.minimumDelay,
            newL2BridgeExecutorParams.maximumDelay,
            newL2BridgeExecutorParams.guardian
        );

        bytes memory encodedPayloadData = abi.encodeWithSelector(
            IBaseCrosschainForwarder.execute.selector,
            address(reconfigurationPayload)
        );

        hostDomain.selectFork();

        vm.prank(L1_PAUSE_PROXY);
        IExecutor(L1_EXECUTOR).exec(
            forwarder,
            encodedPayloadData
        );

        bridgedDomain.relayFromHost(true);

        skip(defaultL2BridgeExecutorArgs.delay);

        IL2BridgeExecutor(bridgeExecutor).execute(0);

        assertEq(
            IL2BridgeExecutor(bridgeExecutor).getDelay(),
            newL2BridgeExecutorParams.delay
        );
        assertEq(
            IL2BridgeExecutor(bridgeExecutor).getGracePeriod(),
            newL2BridgeExecutorParams.gracePeriod
        );
        assertEq(
            IL2BridgeExecutor(bridgeExecutor).getMinimumDelay(),
            newL2BridgeExecutorParams.minimumDelay
        );
        assertEq(
            IL2BridgeExecutor(bridgeExecutor).getMaximumDelay(),
            newL2BridgeExecutorParams.maximumDelay
        );
        assertEq(
            IL2BridgeExecutor(bridgeExecutor).getGuardian(),
            newL2BridgeExecutorParams.guardian
        );
    }
}
