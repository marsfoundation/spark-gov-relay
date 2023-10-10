// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import { GnosisBridgeExecutor } from '../../src/executors/GnosisBridgeExecutor.sol';

import { IPayload } from '../interfaces/IPayload.sol';

/**
 * @dev This payload reconfigures Gnosis bridge executor to a given state
 */
contract GnosisReconfigurationPayload is IPayload {

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
        GnosisBridgeExecutor(address(this)).setAmb(getNewAmb());
        GnosisBridgeExecutor(address(this)).setController(getNewController());
        GnosisBridgeExecutor(address(this)).setChainId(getNewChainId());
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
