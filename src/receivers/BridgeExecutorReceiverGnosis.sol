// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import { GnosisReceiver } from 'xchain-helpers/GnosisReceiver.sol';

import { IAuthBridgeExecutor } from 'src/interfaces/IAuthBridgeExecutor.sol';

contract BridgeExecutorReceiverGnosis is GnosisReceiver {

    IAuthBridgeExecutor public executor;

    constructor(
        address _l2CrossDomain,
        uint256 _chainId,
        address _l1Authority,
        IAuthBridgeExecutor _executor
    ) GnosisReceiver(_l2CrossDomain, _chainId, _l1Authority) {
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
