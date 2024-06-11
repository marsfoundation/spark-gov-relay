// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import './CrosschainTestBase.sol';

import { ArbitrumBridgeTesting } from 'lib/xchain-helpers/src/testing/bridges/ArbitrumBridgeTesting.sol';
import { ArbitrumForwarder }     from 'lib/xchain-helpers/src/forwarders/ArbitrumForwarder.sol';
import { ArbitrumReceiver }      from 'lib/xchain-helpers/src/receivers/ArbitrumReceiver.sol';

contract ArbitrumOneCrosschainPayload is CrosschainPayload {

    constructor(IPayload _targetPayload, address _bridgeReceiver)
        CrosschainPayload(_targetPayload, _bridgeReceiver) {}

    function execute() external override {
        ArbitrumForwarder.sendMessageL1toL2(
            ArbitrumForwarder.L1_CROSS_DOMAIN_ARBITRUM_ONE,
            bridgeReceiver,
            encodeCrosschainExecutionMessage(),
            1_000_000,
            1 gwei,
            block.basefee + 10 gwei
        );
    }

}

contract ArbitrumOneCrosschainTest is CrosschainTestBase {

    using DomainHelpers         for *;
    using ArbitrumBridgeTesting for *;

    function deployCrosschainPayload(IPayload targetPayload, address bridgeReceiver)
        public override returns (IPayload)
    {
        return IPayload(new ArbitrumOneCrosschainPayload(targetPayload, bridgeReceiver));
    }

    function setUp() public {
        bridge = ArbitrumBridgeTesting.createNativeBridge(getChain('mainnet').createFork(), getChain('arbitrum_one').createFork());

        bridge.destination.selectFork();
        bridgeExecutor = new AuthBridgeExecutor(
            defaultL2BridgeExecutorArgs.delay,
            defaultL2BridgeExecutorArgs.gracePeriod,
            defaultL2BridgeExecutorArgs.guardian
        );
        bridgeReceiver = address(new ArbitrumReceiver(
            defaultL2BridgeExecutorArgs.ethereumGovernanceExecutor,
            address(bridgeExecutor)
        ));
        bridgeExecutor.grantRole(bridgeExecutor.DEFAULT_ADMIN_ROLE(), bridgeReceiver);

        bridge.source.selectFork();
        vm.deal(L1_EXECUTOR, 0.01 ether);
    }

    function relayMessagesAcrossBridge() internal override {
        bridge.relayMessagesToDestination(true);
    }

}
