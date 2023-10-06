// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IL2BridgeExecutor} from '../interfaces/IL2BridgeExecutor.sol';

interface IAMB {
  function requireToPassMessage(
    address _contract,
    bytes memory _data,
    uint256 _gas
  ) external returns (bytes32);

  function maxGasPerTx(
  ) external view returns (uint256);
}

/**
 * @title A generic executor for proposals targeting the gnosis chain v3 pool
 * @author BGD Labs
 * @notice You can **only** use this executor when the AMB payload has a `execute()` signature without parameters
 * @notice You can **only** use this executor when the AMB payload is expected to be executed via `DELEGATECALL`
 * @notice You can **only** execute payloads on Gnosis Chain with up to max gas which is specified in `MAX_GAS_LIMIT` gas that
 * is returned from calling the AMB contract.
 * @dev This executor is a generic wrapper to be used with AMB (https://etherscan.io/address/0x4C36d2919e407f0Cc2Ee3c993ccF8ac26d9CE64e)
 * It encodes and sends via the L2CrossDomainMessenger a message to queue for execution an action on Gnosis Chain, in the Aave AMB_BRIDGE_EXECUTOR.
 */
contract CrosschainForwarderGnosis {
  /**
   * @dev The AMB Home contract sends messages from Mainnet to Gnosis Chain,.
   * In this contract it's used by the governance SHORT_EXECUTOR to send the encoded Gnosis Cbain queuing over the bridge.
   */
  address public constant L1_AMB_CROSS_DOMAIN_MESSENGER_ADDRESS =
    0x4C36d2919e407f0Cc2Ee3c993ccF8ac26d9CE64e;

  /**
   * @dev The Gnosis Chain bridge executor is a sidechain governance execution contract.
   * This contract allows queuing of proposals by allow listed addresses (in this case the Mainnet short executor).
   */
  address public immutable AMB_BRIDGE_EXECUTOR;

  /**
   * @param bridgeExecutor The L2 executor
   */
  constructor(address bridgeExecutor) {
    AMB_BRIDGE_EXECUTOR = bridgeExecutor;
  }


  /**
   * @dev this function will be executed once the proposal passes the mainnet vote.
   * @param GCPayloadContract the Gnosis Chain contract containing the `execute()` signature.
   */
  function execute(address GCPayloadContract) public {
    address[] memory targets = new address[](1);
    targets[0] = GCPayloadContract;
    uint256[] memory values = new uint256[](1);
    values[0] = 0;
    string[] memory signatures = new string[](1);
    signatures[0] = 'execute()';
    bytes[] memory calldatas = new bytes[](1);
    calldatas[0] = '';
    bool[] memory withDelegatecalls = new bool[](1);
    withDelegatecalls[0] = true;

    bytes memory queue = abi.encodeWithSelector(
      IL2BridgeExecutor.queue.selector,
      targets,
      values,
      signatures,
      calldatas,
      withDelegatecalls
    );

    IAMB(L1_AMB_CROSS_DOMAIN_MESSENGER_ADDRESS).requireToPassMessage(
      AMB_BRIDGE_EXECUTOR,
      queue,
      IAMB(L1_AMB_CROSS_DOMAIN_MESSENGER_ADDRESS).maxGasPerTx()
    );
  }
}
