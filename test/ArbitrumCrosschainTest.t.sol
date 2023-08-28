// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { ProtocolV3TestBase } from 'spark-spells/ProtocolV3TestBase.sol';
import { ArbitrumDomain, Domain } from 'xchain-helpers/ArbitrumDomain.sol';

import { ArbitrumBridgeExecutor } from '../src/executors/ArbitrumBridgeExecutor.sol';
import { CrosschainForwarderArbitrum } from '../src/forwarders/CrosschainForwarderArbitrum.sol';

import { PayloadWithEmit } from './mocks/PayloadWithEmit.sol';
import { IExecutor } from './interfaces/IExecutor.sol';

contract ArbitrumCrosschainTest is ProtocolV3TestBase {
    event TestEvent();

    address public constant L1_EXECUTOR    = 0x3300f198988e4C9C63F75dF86De36421f06af8c4;
    address public constant L1_PAUSE_PROXY = 0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB;

    Domain public mainnet;
    ArbitrumDomain public arbitrum;

    ArbitrumBridgeExecutor public bridgeExecutor;
    CrosschainForwarderArbitrum public forwarder;
    PayloadWithEmit public payloadWithEmit;

    bytes public encodedPayloadData;

    function setUp() public {
        arbitrum = new ArbitrumDomain(
            getChain('arbitrum_one'),
            new Domain(getChain('mainnet'))
            );
        mainnet = arbitrum.hostDomain();

        arbitrum.selectFork();
        bridgeExecutor = new ArbitrumBridgeExecutor(
            L1_EXECUTOR,
            0,
            1_000,
            0,
            1_000,
            address(0)
        );
        payloadWithEmit = new PayloadWithEmit();

        mainnet.selectFork();
        forwarder = new CrosschainForwarderArbitrum(address(bridgeExecutor));

        encodedPayloadData = abi.encodeWithSelector(
            CrosschainForwarderArbitrum.execute.selector,
            address(payloadWithEmit)
        );
    }

    function testHasSufficientGas() public {
        mainnet.selectFork();

        assertEq(L1_EXECUTOR.balance, 0);
        (bool hasEnoughGasBefore, uint256 requiredGas) = forwarder.hasSufficientGasForExecution(L1_EXECUTOR, encodedPayloadData.length);
        assertEq(hasEnoughGasBefore, false);

        vm.deal(address(L1_EXECUTOR), requiredGas);
        (bool hasEnoughGasAfter, ) = forwarder.hasSufficientGasForExecution(L1_EXECUTOR, encodedPayloadData.length);
        assertEq(hasEnoughGasAfter, true);
    }

    function testCrossChainPayloadExecution() public {
        mainnet.selectFork();

        // (uint256 maxSubmission, uint256 maxRedemption) = forwarder.getRequiredGas(encodedPayloadData.length);
        // (bool hasEnoughGasBefore, ) = forwarder.hasSufficientGasForExecution(L1_EXECUTOR, encodedPayloadData.length);
        // assertEq(hasEnoughGasBefore, false);
        // vm.deal(
        //     L1_EXECUTOR,
        //     (maxSubmission + maxRedemption)
        // );
        // (bool hasEnoughGasAfter, ) = forwarder.hasSufficientGasForExecution(L1_EXECUTOR, encodedPayloadData.length);
        // assertEq(hasEnoughGasAfter, true);

        vm.deal(
            L1_EXECUTOR,
            0.001 ether
        );

        vm.prank(L1_PAUSE_PROXY);
        IExecutor(L1_EXECUTOR).exec(
            address(forwarder),
            encodedPayloadData
        );

        arbitrum.relayFromHost(true);

        vm.expectEmit(address(bridgeExecutor));
        emit TestEvent();
        bridgeExecutor.execute(0);
    }
}
