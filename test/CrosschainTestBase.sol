// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { Domain } from 'xchain-helpers/Domain.sol';
import { BridgedDomain } from 'xchain-helpers/BridgedDomain.sol';

import { IL2BridgeExecutor, IExecutorBase } from '../src/interfaces/IL2BridgeExecutor.sol';

import { PayloadWithEmit } from './mocks/PayloadWithEmit.sol';
import { IExecutor } from './interfaces/IExecutor.sol';

interface IBaseCrossschainForwarder {
  function execute(address l2PayloadContract) external;
}

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
    address public constant GUARDIAN       = 0x474E6f886fE829Fd5F289C5B681DdE09ab207076;

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
            IBaseCrossschainForwarder.execute.selector,
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

    function testBasicCrosschainPayloadExecution(uint256 delay) public {
        vm.assume(delay > defaultL2BridgeExecutorArgs.delay);
        vm.assume(delay < (defaultL2BridgeExecutorArgs.delay + defaultL2BridgeExecutorArgs.gracePeriod));

        preparePayloadExecution();

        skip(delay);

        vm.expectEmit(bridgeExecutor);
        emit TestEvent();
        IL2BridgeExecutor(bridgeExecutor).execute(0);
    }

    function testActionExecutionFailsAfterGracePeriod(uint delay) public {
        vm.assume(delay < 10_000_000);
        vm.assume(delay > (defaultL2BridgeExecutorArgs.delay + defaultL2BridgeExecutorArgs.gracePeriod));

        preparePayloadExecution();

        skip(delay);

        vm.expectRevert(IExecutorBase.OnlyQueuedActions.selector);
        IL2BridgeExecutor(bridgeExecutor).execute(0);
    }

    function testActionxecutionFailsBeforeTimelock(uint delay) public {
        vm.assume(delay < defaultL2BridgeExecutorArgs.delay);

        preparePayloadExecution();

        skip(delay);

        vm.expectRevert(IExecutorBase.TimelockNotFinished.selector);
        IL2BridgeExecutor(bridgeExecutor).execute(0);
    }

    function testNonExistentActionExecutionFails() public {
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

    function testOnlyGuardianCanCancel() public {
        address notGuardian = 0x17B23Be942458E6EfC17F000976A490EC428f49A;

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

    function testCanceledActionCannotBeCanceled() public {
        preparePayloadExecution();


        vm.prank(defaultL2BridgeExecutorArgs.guardian);
        IL2BridgeExecutor(bridgeExecutor).cancel(0);

        vm.expectRevert(IExecutorBase.OnlyQueuedActions.selector);
        vm.prank(defaultL2BridgeExecutorArgs.guardian);
        IL2BridgeExecutor(bridgeExecutor).cancel(0);
    }

    function testExecutedActionCannotBeCanceled() public {
        preparePayloadExecution();

        skip(defaultL2BridgeExecutorArgs.delay);

        IL2BridgeExecutor(bridgeExecutor).execute(0);

        vm.expectRevert(IExecutorBase.OnlyQueuedActions.selector);
        vm.prank(defaultL2BridgeExecutorArgs.guardian);
        IL2BridgeExecutor(bridgeExecutor).cancel(0);
    }

    function testExpiredActionCannotBeCanceled() public {
        preparePayloadExecution();

        skip(defaultL2BridgeExecutorArgs.delay + defaultL2BridgeExecutorArgs.gracePeriod + 1);

        vm.expectRevert(IExecutorBase.OnlyQueuedActions.selector);
        vm.prank(defaultL2BridgeExecutorArgs.guardian);
        IL2BridgeExecutor(bridgeExecutor).cancel(0);
    }

    function testCanceledActionCannotBeExecuted() public {
        preparePayloadExecution();

        skip(defaultL2BridgeExecutorArgs.delay);

        vm.prank(defaultL2BridgeExecutorArgs.guardian);
        IL2BridgeExecutor(bridgeExecutor).cancel(0);

        vm.expectRevert(IExecutorBase.OnlyQueuedActions.selector);
        IL2BridgeExecutor(bridgeExecutor).execute(0);
    }
}
