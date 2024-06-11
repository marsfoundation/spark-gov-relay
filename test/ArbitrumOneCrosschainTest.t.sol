// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { Domain, ArbitrumDomain } from 'xchain-helpers/testing/ArbitrumDomain.sol';
import { XChainForwarders }       from 'xchain-helpers/XChainForwarders.sol';

import { AuthBridgeExecutor }             from 'src/executors/AuthBridgeExecutor.sol';
import { BridgeExecutorReceiverArbitrum } from 'src/receivers/BridgeExecutorReceiverArbitrum.sol';

import { IPayload } from './interfaces/IPayload.sol';

import { CrosschainPayload, CrosschainTestBase } from './CrosschainTestBase.sol';

contract ArbitrumOneCrosschainPayload is CrosschainPayload {

    constructor(IPayload _targetPayload, address _bridgeReceiver)
        CrosschainPayload(_targetPayload, _bridgeReceiver) {}

    function execute() external override {
        XChainForwarders.sendMessageArbitrumOne(
            bridgeReceiver,
            encodeCrosschainExecutionMessage(),
            1_000_000,
            1 gwei,
            block.basefee + 10 gwei
        );
    }

}

contract ArbitrumOneCrosschainTest is CrosschainTestBase {

    function deployCrosschainPayload(IPayload targetPayload, address bridgeReceiver)
        public override returns (IPayload)
    {
        return IPayload(new ArbitrumOneCrosschainPayload(targetPayload, bridgeReceiver));
    }

    function setUp() public {
        hostDomain = new Domain(getChain('mainnet'));
        bridgedDomain = new ArbitrumDomain(getChain('arbitrum_one'), hostDomain);

        bridgedDomain.selectFork();
        bridgeExecutor = new AuthBridgeExecutor(
            defaultL2BridgeExecutorArgs.delay,
            defaultL2BridgeExecutorArgs.gracePeriod,
            defaultL2BridgeExecutorArgs.guardian
        );
        bridgeReceiver = address(new BridgeExecutorReceiverArbitrum(
            defaultL2BridgeExecutorArgs.ethereumGovernanceExecutor,
            bridgeExecutor
        ));
        bridgeExecutor.grantRole(bridgeExecutor.AUTHORIZED_BRIDGE_ROLE(), bridgeReceiver);

        hostDomain.selectFork();
        vm.deal(L1_EXECUTOR, 0.01 ether);
    }

    function test_constructor_receiver() public {
        BridgeExecutorReceiverArbitrum receiver = new BridgeExecutorReceiverArbitrum(
            defaultL2BridgeExecutorArgs.ethereumGovernanceExecutor,
            bridgeExecutor
        );

        assertEq(receiver.l1Authority(),       defaultL2BridgeExecutorArgs.ethereumGovernanceExecutor);
        assertEq(address(receiver.executor()), address(bridgeExecutor));
    }

}
