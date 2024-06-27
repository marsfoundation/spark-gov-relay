// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { OptimismForwarder } from 'lib/xchain-helpers/src/forwarders/OptimismForwarder.sol';

import { CrosschainPayload, IPayload } from './CrosschainPayload.sol';

contract OptimismCrosschainPayload is CrosschainPayload {

    address public immutable l1CrossDomain;

    constructor(address _l1CrossDomain, IPayload _targetPayload, address _bridgeReceiver) CrosschainPayload(_targetPayload, _bridgeReceiver) {
        l1CrossDomain = _l1CrossDomain;
    }

    function execute() external override {
        OptimismForwarder.sendMessageL1toL2(
            l1CrossDomain,
            bridgeReceiver,
            encodeCrosschainExecutionMessage(),
            1_000_000
        );
    }

}
