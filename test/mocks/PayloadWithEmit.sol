// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/**
 * @dev This payload simply emits an event on execution
 */
contract PayloadWithEmit {
  event TestEvent();

  function execute() external {
    emit TestEvent();
  }
}
