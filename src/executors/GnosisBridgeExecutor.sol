// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import {BridgeExecutorBase} from './BridgeExecutorBase.sol';

interface IAMB {
    function messageSender() external view returns (address);

    function messageSourceChainId() external view returns (bytes32);
}

/**
 * @title GnosisBridgeExecutor
 * @author Gnosis
 * @notice Implementation of the AMB Bridge Executor, able to receive cross-chain transactions from Ethereum
 * @dev Queuing an ActionsSet into this Executor can only be done by the AMB contract and must be from the designated
 * controller from the correct origin chain.
 */
contract GnosisBridgeExecutor is BridgeExecutorBase {
    error UnauthorizedAMB();
    error UnauthorizedChainId();
    error UnauthorizedController();

    /**
     * @dev Emitted when Amb address is updated
     * @param oldAmbAddress the old address
     * @param newAmbAddress the new address
     **/
    event AmbAddressUpdated(
        address indexed oldAmbAddress,
        address indexed newAmbAddress
    );

    /**
     * @dev Emitted when controller address is updated
     * @param oldControllerAddress the old address
     * @param newControllerAddress the new address
     **/
    event ControllerUpdated(
        address indexed oldControllerAddress,
        address indexed newControllerAddress
    );

    /**
     * @dev Emitted when chainId is updated
     * @param oldChainIdAddress the old Id
     * @param newChainIdAddress the new Id
     **/
    event ChainIdUpdated(
        bytes32 indexed oldChainIdAddress,
        bytes32 indexed newChainIdAddress
    );

    // Address of the AMB contract forwarding the cross-chain transaction from Ethereum
    IAMB public amb;
    // Address of the orginating sender of the message
    address public controller;
    // Chain ID of the origin
    bytes32 public chainId;

    /**
     * @dev Check that the amb, chainId, and owner are valid
     **/
    modifier onlyValid() {
        if (msg.sender != address(amb)) revert UnauthorizedAMB();
        if (amb.messageSourceChainId() != chainId) revert UnauthorizedChainId();
        if (amb.messageSender() != controller) revert UnauthorizedController();
        _;
    }

    /**
     * @dev Constructor
     * @param _amb The AMB contract on the foreign chain
     * @param _controller Address of the authorized controller contract on the other side of the bridge
     * @param _chainId Address of the authorized chainId from which owner can initiate transactions
     * @param delay The delay before which an actions set can be executed
     * @param gracePeriod The time period after a delay during which an actions set can be executed
     * @param minimumDelay The minimum bound a delay can be set to
     * @param maximumDelay The maximum bound a delay can be set to
     * @param guardian The address of the guardian, which can cancel queued proposals (can be zero)
     */
    constructor(
        IAMB _amb,
        address _controller,
        bytes32 _chainId,
        uint256 delay,
        uint256 gracePeriod,
        uint256 minimumDelay,
        uint256 maximumDelay,
        address guardian
    )
        BridgeExecutorBase(
            delay,
            gracePeriod,
            minimumDelay,
            maximumDelay,
            guardian
        )
    {
        amb = _amb;
        controller = _controller;
        chainId = _chainId;
    }

    /**
     * @notice Queue an ActionsSet
     * @dev If a signature is empty, calldata is used for the execution, calldata is appended to signature otherwise
     * @param targets Array of targets to be called by the actions set
     * @param values Array of values to pass in each call by the actions set
     * @param signatures Array of function signatures to encode in each call by the actions (can be empty)
     * @param calldatas Array of calldata to pass in each call by the actions set
     * @param withDelegatecalls Array of whether to delegatecall for each call of the actions set
     **/
    function queue(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        bool[] memory withDelegatecalls
    ) external onlyValid {
        _queue(targets, values, signatures, calldatas, withDelegatecalls);
    }

    /// @dev Set the AMB contract address
    /// @param _amb Address of the AMB contract
    /// @notice This can only be called by this contract
    function setAmb(address _amb) public onlyThis {
        require(address(amb) != _amb, 'AMB address already set to this');
        emit AmbAddressUpdated(address(amb), _amb);
        amb = IAMB(_amb);
    }

    /// @dev Set the approved chainId
    /// @param _chainId ID of the approved network
    /// @notice This can only be called by this contract
    function setChainId(bytes32 _chainId) public onlyThis {
        require(chainId != _chainId, 'chainId already set to this');
        emit ChainIdUpdated(chainId, _chainId);
        chainId = _chainId;
    }

    /// @dev Set the controller address
    /// @param _controller Set the address of controller on the other side of the bridge
    /// @notice This can only be called by this contract
    function setController(address _controller) public onlyThis {
        require(controller != _controller, 'controller already set to this');
        emit ControllerUpdated(controller, _controller);
        controller = _controller;
    }
}
