// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { ArbitrumDomain, Domain } from 'xchain-helpers/ArbitrumDomain.sol';

import { ArbitrumBridgeExecutor } from '../src/executors/ArbitrumBridgeExecutor.sol';
import { CrosschainForwarderArbitrum } from '../src/forwarders/CrosschainForwarderArbitrum.sol';

import { CrosschainTestBase } from './CrosschainTestBase.sol';

contract ArbitrumCrosschainTest is CrosschainTestBase  {
    ArbitrumDomain public arbitrum;

    ArbitrumBridgeExecutor public arbitrumBridgeExecutor;
    CrosschainForwarderArbitrum public arbitrumForwarder;

    function setUp() public {
        mainnet = new Domain(getChain('mainnet'));
        arbitrum = new ArbitrumDomain(
            getChain('arbitrum_one'),
            mainnet
        );

        arbitrum.selectFork();
        arbitrumBridgeExecutor = new ArbitrumBridgeExecutor(
            L1_EXECUTOR,
            0,
            1_000,
            0,
            1_000,
            address(0)
        );

        mainnet.selectFork();
        arbitrumForwarder = new CrosschainForwarderArbitrum(address(arbitrumBridgeExecutor));
    }

    function testArbitrumCrossChainPayloadExecution() public {
        mainnet.selectFork();
        vm.deal(
            L1_EXECUTOR,
            0.001 ether
        );

        checkCrosschainPayloadExecution(
            mainnet,
            arbitrum,
            address(arbitrumForwarder),
            address(arbitrumBridgeExecutor)
        );
    }

    function testArbitrumGasCalculations(uint256 paylodDataLength) public {
        vm.assume(paylodDataLength >= 256);
        vm.assume(paylodDataLength <= 1024);

        mainnet.selectFork();

        assertEq(L1_EXECUTOR.balance, 0);
        (bool hasEnoughGasBefore, uint256 requiredGas) = arbitrumForwarder.hasSufficientGasForExecution(L1_EXECUTOR, paylodDataLength);
        assertEq(hasEnoughGasBefore, false);

        vm.deal(address(L1_EXECUTOR), requiredGas);
        (bool hasEnoughGasAfter, ) = arbitrumForwarder.hasSufficientGasForExecution(L1_EXECUTOR, paylodDataLength);
        assertEq(hasEnoughGasAfter, true);
    }
}
