// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { OptimismDomain, Domain } from 'xchain-helpers/OptimismDomain.sol';

import { OptimismBridgeExecutor } from '../src/executors/OptimismBridgeExecutor.sol';
import { CrosschainForwarderOptimism } from '../src/forwarders/CrosschainForwarderOptimism.sol';

import { CrosschainTestBase } from './CrosschainTestBase.sol';

contract OptimismCrosschainTest is CrosschainTestBase {
    OptimismDomain public optimism;

    OptimismBridgeExecutor public optimismBridgeExecutor;
    CrosschainForwarderOptimism public optimismForwarder;

    address public constant OVM_L2_CROSS_DOMAIN_MESSENGER = 0x4200000000000000000000000000000000000007;

    function setUp() public {
        mainnet = new Domain(getChain('mainnet'));
        optimism = new OptimismDomain(
            getChain('optimism'),
            mainnet
            );

        optimism.selectFork();
        optimismBridgeExecutor = new OptimismBridgeExecutor(
            OVM_L2_CROSS_DOMAIN_MESSENGER,
            L1_EXECUTOR,
            0,
            1_000,
            0,
            1_000,
            address(0)
        );

        mainnet.selectFork();
        optimismForwarder = new CrosschainForwarderOptimism(address(optimismBridgeExecutor));
    }

    function testOptimismCrossChainPayloadExecution() public {
        checkCrosschainPayloadExecution(
            mainnet,
            optimism,
            address(optimismForwarder),
            address(optimismBridgeExecutor)
        );
    }
}
