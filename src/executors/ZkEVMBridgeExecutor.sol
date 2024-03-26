// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { BridgeExecutorBase } from "./BridgeExecutorBase.sol";
import { IL2BridgeExecutor } from "../interfaces/IL2BridgeExecutor.sol";

interface IZkEVMBridgeMessageReceiver {
    function onMessageReceived(address originAddress, uint32 originNetwork, bytes memory data) external payable;
}

/**
 * @title ZkEVMBridgeExecutor
 * @notice Implementation of the ZkEVM Bridge Executor, able to receive cross-chain transactions from Ethereum
 * @dev Queuing an ActionsSet into this Executor can only be done by the ZkEVM Bridge and having
 * the EthereumGovernanceExecutor as the sender
 */
contract ZkEVMBridgeExecutor is BridgeExecutorBase, IZkEVMBridgeMessageReceiver {
    error UnauthorizedBridgeCaller();
    error InvalidOriginNetwork();
    error InvalidMethodId();
    error UnauthorizedEthereumExecutor();

    /**
     * @dev Emitted when the Ethereum Governance Executor is updated
     * @param oldEthereumGovernanceExecutor The address of the old EthereumGovernanceExecutor
     * @param newEthereumGovernanceExecutor The address of the new EthereumGovernanceExecutor
     *
     */
    event EthereumGovernanceExecutorUpdate(
        address oldEthereumGovernanceExecutor, address newEthereumGovernanceExecutor
    );

    // Address of the Ethereum Governance Executor, which should be able to queue actions sets
    address public ethereumGovernanceExecutor;

    uint32  public immutable originNetworkId;

    // Address of the ZkEVM bridge
    address public immutable zkEVMBridge;

    /**
     * @dev Constructor
     *
     * @param bridge The address of the ZkEVM Bridge
     * @param ethereumGovernanceExecutor_ The address of the EthereumGovernanceExecutor
     * @param delay The delay before which an actions set can be executed
     * @param gracePeriod The time period after a delay during which an actions set can be executed
     * @param minimumDelay The minimum bound a delay can be set to
     * @param maximumDelay The maximum bound a delay can be set to
     * @param guardian The address of the guardian, which can cancel queued proposals (can be zero)
     */
    constructor(
        address bridge,
        address ethereumGovernanceExecutor_,
        uint256 delay,
        uint256 gracePeriod,
        uint256 minimumDelay,
        uint256 maximumDelay,
        address guardian,
        uint32 originNetworkId_
    ) BridgeExecutorBase(delay, gracePeriod, minimumDelay, maximumDelay, guardian) {
        originNetworkId = originNetworkId_;
        ethereumGovernanceExecutor = ethereumGovernanceExecutor_;
        zkEVMBridge = bridge;
    }

    function onMessageReceived(address originAddress, uint32 originNetwork, bytes calldata data) external payable {
        if (msg.sender != zkEVMBridge) revert UnauthorizedBridgeCaller();
        if (originAddress != ethereumGovernanceExecutor) revert UnauthorizedEthereumExecutor();
        if (originNetwork != originNetworkId) revert InvalidOriginNetwork();
        bytes4 methodId = bytes4(data[0:4]);
        if (methodId != IL2BridgeExecutor.queue.selector) revert InvalidMethodId();

        (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas,
            bool[] memory withDelegatecalls
        ) = abi.decode(data[4:], (address[], uint256[], string[], bytes[], bool[]));

        _queue(targets, values, signatures, calldatas, withDelegatecalls);
    }

    /**
     * @notice Update the address of the Ethereum Governance Executor
     * @param ethereumGovernanceExecutor_ The address of the new EthereumGovernanceExecutor
     *
     */
    function updateEthereumGovernanceExecutor(address ethereumGovernanceExecutor_) external onlyThis {
        emit EthereumGovernanceExecutorUpdate(ethereumGovernanceExecutor, ethereumGovernanceExecutor_);
        ethereumGovernanceExecutor = ethereumGovernanceExecutor_;
    }
}
