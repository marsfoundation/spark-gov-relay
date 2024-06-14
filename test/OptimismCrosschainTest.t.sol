// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import './CrosschainTestBase.sol';

import { OptimismBridgeTesting } from 'lib/xchain-helpers/src/testing/bridges/OptimismBridgeTesting.sol';
import { OptimismForwarder }     from 'lib/xchain-helpers/src/forwarders/OptimismForwarder.sol';
import { OptimismReceiver }      from 'lib/xchain-helpers/src/receivers/OptimismReceiver.sol';

contract OptimismCrosschainPayload is CrosschainPayload {

    constructor(IPayload _targetPayload, address _bridgeReceiver)
        CrosschainPayload(_targetPayload, _bridgeReceiver) {}

    function execute() external override {
        OptimismForwarder.sendMessageL1toL2(
            OptimismForwarder.L1_CROSS_DOMAIN_OPTIMISM,
            bridgeReceiver,
            encodeCrosschainExecutionMessage(),
            1_000_000
        );
    }

}

contract OptimismCrosschainTest is CrosschainTestBase {

    using DomainHelpers         for *;
    using OptimismBridgeTesting for *;

    function deployCrosschainPayload(IPayload targetPayload, address bridgeReceiver)
        public override returns (IPayload)
    {
        return IPayload(new OptimismCrosschainPayload(targetPayload, bridgeReceiver));
    }

    function setUp() public {
        bridge = OptimismBridgeTesting.createNativeBridge(
            getChain('mainnet').createFork(),
            getChain('optimism').createFork()
        );

        bridge.destination.selectFork();
        bridgeExecutor = new Executor(
            defaultL2BridgeExecutorArgs.delay,
            defaultL2BridgeExecutorArgs.gracePeriod
        );
        bridgeReceiver = address(new OptimismReceiver(
            defaultL2BridgeExecutorArgs.ethereumGovernanceExecutor,
            address(bridgeExecutor)
        ));
        bridgeExecutor.grantRole(bridgeExecutor.SUBMISSION_ROLE(),     bridgeReceiver);
        bridgeExecutor.grantRole(bridgeExecutor.GUARDIAN_ROLE(),       defaultL2BridgeExecutorArgs.guardian);
        bridgeExecutor.revokeRole(bridgeExecutor.DEFAULT_ADMIN_ROLE(), address(this));

        bridge.source.selectFork();
    }

    function relayMessagesAcrossBridge() internal override {
        bridge.relayMessagesToDestination(true);
    }

}
