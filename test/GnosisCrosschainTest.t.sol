// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { Domain, GnosisDomain } from 'xchain-helpers/GnosisDomain.sol';

import { IAMB, AMBBridgeExecutor } from '../src/executors/AMBBridgeExecutor.sol';
import { CrosschainForwarderAMB } from '../src/forwarders/CrosschainForwarderAMB.sol';

import { CrosschainTestBase } from './CrosschainTestBase.sol';

contract GnosisCrosschainTest is CrosschainTestBase {

    IAMB public constant AMB = IAMB(0x75Df5AF045d91108662D8080fD1FEFAd6aA0bb59);

    bytes32 public constant MAINNET_CHAIN_ID = bytes32(0x0000000000000000000000000000000000000000000000000000000000000001);

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
}
