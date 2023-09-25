// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { Domain, OptimismDomain } from 'xchain-helpers/OptimismDomain.sol';

import { OptimismBridgeExecutor } from '../src/executors/OptimismBridgeExecutor.sol';
import { CrosschainForwarderOptimism } from '../src/forwarders/CrosschainForwarderOptimism.sol';

import { CrosschainTestBase } from './CrosschainTestBase.sol';

contract OptimismCrosschainTest is CrosschainTestBase {

    address public constant OVM_L2_CROSS_DOMAIN_MESSENGER = 0x4200000000000000000000000000000000000007;

    function setUp() public {
        hostDomain = new Domain(getChain('mainnet'));
        bridgedDomain = new OptimismDomain(getChain('optimism'), hostDomain);

        bridgedDomain.selectFork();
        bridgeExecutor = address(new OptimismBridgeExecutor(
            OVM_L2_CROSS_DOMAIN_MESSENGER,
            defaultL2BridgeExecutorArgs.ethereumGovernanceExecutor,
            defaultL2BridgeExecutorArgs.delay,
            defaultL2BridgeExecutorArgs.gracePeriod,
            defaultL2BridgeExecutorArgs.minimumDelay,
            defaultL2BridgeExecutorArgs.maximumDelay,
            defaultL2BridgeExecutorArgs.guardian
        ));

        hostDomain.selectFork();
        forwarder = address(new CrosschainForwarderOptimism(bridgeExecutor));
    }
}
