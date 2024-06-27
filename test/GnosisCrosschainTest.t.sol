// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import './CrosschainTestBase.sol';

import { AMBBridgeTesting } from 'lib/xchain-helpers/src/testing/bridges/AMBBridgeTesting.sol';
import { AMBReceiver }      from 'lib/xchain-helpers/src/receivers/AMBReceiver.sol';

import { GnosisCrosschainPayload } from './payloads/GnosisCrosschainPayload.sol';

contract GnosisCrosschainTest is CrosschainTestBase {

    using DomainHelpers    for *;
    using AMBBridgeTesting for *;

    function deployCrosschainPayload(IPayload targetPayload, address bridgeReceiver)
        internal override returns (IPayload)
    {
        return IPayload(new GnosisCrosschainPayload(targetPayload, bridgeReceiver));
    }

    function setupDomain() internal override {
        remote = getChain('gnosis_chain').createFork();
        bridge = AMBBridgeTesting.createGnosisBridge(
            mainnet,
            remote
        );

        remote.selectFork();
        bridgeReceiver = address(new AMBReceiver(
            AMBBridgeTesting.getGnosisMessengerFromChainAlias(bridge.destination.chain.chainAlias),
            bytes32(uint256(1)),  // Ethereum chainid
            defaultL2BridgeExecutorArgs.ethereumGovernanceExecutor,
            vm.computeCreateAddress(address(this), 2)
        ));
    }

    function relayMessagesAcrossBridge() internal override {
        bridge.relayMessagesToDestination(true);
    }

}
