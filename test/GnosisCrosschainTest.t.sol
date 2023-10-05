// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { Domain, GnosisDomain } from 'xchain-helpers/GnosisDomain.sol';

import { IAMB, AMBBridgeExecutor } from '../src/executors/AMBBridgeExecutor.sol';
import { CrosschainForwarderAMB } from '../src/forwarders/CrosschainForwarderAMB.sol';
import { IL2BridgeExecutor } from '../src/interfaces/IL2BridgeExecutor.sol';

import { GnosisReconfigurationPayload } from './mocks/GnosisReconfigurationPayload.sol';
import { IBaseCrosschainForwarder } from './interfaces/IBaseCrosschainForwarder.sol';
import { IExecutor } from './interfaces/IExecutor.sol';
import { CrosschainTestBase } from './CrosschainTestBase.sol';

contract GnosisCrosschainTest is CrosschainTestBase {

    IAMB public constant AMB = IAMB(0x75Df5AF045d91108662D8080fD1FEFAd6aA0bb59);

    bytes32 public constant MAINNET_CHAIN_ID = bytes32(uint256(1));

    function setUp() public {
        hostDomain = new Domain(getChain('mainnet'));
        bridgedDomain = new GnosisDomain(getChain('gnosis_chain'), hostDomain);

        bridgedDomain.selectFork();
        bridgeExecutor = address(new AMBBridgeExecutor(
            AMB,
            defaultL2BridgeExecutorArgs.ethereumGovernanceExecutor,
            MAINNET_CHAIN_ID,
            defaultL2BridgeExecutorArgs.delay,
            defaultL2BridgeExecutorArgs.gracePeriod,
            defaultL2BridgeExecutorArgs.minimumDelay,
            defaultL2BridgeExecutorArgs.maximumDelay,
            defaultL2BridgeExecutorArgs.guardian
        ));

        hostDomain.selectFork();
        forwarder = address(new CrosschainForwarderAMB(bridgeExecutor));
    }

    function test_gnosisSpecificSelfReconfiguration() public {
        bridgedDomain.selectFork();

        assertEq(
            AMBBridgeExecutor(bridgeExecutor).amb(),
            AMB
        );
        assertEq(
            AMBBridgeExecutor(bridgeExecutor).conotroller(),
            defaultL2BridgeExecutorArgs.ethereumGovernanceExecutor
        );
        assertEq(
            AMBBridgeExecutor(bridgeExecutor).chainId(),
            MAINNET_CHAIN_ID
        );

        address newAmb        = makeAddr("newAMB");
        address newController = makeAddr("newController");

        bytes32 newChainId = bytes32(uint256(2));

        GnosisReconfigurationPayload reconfigurationPayload = new GnosisReconfigurationPayload(
            newAmb,
            newController,
            newChainId
        );

        bytes memory encodedPayloadData = abi.encodeWithSelector(
            IBaseCrosschainForwarder.execute.selector,
            address(reconfigurationPayload)
        );

        hostDomain.selectFork();

        vm.prank(L1_PAUSE_PROXY);
        IExecutor(L1_EXECUTOR).exec(
            forwarder,
            encodedPayloadData
        );

        bridgedDomain.relayFromHost(true);

        skip(defaultL2BridgeExecutorArgs.delay);

        IL2BridgeExecutor(bridgeExecutor).execute(0);

        assertEq(
            AMBBridgeExecutor(bridgeExecutor).amb(),
            newAmb
        );
        assertEq(
            AMBBridgeExecutor(bridgeExecutor).conotroller(),
            newController
        );
        assertEq(
            AMBBridgeExecutor(bridgeExecutor).chainId(),
            newChainId
        );
    }

}
