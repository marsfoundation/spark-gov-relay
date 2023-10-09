// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBaseCrosschainForwarder {
  function execute(address l2PayloadContract) external;
}
