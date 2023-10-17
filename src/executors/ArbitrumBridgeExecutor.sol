// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import {L2BridgeExecutor} from './L2BridgeExecutor.sol';

/**
 * @title ArbitrumBridgeExecutor
 * @author Aave
 * @notice Implementation of the Arbitrum Bridge Executor, able to receive cross-chain transactions from Ethereum
 * @dev Queuing an ActionsSet into this Executor can only be done by the L2 Address Alias of the L1 EthereumGovernanceExecutor
 */
contract ArbitrumBridgeExecutor is L2BridgeExecutor {
    uint160 internal constant OFFSET = uint160(0x1111000000000000000000000000000000001111);

    /// @notice Utility function that converts the msg.sender viewed in the L2 to the
    /// address in the L1 that submitted a tx to the inbox
    /// @param l2Address L2 address as viewed in msg.sender
    /// @return l1Address the address in the L1 that triggered the tx to L2
    function undoL1ToL2Alias(address l2Address) internal pure returns (address l1Address) {
        unchecked {
            l1Address = address(uint160(l2Address) - OFFSET);
        }
    }

    /// @inheritdoc L2BridgeExecutor
    modifier onlyEthereumGovernanceExecutor() override {
        if (undoL1ToL2Alias(msg.sender) != _ethereumGovernanceExecutor)
            revert UnauthorizedEthereumExecutor();
        _;
    }

    /**
    * @dev Constructor
    *
    * @param ethereumGovernanceExecutor The address of the EthereumGovernanceExecutor
    * @param delay The delay before which an actions set can be executed
    * @param gracePeriod The time period after a delay during which an actions set can be executed
    * @param minimumDelay The minimum bound a delay can be set to
    * @param maximumDelay The maximum bound a delay can be set to
    * @param guardian The address of the guardian, which can cancel queued proposals (can be zero)
    */
    constructor(
        address ethereumGovernanceExecutor,
        uint256 delay,
        uint256 gracePeriod,
        uint256 minimumDelay,
        uint256 maximumDelay,
        address guardian
    )
        L2BridgeExecutor(
            ethereumGovernanceExecutor,
            delay,
            gracePeriod,
            minimumDelay,
            maximumDelay,
            guardian
        )
    {
      // Intentionally left blank
    }
}
