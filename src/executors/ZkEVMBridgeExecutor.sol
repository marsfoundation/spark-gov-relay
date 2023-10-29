// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import {L2BridgeExecutor} from "./L2BridgeExecutor.sol";

interface IZkEvmBridgeLike {
    function bridgeMessage(
        uint32 destinationNetwork,
        address destinationAddress,
        bool forceUpdateGlobalExitRoot,
        bytes calldata metadata
    ) external payable;
}

interface IBridgeMessageReceiver {
    function onMessageReceived(address originAddress, uint32 originNetwork, bytes memory data) external payable;
}

/**
 * @title ZkEVMBridgeExecutor
 * @notice Implementation of the ZkEVM Bridge Executor, able to receive cross-chain transactions from Ethereum
 * @dev Queuing an ActionsSet into this Executor can only be done by the ZkEVM Bridge and having
 * the EthereumGovernanceExecutor as the sender
 */
contract ZkEVMBridgeExecutor is L2BridgeExecutor, IBridgeMessageReceiver {
    error UnauthorizedBridgeCaller();
    error NotDirectlyCallable();
    error InvalidOriginNetwork();
    error InvalidMethodId();

    uint32 internal constant _MAINNET_NETWORK_ID = 0;

    // Address of the ZkEVM bridge
    address public immutable ZKEVM_BRIDGE;
    address internal immutable zkEVMBridge;

    /// @inheritdoc L2BridgeExecutor
    modifier onlyEthereumGovernanceExecutor() override {
        revert NotDirectlyCallable();
        _;
    }

    /**
     * @dev Constructor
     *
     * @param bridge The address of the ZkEVM Bridge
     * @param ethereumGovernanceExecutor The address of the EthereumGovernanceExecutor
     * @param delay The delay before which an actions set can be executed
     * @param gracePeriod The time period after a delay during which an actions set can be executed
     * @param minimumDelay The minimum bound a delay can be set to
     * @param maximumDelay The maximum bound a delay can be set to
     * @param guardian The address of the guardian, which can cancel queued proposals (can be zero)
     */
    constructor(
        address bridge,
        address ethereumGovernanceExecutor,
        uint256 delay,
        uint256 gracePeriod,
        uint256 minimumDelay,
        uint256 maximumDelay,
        address guardian
    ) L2BridgeExecutor(ethereumGovernanceExecutor, delay, gracePeriod, minimumDelay, maximumDelay, guardian) {
        zkEVMBridge = bridge;
    }

    function onMessageReceived(address originAddress, uint32 originNetwork, bytes calldata data) external payable {
        if (originAddress != _ethereumGovernanceExecutor) {
            revert UnauthorizedEthereumExecutor();
        }
        if (originNetwork != _MAINNET_NETWORK_ID) {
            revert InvalidOriginNetwork();
        }
        bytes4 methodId = bytes4(data[0:4]);
        if (methodId != this.queue.selector) {
            revert InvalidMethodId();
        }

        (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas,
            bool[] memory withDelegatecalls
        ) = abi.decode(data[4:], (address[], uint256[], string[], bytes[], bool[]));

        _queue(targets, values, signatures, calldatas, withDelegatecalls);
    }
}
