// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import './CrosschainTestBase.sol';

import { OptimismBridgeTesting } from 'lib/xchain-helpers/src/testing/bridges/OptimismBridgeTesting.sol';
import { OptimismForwarder }     from 'lib/xchain-helpers/src/forwarders/OptimismForwarder.sol';
import { OptimismReceiver }      from 'lib/xchain-helpers/src/receivers/OptimismReceiver.sol';

import { OptimismCrosschainPayload } from './payloads/OptimismCrosschainPayload.sol';

contract BaseChainCrosschainTest is CrosschainTestBase {

    using DomainHelpers         for *;
    using OptimismBridgeTesting for *;

    function deployCrosschainPayload(IPayload targetPayload, address bridgeReceiver)
        internal override returns (IPayload)
    {
        return IPayload(new OptimismCrosschainPayload(OptimismForwarder.L1_CROSS_DOMAIN_OPTIMISM, targetPayload, bridgeReceiver));
    }

    function setupDomain() internal override {
        remote = getChain('optimism').createFork();
        bridge = OptimismBridgeTesting.createNativeBridge(
            mainnet,
            remote
        );

        remote.selectFork();
        bridgeReceiver = address(new OptimismReceiver(
            defaultL2BridgeExecutorArgs.ethereumGovernanceExecutor,
            vm.computeCreateAddress(address(this), 2)
        ));
    }

    function relayMessagesAcrossBridge() internal override {
        bridge.relayMessagesToDestination(true);
    }

}
