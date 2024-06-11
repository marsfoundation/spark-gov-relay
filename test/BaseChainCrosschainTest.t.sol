// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { Domain, OptimismDomain } from 'xchain-helpers/testing/OptimismDomain.sol';
import { XChainForwarders }       from 'xchain-helpers/XChainForwarders.sol';

import { AuthBridgeExecutor }             from 'src/executors/AuthBridgeExecutor.sol';
import { BridgeExecutorReceiverOptimism } from 'src/receivers/BridgeExecutorReceiverOptimism.sol';

import { IPayload } from './interfaces/IPayload.sol';

import { CrosschainPayload, CrosschainTestBase } from './CrosschainTestBase.sol';

contract BaseChainCrosschainPayload is CrosschainPayload {

    constructor(IPayload _targetPayload, address _bridgeReceiver)
        CrosschainPayload(_targetPayload, _bridgeReceiver) {}

    function execute() external override {
        XChainForwarders.sendMessageBase(
            bridgeReceiver,
            encodeCrosschainExecutionMessage(),
            1_000_000
        );
    }

}

contract BaseChainCrosschainTest is CrosschainTestBase {

    function deployCrosschainPayload(IPayload targetPayload, address bridgeReceiver)
        public override returns (IPayload)
    {
        return IPayload(new BaseChainCrosschainPayload(targetPayload, bridgeReceiver));
    }

    function setUp() public {
        hostDomain = new Domain(getChain('mainnet'));
        bridgedDomain = new OptimismDomain(getChain('base'), hostDomain);

        bridgedDomain.selectFork();
        bridgeExecutor = new AuthBridgeExecutor(
            defaultL2BridgeExecutorArgs.delay,
            defaultL2BridgeExecutorArgs.gracePeriod,
            defaultL2BridgeExecutorArgs.guardian
        );
        bridgeReceiver = address(new BridgeExecutorReceiverOptimism(
            defaultL2BridgeExecutorArgs.ethereumGovernanceExecutor,
            bridgeExecutor
        ));
        bridgeExecutor.grantRole(bridgeExecutor.AUTHORIZED_BRIDGE_ROLE(), bridgeReceiver);

        hostDomain.selectFork();
    }

}
