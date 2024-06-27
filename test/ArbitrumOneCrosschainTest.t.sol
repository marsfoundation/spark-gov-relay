// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import './CrosschainTestBase.sol';

import { ArbitrumBridgeTesting } from 'lib/xchain-helpers/src/testing/bridges/ArbitrumBridgeTesting.sol';
import { ArbitrumForwarder }     from 'lib/xchain-helpers/src/forwarders/ArbitrumForwarder.sol';
import { ArbitrumReceiver }      from 'lib/xchain-helpers/src/receivers/ArbitrumReceiver.sol';

import { ArbitrumCrosschainPayload } from './payloads/ArbitrumCrosschainPayload.sol';

contract ArbitrumOneCrosschainTest is CrosschainTestBase {

    using DomainHelpers         for *;
    using ArbitrumBridgeTesting for *;

    function deployCrosschainPayload(IPayload targetPayload, address bridgeReceiver)
        internal override returns (IPayload)
    {
        return IPayload(new ArbitrumCrosschainPayload(ArbitrumForwarder.L1_CROSS_DOMAIN_ARBITRUM_ONE, targetPayload, bridgeReceiver));
    }

    function setupDomain() internal override {
        remote = getChain('arbitrum_one').createFork();
        bridge = ArbitrumBridgeTesting.createNativeBridge(
            mainnet,
            remote
        );

        remote.selectFork();
        bridgeReceiver = address(new ArbitrumReceiver(
            defaultL2BridgeExecutorArgs.ethereumGovernanceExecutor,
            vm.computeCreateAddress(address(this), 3)
        ));

        mainnet.selectFork();
        vm.deal(L1_EXECUTOR, 0.01 ether);
    }

    function relayMessagesAcrossBridge() internal override {
        bridge.relayMessagesToDestination(true);
    }

}
