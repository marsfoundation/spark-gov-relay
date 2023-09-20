// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import { IExecutorBase } from '../../src/interfaces/IExecutorBase.sol';

/**
 * @dev This payload reconfigures birdge executor to a given state
 */
contract ReconfigurationPayload {

    uint256 public immutable newDelay;
    uint256 public immutable newGracePeriod;
    uint256 public immutable newMinimumDelay;
    uint256 public immutable newMaximumDelay;
    address public immutable newGuardian;

    constructor(
        uint256 _newDelay,
        uint256 _newGracePeriod,
        uint256 _newMinimumDelay,
        uint256 _newMaximumDelay,
        address _newGuardian
    ) {
        newDelay =        _newDelay;
        newGracePeriod =  _newGracePeriod;
        newMinimumDelay = _newMinimumDelay;
        newMaximumDelay = _newMaximumDelay;
        newGuardian =     _newGuardian;
    }

    function execute() external {
        IExecutorBase(address(this)).updateDelay(getNewDelay());
        IExecutorBase(address(this)).updateGracePeriod(getNewGracePeriod());
        IExecutorBase(address(this)).updateMinimumDelay(getNewMinimumDelay());
        IExecutorBase(address(this)).updateMaximumDelay(getNewMaximumDelay());
        IExecutorBase(address(this)).updateGuardian(getNewGuardian());
    }

    function getNewDelay() public view returns (uint256) {
        return newDelay;
    }

    function getNewGracePeriod() public view returns (uint256) {
        return newGracePeriod;
    }

    function getNewMinimumDelay() public view returns (uint256) {
        return newMinimumDelay;
    }

    function getNewMaximumDelay() public view returns (uint256) {
        return newMaximumDelay;
    }

    function getNewGuardian() public view returns (address) {
        return newGuardian;
    }


}
