// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { OptimismReceiver } from 'xchain-helpers/OptimismReceiver.sol';

import { IAuthBridgeExecutor } from 'src/interfaces/IAuthBridgeExecutor.sol';

contract BridgeExecutorReceiverOptimism is OptimismReceiver {

    IAuthBridgeExecutor public executor;

    constructor(
        address _l1Authority,
        IAuthBridgeExecutor _executor
    ) OptimismReceiver(_l1Authority) {
        executor = _executor;
    }

    function queue(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        bool[] memory withDelegatecalls
    ) external onlyCrossChainMessage {
        executor.queue(
            targets,
            values,
            signatures,
            calldatas,
            withDelegatecalls
        );
    }

}
