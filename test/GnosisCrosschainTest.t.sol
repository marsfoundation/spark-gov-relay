// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import './CrosschainTestBase.sol';

import { AMBBridgeTesting } from 'lib/xchain-helpers/src/testing/bridges/AMBBridgeTesting.sol';
import { AMBForwarder }     from 'lib/xchain-helpers/src/forwarders/AMBForwarder.sol';
import { AMBReceiver }      from 'lib/xchain-helpers/src/receivers/AMBReceiver.sol';

contract GnosisCrosschainPayload is CrosschainPayload {

    constructor(IPayload _targetPayload, address _bridgeReceiver)
        CrosschainPayload(_targetPayload, _bridgeReceiver) {}

    function execute() external override {
        AMBForwarder.sendMessageEthereumToGnosisChain(
            bridgeReceiver,
            abi.encodeCall(AMBReceiver.forward, (encodeCrosschainExecutionMessage())),
            1_000_000
        );
    }

}

contract GnosisCrosschainTest is CrosschainTestBase {

    using DomainHelpers    for *;
    using AMBBridgeTesting for *;

    function deployCrosschainPayload(IPayload targetPayload, address bridgeReceiver)
        public override returns (IPayload)
    {
        return IPayload(new GnosisCrosschainPayload(targetPayload, bridgeReceiver));
    }

    function setUp() public {
        bridge = AMBBridgeTesting.createGnosisBridge(getChain('mainnet').createFork(), getChain('gnosis_chain').createFork());

        bridge.destination.selectFork();
        bridgeExecutor = new AuthBridgeExecutor(
            defaultL2BridgeExecutorArgs.delay,
            defaultL2BridgeExecutorArgs.gracePeriod,
            defaultL2BridgeExecutorArgs.minimumDelay,
            defaultL2BridgeExecutorArgs.maximumDelay,
            defaultL2BridgeExecutorArgs.guardian
        );
        bridgeReceiver = address(new AMBReceiver(
            AMBBridgeTesting.getGnosisMessengerFromChainAlias(bridge.destination.chain.chainAlias),
            bytes32(uint256(1)),  // Ethereum chainid
            defaultL2BridgeExecutorArgs.ethereumGovernanceExecutor,
            address(bridgeExecutor)
        ));
        bridgeExecutor.grantRole(bridgeExecutor.AUTHORIZED_BRIDGE_ROLE(), bridgeReceiver);

        bridge.source.selectFork();
    }

    function relayMessagesAcrossBridge() internal override {
        bridge.relayMessagesToDestination(true);
    }

}
