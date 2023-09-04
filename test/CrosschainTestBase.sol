// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { Domain } from 'xchain-helpers/Domain.sol';
import { BridgedDomain } from 'xchain-helpers/BridgedDomain.sol';

import { IL2BridgeExecutor } from '../src/interfaces/IL2BridgeExecutor.sol';

import { PayloadWithEmit } from './mocks/PayloadWithEmit.sol';
import { IExecutor } from './interfaces/IExecutor.sol';

interface IBaseCrossschainForwarder {
  function execute(address l2PayloadContract) external;
}

abstract contract CrosschainTestBase is Test  {
    event TestEvent();

    address public constant L1_EXECUTOR    = 0x3300f198988e4C9C63F75dF86De36421f06af8c4;
    address public constant L1_PAUSE_PROXY = 0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB;

    Domain public hostDomain;
    BridgedDomain public bridgedDomain;

    address public forwarder;
    address public bridgeExecutor;

    function testSimpleCrosschainPayloadExecution() public {
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

        vm.expectEmit(bridgeExecutor);
        emit TestEvent();
        IL2BridgeExecutor(bridgeExecutor).execute(0);
    }
}
