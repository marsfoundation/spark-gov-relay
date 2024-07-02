// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { IExecutor } from 'src/interfaces/IExecutor.sol';

import { IPayload } from '../payloads/IPayload.sol';

/**
 * @dev This payload reconfigures bridge executor to a given state
 */
contract ReconfigurationPayload is IPayload {

    uint256 public immutable newDelay;
    uint256 public immutable newGracePeriod;
    address public immutable oldGuardian;
    address public immutable newGuardian;

    constructor(
        uint256 _newDelay,
        uint256 _newGracePeriod,
        address _oldGuardian,
        address _newGuardian
    ) {
        newDelay        = _newDelay;
        newGracePeriod  = _newGracePeriod;
        oldGuardian     = _oldGuardian;
        newGuardian     = _newGuardian;
    }

    function execute() external override {
        IExecutor(address(this)).updateDelay(getNewDelay());
        IExecutor(address(this)).updateGracePeriod(getNewGracePeriod());
        IExecutor(address(this)).revokeRole(IExecutor(address(this)).GUARDIAN_ROLE(), getOldGuardian());
        IExecutor(address(this)).grantRole(IExecutor(address(this)).GUARDIAN_ROLE(), getNewGuardian());
    }

    function getNewDelay() public view returns (uint256) {
        return newDelay;
    }

    function getNewGracePeriod() public view returns (uint256) {
        return newGracePeriod;
    }

    function getOldGuardian() public view returns (address) {
        return oldGuardian;
    }

    function getNewGuardian() public view returns (address) {
        return newGuardian;
    }

}
