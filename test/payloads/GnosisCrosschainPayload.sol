// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { AMBForwarder } from 'lib/xchain-helpers/src/forwarders/AMBForwarder.sol';

import { CrosschainPayload, IPayload } from './CrosschainPayload.sol';

contract GnosisCrosschainPayload is CrosschainPayload {

    constructor(IPayload _targetPayload, address _bridgeReceiver) CrosschainPayload(_targetPayload, _bridgeReceiver) {
    }

    function execute() external override {
        AMBForwarder.sendMessageEthereumToGnosisChain(
            bridgeReceiver,
            encodeCrosschainExecutionMessage(),
            1_000_000
        );
    }

}
