// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { Domain, OptimismDomain } from 'xchain-helpers/testing/OptimismDomain.sol';
import { XChainForwarders }       from 'xchain-helpers/XChainForwarders.sol';

import { AuthBridgeExecutor }             from 'src/executors/AuthBridgeExecutor.sol';
import { BridgeExecutorReceiverOptimism } from 'src/receivers/BridgeExecutorReceiverOptimism.sol';

import { IPayload } from './interfaces/IPayload.sol';

import { CrosschainPayload, CrosschainTestBase } from './CrosschainTestBase.sol';

contract OptimismCrosschainPayload is CrosschainPayload {

    constructor(IPayload _targetPayload, address _bridgeReceiver)
        CrosschainPayload(_targetPayload, _bridgeReceiver) {}

    function execute() external override {
        XChainForwarders.sendMessageOptimismMainnet(
            bridgeReceiver,
            encodeCrosschainExecutionMessage(),
            1_000_000
        );
    }

}

contract OptimismCrosschainTest is CrosschainTestBase {

    function deployCrosschainPayload(IPayload targetPayload, address bridgeReceiver)
        public override returns (IPayload)
    {
        return IPayload(new OptimismCrosschainPayload(targetPayload, bridgeReceiver));
    }

    function setUp() public {
        hostDomain = new Domain(getChain('mainnet'));
        bridgedDomain = new OptimismDomain(getChain('optimism'), hostDomain);

        bridgedDomain.selectFork();
        bridgeExecutor = new AuthBridgeExecutor(
            defaultL2BridgeExecutorArgs.delay,
            defaultL2BridgeExecutorArgs.gracePeriod,
            defaultL2BridgeExecutorArgs.minimumDelay,
            defaultL2BridgeExecutorArgs.maximumDelay,
            defaultL2BridgeExecutorArgs.guardian
        );
        bridgeReceiver = address(new BridgeExecutorReceiverOptimism(
            defaultL2BridgeExecutorArgs.ethereumGovernanceExecutor,
            bridgeExecutor
        ));
        bridgeExecutor.grantRole(bridgeExecutor.AUTHORIZED_BRIDGE_ROLE(), bridgeReceiver);

        hostDomain.selectFork();
    }

    function test_constructor_receiver() public {
        BridgeExecutorReceiverOptimism receiver = new BridgeExecutorReceiverOptimism(
            defaultL2BridgeExecutorArgs.ethereumGovernanceExecutor,
            bridgeExecutor
        );

        assertEq(receiver.l1Authority(),        defaultL2BridgeExecutorArgs.ethereumGovernanceExecutor);
        assertEq(address(receiver.executor()), address(bridgeExecutor));
    }

}
