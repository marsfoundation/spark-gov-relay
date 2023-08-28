// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { OptimismDomain, Domain } from 'xchain-helpers/OptimismDomain.sol';

import { OptimismBridgeExecutor } from '../src/executors/OptimismBridgeExecutor.sol';
import { CrosschainForwarderOptimism } from '../src/forwarders/CrosschainForwarderOptimism.sol';

import { PayloadWithEmit } from './mocks/PayloadWithEmit.sol';
import { IExecutor } from './interfaces/IExecutor.sol';

contract OptimismCrosschainTest is Test {
    event TestEvent();

    address public constant OVM_L2_CROSS_DOMAIN_MESSENGER = 0x4200000000000000000000000000000000000007;
    address public constant L1_EXECUTOR                   = 0x3300f198988e4C9C63F75dF86De36421f06af8c4;
    address public constant L1_PAUSE_PROXY                = 0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB;

    Domain public mainnet;
    OptimismDomain public optimism;

    OptimismBridgeExecutor public bridgeExecutor;
    CrosschainForwarderOptimism public forwarder;
    PayloadWithEmit public payloadWithEmit;

    bytes public encodedPayloadData;

    function setUp() public {
        optimism = new OptimismDomain(
            getChain('optimism'),
            new Domain(getChain('mainnet'))
            );
        mainnet = optimism.hostDomain();

        optimism.selectFork();
        bridgeExecutor = new OptimismBridgeExecutor(
            OVM_L2_CROSS_DOMAIN_MESSENGER,
            L1_EXECUTOR,
            0,
            1_000,
            0,
            1_000,
            address(0)
        );
        payloadWithEmit = new PayloadWithEmit();

        mainnet.selectFork();
        forwarder = new CrosschainForwarderOptimism(address(bridgeExecutor));

        encodedPayloadData = abi.encodeWithSelector(
            CrosschainForwarderOptimism.execute.selector,
            address(payloadWithEmit)
        );
    }

    function testCrossChainPayloadExecution() public {
        mainnet.selectFork();

        vm.prank(L1_PAUSE_PROXY);
        IExecutor(L1_EXECUTOR).exec(
            address(forwarder),
            encodedPayloadData
        );

        optimism.relayFromHost(true);

        vm.expectEmit(address(bridgeExecutor));
        emit TestEvent();
        bridgeExecutor.execute(0);
    }
}
