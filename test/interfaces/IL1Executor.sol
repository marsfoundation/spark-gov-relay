// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IL1Executor {
    function exec(address target, bytes calldata args)
        external
        payable
        returns (bytes memory out);
}
