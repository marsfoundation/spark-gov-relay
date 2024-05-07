// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { IPayload } from '../interfaces/IPayload.sol';

/**
 * @dev This payload simply emits an event on execution
 */
contract PayloadWithEmit is IPayload {
    event TestEvent();

    function execute() external override {
        emit TestEvent();
    }
}
