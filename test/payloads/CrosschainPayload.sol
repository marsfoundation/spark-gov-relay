// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IExecutor } from 'src/interfaces/IExecutor.sol';

import { IPayload } from './IPayload.sol';

abstract contract CrosschainPayload is IPayload {

    IPayload immutable targetPayload;
    address  immutable bridgeReceiver;

    constructor(IPayload _targetPayload, address _bridgeReceiver) {
        targetPayload  = _targetPayload;
        bridgeReceiver = _bridgeReceiver;
    }

    function execute() external virtual;

    function encodeCrosschainExecutionMessage() internal view returns (bytes memory) {
        address[] memory targets = new address[](1);
        targets[0] = address(targetPayload);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        string[] memory signatures = new string[](1);
        signatures[0] = 'execute()';
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = '';
        bool[] memory withDelegatecalls = new bool[](1);
        withDelegatecalls[0] = true;

        return abi.encodeWithSelector(
            IExecutor.queue.selector,
            targets,
            values,
            signatures,
            calldatas,
            withDelegatecalls
        );
    }

}
