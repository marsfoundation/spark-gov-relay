// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import { AMBBridgeExecutor } from '../../src/executors/AMBBridgeExecutor.sol';

/**
 * @dev This payload reconfigures Gnosis bridge executor to a given state
 */
contract GnosisReconfigurationPayload {

    address public immutable newAmb;
    address public immutable newController;

    bytes32 public immutable newChainId;

    constructor(
        address _newAmb,
        address _newController,
        bytes32 _newChainId
    ) {
        newAmb =        _newAmb;
        newController = _newController;
        newChainId =    _newChainId;
    }

    function execute() external {
        AMBBridgeExecutor(address(this)).setAmb(getNewAmb());
        AMBBridgeExecutor(address(this)).setController(getNewController());
        AMBBridgeExecutor(address(this)).setChainId(getNewChainId());
    }

    function getNewAmb() public view returns (address) {
        return newAmb;
    }

    function getNewController() public view returns (address) {
        return newController;
    }

    function getNewChainId() public view returns (bytes32) {
        return newChainId;
    }
}
