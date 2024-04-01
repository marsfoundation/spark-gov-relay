// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import { ArbitrumReceiver } from 'xchain-helpers/ArbitrumReceiver.sol';

import { IAuthBridgeExecutor } from '../interfaces/IAuthBridgeExecutor.sol';

contract BridgeExecutorReceiverArbitrum is ArbitrumReceiver {

    IAuthBridgeExecutor public executor;

    constructor(
        address _l1Authority,
        IAuthBridgeExecutor _executor
    ) ArbitrumReceiver(_l1Authority) {
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