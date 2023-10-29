// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { Domain, ArbitrumDomain } from 'xchain-helpers/testing/ArbitrumDomain.sol';
import { XChainForwarders }       from 'xchain-helpers/XChainForwarders.sol';

import { ArbitrumBridgeExecutor } from '../src/executors/ArbitrumBridgeExecutor.sol';

import { IPayload } from './interfaces/IPayload.sol';

import { CrosschainPayload, CrosschainTestBase } from './CrosschainTestBase.sol';

contract ArbitrumCrosschainPayload is CrosschainPayload {
    constructor(IPayload _targetPayload, address _bridgeExecutor)
        CrosschainPayload(_targetPayload, _bridgeExecutor) {}

    function execute() external override {
        XChainForwarders.sendMessageArbitrumOne(
            bridgeExecutor,
            encodeCrosschainExecutionMessage(),
            1_000_000
        );
    }
}

contract ArbitrumCrosschainTest is CrosschainTestBase {
    function deployCrosschainPayload(IPayload targetPayload, address bridgeExecutor)
        public override returns (IPayload)
    {
        return IPayload(new ArbitrumCrosschainPayload(targetPayload, bridgeExecutor));
    }

    function setUp() public {
        hostDomain = new Domain(getChain('mainnet'));
        bridgedDomain = new ArbitrumDomain(getChain('arbitrum_one'), hostDomain);

        bridgedDomain.selectFork();
        bridgeExecutor = address(
            new ArbitrumBridgeExecutor(
                defaultL2BridgeExecutorArgs.ethereumGovernanceExecutor,
                defaultL2BridgeExecutorArgs.delay,
                defaultL2BridgeExecutorArgs.gracePeriod,
                defaultL2BridgeExecutorArgs.minimumDelay,
                defaultL2BridgeExecutorArgs.maximumDelay,
                defaultL2BridgeExecutorArgs.guardian
            )
        );

        hostDomain.selectFork();
        vm.deal(L1_EXECUTOR, 0.01 ether);
    }
}
