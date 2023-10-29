// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { Domain, ZkEVMDomain } from 'xchain-helpers/testing/ZkEVMDomain.sol';
import { XChainForwarders }       from 'xchain-helpers/XChainForwarders.sol';

import { ZkEVMBridgeExecutor } from '../src/executors/ZkEVMBridgeExecutor.sol';

import { IL2BridgeExecutor } from '../src/interfaces/IL2BridgeExecutor.sol';

import { IPayload } from './interfaces/IPayload.sol';

import { CrosschainPayload, CrosschainTestBase } from './CrosschainTestBase.sol';

contract ZkEVMCrosschainPayload is CrosschainPayload {

    constructor(IPayload _targetPayload, address _bridgeExecutor)
        CrosschainPayload(_targetPayload, _bridgeExecutor) {}

    function execute() external override {
        XChainForwarders.sendMessageZkEVM(
            bridgeExecutor,
            encodeCrosschainExecutionMessage()
        );
    }

}

contract ZkEVMCrosschainTest is CrosschainTestBase {
    address constant ZKEVM_BRIDGE = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;

    function deployCrosschainPayload(IPayload targetPayload, address bridgeExecutor)
        public override returns (IPayload)
    {
        return IPayload(new ZkEVMCrosschainPayload(targetPayload, bridgeExecutor));
    }

    function setUp() public {
        setChain("zkevm", ChainData("ZkEVM", 1101, "https://zkevm-rpc.com"));
        hostDomain = new Domain(getChain('mainnet'));
        bridgedDomain = new ZkEVMDomain(getChain('zkevm'), hostDomain);

        bridgedDomain.selectFork();
        bridgeExecutor = address(new ZkEVMBridgeExecutor(
            ZKEVM_BRIDGE,
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
