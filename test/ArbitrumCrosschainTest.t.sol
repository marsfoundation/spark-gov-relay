// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { Domain, ArbitrumDomain } from 'xchain-helpers/ArbitrumDomain.sol';

import { ArbitrumBridgeExecutor } from '../src/executors/ArbitrumBridgeExecutor.sol';
import { CrosschainForwarderArbitrum } from '../src/forwarders/CrosschainForwarderArbitrum.sol';

import { CrosschainTestBase } from './CrosschainTestBase.sol';

contract ArbitrumCrosschainTest is CrosschainTestBase  {

    function setUp() public {
        hostDomain = new Domain(getChain('mainnet'));
        bridgedDomain = new ArbitrumDomain(getChain('arbitrum_one'), hostDomain);

        bridgedDomain.selectFork();
        bridgeExecutor = address(new ArbitrumBridgeExecutor(
            L1_EXECUTOR,
            0,
            1_000,
            0,
            1_000,
            address(0)
        ));

        hostDomain.selectFork();
        forwarder = address(new CrosschainForwarderArbitrum(bridgeExecutor));
        vm.deal(
            L1_EXECUTOR,
            0.001 ether
        );
    }

    function testArbitrumGasCalculations(uint256 paylodDataLength) public {
        vm.assume(paylodDataLength >= 256);
        vm.assume(paylodDataLength <= 1024);

        hostDomain.selectFork();

        vm.deal(L1_EXECUTOR, 0);
        assertEq(L1_EXECUTOR.balance, 0);
        (bool hasEnoughGasBefore, uint256 requiredGas) = CrosschainForwarderArbitrum(forwarder)
            .hasSufficientGasForExecution(L1_EXECUTOR, paylodDataLength);
        assertEq(hasEnoughGasBefore, false);

        vm.deal(L1_EXECUTOR, requiredGas);
        (bool hasEnoughGasAfter, ) = CrosschainForwarderArbitrum(forwarder)
            .hasSufficientGasForExecution(L1_EXECUTOR, paylodDataLength);
        assertEq(hasEnoughGasAfter, true);
    }
}
