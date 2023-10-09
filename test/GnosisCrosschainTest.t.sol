// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { Domain, GnosisDomain } from 'xchain-helpers/GnosisDomain.sol';

import { IAMB, GnosisBridgeExecutor } from '../src/executors/GnosisBridgeExecutor.sol';
import { CrosschainForwarderGnosis }  from '../src/forwarders/CrosschainForwarderGnosis.sol';
import { IL2BridgeExecutor }          from '../src/interfaces/IL2BridgeExecutor.sol';

import { IBaseCrosschainForwarder } from './interfaces/IBaseCrosschainForwarder.sol';
import { IExecutor }                from './interfaces/IExecutor.sol';

import { GnosisReconfigurationPayload } from './mocks/GnosisReconfigurationPayload.sol';

import { CrosschainTestBase } from './CrosschainTestBase.sol';

contract GnosisCrosschainTest is CrosschainTestBase {

    IAMB public constant AMB = IAMB(0x75Df5AF045d91108662D8080fD1FEFAd6aA0bb59);

    bytes32 public constant MAINNET_CHAIN_ID = bytes32(uint256(1));

    function setUp() public {
        hostDomain    = new Domain(getChain('mainnet'));
        bridgedDomain = new GnosisDomain(getChain('gnosis_chain'), hostDomain);

        bridgedDomain.selectFork();
        bridgeExecutor = address(new GnosisBridgeExecutor(
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
        forwarder = address(new CrosschainForwarderGnosis(bridgeExecutor));
    }

    function test_gnosisSpecificSelfReconfiguration() public {
        bridgedDomain.selectFork();

        assertEq(
            address(GnosisBridgeExecutor(bridgeExecutor).amb()),
            address(AMB)
        );
        assertEq(
            GnosisBridgeExecutor(bridgeExecutor).controller(),
            defaultL2BridgeExecutorArgs.ethereumGovernanceExecutor
        );
        assertEq(
            GnosisBridgeExecutor(bridgeExecutor).chainId(),
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
            address(GnosisBridgeExecutor(bridgeExecutor).amb()),
            newAmb
        );
        assertEq(
            GnosisBridgeExecutor(bridgeExecutor).controller(),
            newController
        );
        assertEq(
            GnosisBridgeExecutor(bridgeExecutor).chainId(),
            newChainId
        );
    }

}
