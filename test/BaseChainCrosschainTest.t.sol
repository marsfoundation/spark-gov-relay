// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import './CrosschainTestBase.sol';

import { OptimismBridgeTesting } from 'lib/xchain-helpers/src/testing/bridges/OptimismBridgeTesting.sol';
import { OptimismForwarder }     from 'lib/xchain-helpers/src/forwarders/OptimismForwarder.sol';
import { OptimismReceiver }      from 'lib/xchain-helpers/src/receivers/OptimismReceiver.sol';

contract BaseChainCrosschainPayload is CrosschainPayload {

    constructor(IPayload _targetPayload, address _bridgeReceiver)
        CrosschainPayload(_targetPayload, _bridgeReceiver) {}

    function execute() external override {
        OptimismForwarder.sendMessageL1toL2(
            OptimismForwarder.L1_CROSS_DOMAIN_BASE,
            bridgeReceiver,
            encodeCrosschainExecutionMessage(),
            1_000_000
        );
    }

}

contract BaseChainCrosschainTest is CrosschainTestBase {

    using DomainHelpers         for *;
    using OptimismBridgeTesting for *;

    function deployCrosschainPayload(IPayload targetPayload, address bridgeReceiver)
        public override returns (IPayload)
    {
        return IPayload(new BaseChainCrosschainPayload(targetPayload, bridgeReceiver));
    }

    function setUp() public {
        bridge = OptimismBridgeTesting.createNativeBridge(
            getChain('mainnet').createFork(),
            getChain('base').createFork()
        );

        bridge.destination.selectFork();
        bridgeExecutor = new AuthBridgeExecutor(
            defaultL2BridgeExecutorArgs.delay,
            defaultL2BridgeExecutorArgs.gracePeriod,
            defaultL2BridgeExecutorArgs.guardian
        );
        bridgeReceiver = address(new OptimismReceiver(
            defaultL2BridgeExecutorArgs.ethereumGovernanceExecutor,
            address(bridgeExecutor)
        ));
        bridgeExecutor.grantRole(bridgeExecutor.DEFAULT_ADMIN_ROLE(), bridgeReceiver);

        bridge.source.selectFork();
    }

    function relayMessagesAcrossBridge() internal override {
        bridge.relayMessagesToDestination(true);
    }

}
