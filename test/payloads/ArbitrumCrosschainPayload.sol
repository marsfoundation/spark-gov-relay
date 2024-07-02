// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { ArbitrumForwarder } from 'lib/xchain-helpers/src/forwarders/ArbitrumForwarder.sol';

import { CrosschainPayload, IPayload } from './CrosschainPayload.sol';

contract ArbitrumCrosschainPayload is CrosschainPayload {

    address public immutable l1CrossDomain;

    constructor(address _l1CrossDomain, IPayload _targetPayload, address _bridgeReceiver) CrosschainPayload(_targetPayload, _bridgeReceiver) {
        l1CrossDomain = _l1CrossDomain;
    }

    function execute() external override {
        ArbitrumForwarder.sendMessageL1toL2(
            l1CrossDomain,
            bridgeReceiver,
            encodeCrosschainExecutionMessage(),
            1_000_000,
            1 gwei,
            block.basefee + 10 gwei
        );
    }

}
