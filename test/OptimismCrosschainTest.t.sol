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
            L1_EXECUTOR,
            0,
            1_000,
            0,
            1_000,
            address(0)
        ));

        hostDomain.selectFork();
        forwarder = address(new CrosschainForwarderOptimism(bridgeExecutor));
    }
}
