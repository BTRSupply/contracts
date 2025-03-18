// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IInterchainTransferSent {
    event InterchainTransferSent(
        string destinationChain,
        string destinationContractAddress,
        address indexed sender,
        bytes recipient,
        address indexed token,
        uint256 amount
    );
}

interface IInterchainTransferReceived {
    event InterchainTransferReceived(
        string sourceChain,
        string sourceAddress,
        bytes sender,
        address indexed recipient,
        address indexed token,
        uint256 amount
    );
}
