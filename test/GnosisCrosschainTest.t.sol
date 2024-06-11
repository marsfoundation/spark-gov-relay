// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { Domain, GnosisDomain } from 'xchain-helpers/testing/GnosisDomain.sol';
import { XChainForwarders }     from 'xchain-helpers/XChainForwarders.sol';

import { AuthBridgeExecutor }           from 'src/executors/AuthBridgeExecutor.sol';
import { BridgeExecutorReceiverGnosis } from 'src/receivers/BridgeExecutorReceiverGnosis.sol';

import { IPayload } from './interfaces/IPayload.sol';

import { CrosschainPayload, CrosschainTestBase } from './CrosschainTestBase.sol';

contract GnosisCrosschainPayload is CrosschainPayload {

    constructor(IPayload _targetPayload, address _bridgeReceiver)
        CrosschainPayload(_targetPayload, _bridgeReceiver) {}

    function execute() external override {
        XChainForwarders.sendMessageGnosis(
            bridgeReceiver,
            encodeCrosschainExecutionMessage(),
            1_000_000
        );
    }

}

contract GnosisCrosschainTest is CrosschainTestBase {

    address constant AMB = 0x75Df5AF045d91108662D8080fD1FEFAd6aA0bb59;

    function deployCrosschainPayload(IPayload targetPayload, address bridgeReceiver)
        public override returns (IPayload)
    {
        return IPayload(new GnosisCrosschainPayload(targetPayload, bridgeReceiver));
    }

    function setUp() public {
        hostDomain = new Domain(getChain('mainnet'));
        bridgedDomain = new GnosisDomain(getChain('gnosis_chain'), hostDomain);

        bridgedDomain.selectFork();
        bridgeExecutor = new AuthBridgeExecutor(
            defaultL2BridgeExecutorArgs.delay,
            defaultL2BridgeExecutorArgs.gracePeriod,
            defaultL2BridgeExecutorArgs.guardian
        );
        bridgeReceiver = address(new BridgeExecutorReceiverGnosis(
            AMB,
            1,  // Ethereum chainid
            defaultL2BridgeExecutorArgs.ethereumGovernanceExecutor,
            bridgeExecutor
        ));
        bridgeExecutor.grantRole(bridgeExecutor.DEFAULT_ADMIN_ROLE(), bridgeReceiver);

        hostDomain.selectFork();
    }

    function test_constructor_receiver() public {
        BridgeExecutorReceiverGnosis receiver = new BridgeExecutorReceiverGnosis(
            AMB,
            1,
            defaultL2BridgeExecutorArgs.ethereumGovernanceExecutor,
            bridgeExecutor
        );

        assertEq(address(receiver.l2CrossDomain()), AMB);
        assertEq(receiver.chainId(),                bytes32(uint256(1)));
        assertEq(receiver.l1Authority(),            defaultL2BridgeExecutorArgs.ethereumGovernanceExecutor);
        assertEq(address(receiver.executor()),      address(bridgeExecutor));
    }

}
