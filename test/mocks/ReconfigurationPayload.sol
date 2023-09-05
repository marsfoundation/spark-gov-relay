// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import { IExecutorBase } from '../../src/interfaces/IExecutorBase.sol';

/**
 * @dev This payload reconfigures birdge executor to a given state
 */
contract ReconfigurationPayload {

    function execute() external {
        IExecutorBase(address(this)).updateDelay(getNewDelay());
        IExecutorBase(address(this)).updateGracePeriod(getNewGracePeriod());
        IExecutorBase(address(this)).updateMinimumDelay(getNewMinimumDelay());
        IExecutorBase(address(this)).updateMaximumDelay(getNewMaximumDelay());
        IExecutorBase(address(this)).updateGuardian(getNewGuardian());
    }

    function getNewDelay() public pure returns (uint256) {
        return 1200;
    }

    function getNewGracePeriod() public pure returns (uint256) {
        return 1800;
    }

    function getNewMinimumDelay() public pure returns (uint256) {
        return 100;
    }

    function getNewMaximumDelay() public pure returns (uint256) {
        return 3600;
    }

    function getNewGuardian() public pure returns (address) {
        return 0x3300f198988e4C9C63F75dF86De36421f06af8c4;
    }


}
