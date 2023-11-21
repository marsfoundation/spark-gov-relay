// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { Domain, ScrollDomain } from 'xchain-helpers/testing/ScrollDomain.sol';
import { XChainForwarders }       from 'xchain-helpers/XChainForwarders.sol';

import { ScrollBridgeExecutor } from '../src/executors/ScrollBridgeExecutor.sol';

import { IL2BridgeExecutor } from '../src/interfaces/IL2BridgeExecutor.sol';

import { IPayload } from './interfaces/IPayload.sol';

import { CrosschainPayload, CrosschainTestBase } from './CrosschainTestBase.sol';

interface MessageQueueLike {
    function estimateCrossDomainMessageFee(uint256 gasLimit) external view returns (uint256);
}

contract ScrollCrosschainPayload is CrosschainPayload {
    address public constant L1_MESSAGE_QUEUE = 0x0d7E906BD9cAFa154b048cFa766Cc1E54E39AF9B;

    constructor(IPayload _targetPayload, address _bridgeExecutor)
        CrosschainPayload(_targetPayload, _bridgeExecutor) {}

    function execute() external override {
        XChainForwarders.sendMessageScrollMainnet(
            bridgeExecutor,
            encodeCrosschainExecutionMessage(),
            1_000_000,
            MessageQueueLike(L1_MESSAGE_QUEUE).estimateCrossDomainMessageFee(1_000_000)
        );
    }

}

contract ScrollCrosschainTest is CrosschainTestBase {

    address public constant L2_SCROLL_MESSENGER = 0x781e90f1c8Fc4611c9b7497C3B47F99Ef6969CbC;

    function deployCrosschainPayload(IPayload targetPayload, address bridgeExecutor)
        public override returns (IPayload)
    {
        return IPayload(new ScrollCrosschainPayload(targetPayload, bridgeExecutor));
    }

    function setUp() public {
        setChain(
            "scroll",
            ChainData("Scroll Chain", 534352, "https://rpc.scroll.io")
        );

        hostDomain = new Domain(getChain('mainnet'));
        bridgedDomain = new ScrollDomain(getChain('scroll'), hostDomain);

        bridgedDomain.selectFork();
        bridgeExecutor = address(new ScrollBridgeExecutor(
            L2_SCROLL_MESSENGER,
            defaultL2BridgeExecutorArgs.ethereumGovernanceExecutor,
            defaultL2BridgeExecutorArgs.delay,
            defaultL2BridgeExecutorArgs.gracePeriod,
            defaultL2BridgeExecutorArgs.minimumDelay,
            defaultL2BridgeExecutorArgs.maximumDelay,
            defaultL2BridgeExecutorArgs.guardian
        ));

        hostDomain.selectFork();
        vm.deal(L1_EXECUTOR, 100 ether);
    }

}
