// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import { Domain, GnosisDomain } from 'xchain-helpers/testing/GnosisDomain.sol';
import { XChainForwarders }     from 'xchain-helpers/XChainForwarders.sol';

import { IAMB, GnosisBridgeExecutor } from '../src/executors/GnosisBridgeExecutor.sol';

import { IL2BridgeExecutor } from '../src/interfaces/IL2BridgeExecutor.sol';

import { IL1Executor } from './interfaces/IL1Executor.sol';
import { IPayload }    from './interfaces/IPayload.sol';

import { GnosisReconfigurationPayload } from './mocks/GnosisReconfigurationPayload.sol';

import { CrosschainPayload, CrosschainTestBase } from './CrosschainTestBase.sol';

contract GnosisCrosschainPayload is CrosschainPayload {

    constructor(IPayload _targetPayload, address _bridgeExecutor)
        CrosschainPayload(_targetPayload, _bridgeExecutor) {}

    function execute() external override {
        XChainForwarders.sendMessageGnosis(
            bridgeExecutor,
            encodeCrosschainExecutionMessage(),
            1_000_000
        );
    }

}

contract GnosisCrosschainTest is CrosschainTestBase {
    IAMB public constant AMB = IAMB(0x75Df5AF045d91108662D8080fD1FEFAd6aA0bb59);

    bytes32 public constant MAINNET_CHAIN_ID = bytes32(uint256(1));

    function deployCrosschainPayload(IPayload targetPayload, address bridgeExecutor)
        public override returns (IPayload)
    {
        return IPayload(new GnosisCrosschainPayload(targetPayload, bridgeExecutor));
    }

    function setUp() public {
        hostDomain    = new Domain(getChain('mainnet'));
        bridgedDomain = new GnosisDomain(getChain('gnosis_chain'), hostDomain);

        bridgedDomain.selectFork();
        bridgeExecutor = address(new GnosisBridgeExecutor(
            AMB,
            defaultL2BridgeExecutorArgs.ethereumGovernanceExecutor,
            MAINNET_CHAIN_ID,
            defaultL2BridgeExecutorArgs.delay,
            defaultL2BridgeExecutorArgs.gracePeriod,
            defaultL2BridgeExecutorArgs.minimumDelay,
            defaultL2BridgeExecutorArgs.maximumDelay,
            defaultL2BridgeExecutorArgs.guardian
        ));

        hostDomain.selectFork();
    }

    function test_gnosisSpecificSelfReconfiguration() public {
        bridgedDomain.selectFork();

        assertEq(
            address(GnosisBridgeExecutor(bridgeExecutor).amb()),
            address(AMB)
        );
        assertEq(
            GnosisBridgeExecutor(bridgeExecutor).controller(),
            defaultL2BridgeExecutorArgs.ethereumGovernanceExecutor
        );
        assertEq(
            GnosisBridgeExecutor(bridgeExecutor).chainId(),
            MAINNET_CHAIN_ID
        );

        address newAmb        = makeAddr('newAMB');
        address newController = makeAddr('newController');

        bytes32 newChainId = bytes32(uint256(2));

        IPayload reconfigurationPayload = IPayload(new GnosisReconfigurationPayload(
            newAmb,
            newController,
            newChainId
        ));

        hostDomain.selectFork();

        IPayload crosschainPayload = deployCrosschainPayload(
            reconfigurationPayload,
            bridgeExecutor
        );

        vm.prank(L1_PAUSE_PROXY);
        IL1Executor(L1_EXECUTOR).exec(
            address(crosschainPayload),
            abi.encodeWithSelector(IPayload.execute.selector)
        );

        bridgedDomain.relayFromHost(true);

        skip(defaultL2BridgeExecutorArgs.delay);

        IL2BridgeExecutor(bridgeExecutor).execute(0);

        assertEq(address(GnosisBridgeExecutor(bridgeExecutor).amb()), newAmb);
        assertEq(
            GnosisBridgeExecutor(bridgeExecutor).controller(),
            newController
        );
        assertEq(GnosisBridgeExecutor(bridgeExecutor).chainId(), newChainId);
    }

}
