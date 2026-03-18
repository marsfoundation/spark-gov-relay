// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { OptionsBuilder } from "layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

import { LZGovBridgeForwarder, MessagingFee } from 'lib/xchain-helpers/src/forwarders/LZGovBridgeForwarder.sol';

import { CrosschainPayload, IPayload } from './CrosschainPayload.sol';

contract LZGovBridgeCrosschainPayload is CrosschainPayload {

    using OptionsBuilder for bytes;

    uint32  public immutable dstEid;
    address public immutable govOapp;
    address public immutable receiver;

    constructor(
        uint32   _dstEid,
        address  _govOapp,
        address  _receiver,
        IPayload _targetPayload,
        address  _bridgeReceiver
    ) CrosschainPayload(_targetPayload, _bridgeReceiver) {
        dstEid  = _dstEid;
        govOapp = _govOapp;
        receiver = _receiver;
    }

    function execute() external override {
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200_000, 0);

        bytes memory message = encodeCrosschainExecutionMessage();

        MessagingFee memory fee = LZGovBridgeForwarder.quote(
            govOapp,
            dstEid,
            receiver,
            message,
            options,
            false
        );

        LZGovBridgeForwarder.sendMessage(
            govOapp,
            dstEid,
            receiver,
            message,
            options,
            msg.sender,
            fee,
            address(0)
        );
    }

}
