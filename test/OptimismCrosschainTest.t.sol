// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { Domain, OptimismDomain } from 'xchain-helpers/testing/OptimismDomain.sol';
import { XChainForwarders }       from 'xchain-helpers/XChainForwarders.sol';

import { OptimismBridgeExecutor } from '../src/executors/OptimismBridgeExecutor.sol';

import { IL2BridgeExecutor } from '../src/interfaces/IL2BridgeExecutor.sol';

import { IPayload } from './interfaces/IPayload.sol';

import { CrosschainPayload, CrosschainTestBase } from './CrosschainTestBase.sol';

contract OptimismCrosschainPayload is CrosschainPayload {

    constructor(IPayload _targetPayload, address _bridgeExecutor)
        CrosschainPayload(_targetPayload, _bridgeExecutor) {}

    function execute() external override {
        XChainForwarders.sendMessageOptimismMainnet(
            bridgeExecutor,
            encodeCrosschainExecutionMessage(),
            1_000_000
        );
    }

}

contract OptimismCrosschainTest is CrosschainTestBase {

    address public constant OVM_L2_CROSS_DOMAIN_MESSENGER = 0x4200000000000000000000000000000000000007;

    function deployCrosschainPayload(IPayload targetPayload, address bridgeExecutor)
        public override returns (IPayload)
    {
        return IPayload(new OptimismCrosschainPayload(targetPayload, bridgeExecutor));
    }

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
    }

}
