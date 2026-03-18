// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import './CrosschainTestBase.sol';

import { LZBridgeTesting }                      from 'lib/xchain-helpers/src/testing/bridges/LZBridgeTesting.sol';
import { LZGovBridgeForwarder }                  from 'lib/xchain-helpers/src/forwarders/LZGovBridgeForwarder.sol';
import { LZGovBridgeReceiver }                   from 'lib/xchain-helpers/src/receivers/LZGovBridgeReceiver.sol';

import { GovernanceOAppReceiverMock } from 'lib/xchain-helpers/test/mocks/lz/GovernanceOAppReceiverMock.sol';

import { LZGovBridgeCrosschainPayload } from './payloads/LZGovBridgeCrosschainPayload.sol';

interface IChainLog {
    function getAddress(bytes32) external view returns (address);
}

interface IGovOappSender {
    function owner() external view returns (address);
    function setPeer(uint32 _eid, bytes32 _peer) external;
    function setCanCallTarget(address _srcSender, uint32 _dstEid, bytes32 _dstTarget, bool _canCall) external;
}

contract LZGovBridgeCrosschainTest is CrosschainTestBase {

    using DomainHelpers   for *;
    using LZBridgeTesting for *;

    uint32  constant ENDPOINT_ID_BASE = 30184;
    address constant ENDPOINT_BASE    = 0x1a44076050125825900e736c501f859c50fE728c;

    IChainLog constant chainlog = IChainLog(0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F);

    address govOappSender;

    GovernanceOAppReceiverMock govOappReceiver;

    function deployCrosschainPayload(IPayload targetPayload, address _bridgeReceiver)
        internal override returns (IPayload)
    {
        return IPayload(new LZGovBridgeCrosschainPayload(
            ENDPOINT_ID_BASE,
            govOappSender,
            _bridgeReceiver,
            targetPayload,
            _bridgeReceiver
        ));
    }

    function setupDomain() internal override {
        mainnet.selectFork();
        govOappSender = chainlog.getAddress("LZ_GOV_SENDER");

        remote = getChain('base').createFork();
        bridge = LZBridgeTesting.createLZBridge(mainnet, remote);

        uint256 nonce = vm.getNonce(address(this));
        address expectedGovOappReceiver   = vm.computeCreateAddress(address(this), nonce);
        address expectedGovBridgeReceiver = vm.computeCreateAddress(address(this), nonce + 1);

        // Configure GovernanceOAppSender on mainnet
        address govOwner = IGovOappSender(govOappSender).owner();
        vm.startPrank(govOwner);
        IGovOappSender(govOappSender).setPeer(
            ENDPOINT_ID_BASE,
            bytes32(uint256(uint160(expectedGovOappReceiver)))
        );
        IGovOappSender(govOappSender).setCanCallTarget(
            L1_SPARK_PROXY,
            ENDPOINT_ID_BASE,
            bytes32(uint256(uint160(expectedGovBridgeReceiver))),
            true
        );
        vm.stopPrank();

        vm.deal(L1_SPARK_PROXY, 0.01 ether);

        // Deploy destination contracts
        remote.selectFork();

        govOappReceiver = new GovernanceOAppReceiverMock(
            LZGovBridgeForwarder.ENDPOINT_ID_ETHEREUM,
            bytes32(uint256(uint160(govOappSender))),
            ENDPOINT_BASE,
            address(this)
        );
        assertEq(address(govOappReceiver), expectedGovOappReceiver);

        // bridgeExecutor will be deployed at nonce+2 by super.setUp()
        bridgeReceiver = address(new LZGovBridgeReceiver(
            address(govOappReceiver),
            LZGovBridgeForwarder.ENDPOINT_ID_ETHEREUM,
            L1_SPARK_PROXY,
            vm.computeCreateAddress(address(this), nonce + 2)
        ));
        assertEq(bridgeReceiver, expectedGovBridgeReceiver);
    }

    function relayMessagesAcrossBridge() internal override {
        bridge.relayMessagesToDestination(true, govOappSender, address(govOappReceiver));
    }

}
