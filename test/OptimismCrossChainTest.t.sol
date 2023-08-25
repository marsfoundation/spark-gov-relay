// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import {ProtocolV3TestBase} from 'aave-helpers/ProtocolV3TestBase.sol';
import {OptimismDomain, Domain} from 'xchain-helpers/OptimismDomain.sol';

import {OptimismBridgeExecutor} from '../src/executors/OptimismBridgeExecutor.sol';
import {CrosschainForwarderOptimism} from '../src/forwarders/CrosschainForwarderOptimism.sol';

contract OptimismCrossTest is ProtocolV3TestBase {
  event TestEvent();

  address public constant OVM_L2_CROSS_DOMAIN_MESSENGER = 0x4200000000000000000000000000000000000007;
  address public constant L1_EXECUTOR = 0x3300f198988e4C9C63F75dF86De36421f06af8c4;

  Domain public mainnet;
  OptimismDomain public optimism;

  OptimismBridgeExecutor public bridgeExecutor;
  CrosschainForwarderOptimism public forwarder;

  function setUp() public {
    optimism = new OptimismDomain(
        getChain('optimism'),
        new Domain(getChain('mainnet'))
        );
    mainnet = optimism.hostDomain();
  }

  function testCrossChainProposalExecution() public {
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

    mainnet.selectFork();
    forwarder = new CrosschainForwarderOptimism(address(bridgeExecutor));
  }
}
