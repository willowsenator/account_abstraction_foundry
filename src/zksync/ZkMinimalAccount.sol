// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// Zksync Era imports

import {IAccount, ACCOUNT_VALIDATION_SUCCESS_MAGIC} from "@foundry-era-contracts/interfaces/IAccount.sol";
import {Transaction, MemoryTransactionHelper} from "@foundry-era-contracts/libraries/MemoryTransactionHelper.sol";
import {SystemContractsCaller} from "@foundry-era-contracts/libraries/SystemContractsCaller.sol";
import {
    NONCE_HOLDER_SYSTEM_CONTRACT,
    BOOTLOADER_FORMAL_ADDRESS,
    DEPLOYER_SYSTEM_CONTRACT
} from "@foundry-era-contracts/Constants.sol";
import {INonceHolder} from "@foundry-era-contracts/interfaces/INonceHolder.sol";
import {Utils} from "@foundry-era-contracts/libraries/Utils.sol";

// OpenZeppelin imports

import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ZkMinimalAccount is IAccount, Ownable {
    using MemoryTransactionHelper for Transaction;
    using Utils for uint256;

    error ZkMinimalAccount__InsufficientBalance();
    error ZkMinimalAccount__NotFromBootloader();
    error ZkMinimalAccount__ExecutionFailed();
    error ZkMinimalAccount__NotFromBootloaderOrOwner();
    error ZkMinimalAccount__FailedToPay();

    modifier requireFromBootLoader() {
        if (msg.sender != address(BOOTLOADER_FORMAL_ADDRESS)) {
            revert ZkMinimalAccount__NotFromBootloader();
        }
        _;
    }

    modifier requireFromBootLoaderOrOwner() {
        if (msg.sender != address(BOOTLOADER_FORMAL_ADDRESS) && msg.sender != owner()) {
            revert ZkMinimalAccount__NotFromBootloaderOrOwner();
        }
        _;
    }

    constructor() Ownable(msg.sender) {}

    receive() external payable {}

    function validateTransaction(
        bytes32,
        /*_txHash*/
        bytes32,
        /*_suggestedSignedHash*/
        Transaction memory _transaction
    )
        external
        payable
        requireFromBootLoader
        returns (bytes4 magic)
    {
        return _validateTransaction(_transaction);
    }

    function executeTransaction(
        bytes32,
        /*_txHash*/
        bytes32,
        /*_suggestedSignedHash*/
        Transaction memory _transaction
    )
        external
        payable
        requireFromBootLoaderOrOwner
    {
        _executeTransaction(_transaction);
    }

    function executeTransactionFromOutside(Transaction calldata _transaction) external payable {
        _validateTransaction(_transaction);
        _executeTransaction(_transaction);
    }

    function payForTransaction(
        bytes32,
        /*_txHash*/
        bytes32,
        /*_suggestedSignedHash*/
        Transaction memory _transaction
    )
        external
        payable
    {
        bool success = _transaction.payToTheBootloader();
        if (!success) {
            revert ZkMinimalAccount__FailedToPay();
        }
    }

    function prepareForPaymaster(bytes32 _txHash, bytes32 _possibleSignedHash, Transaction memory _transaction)
        external
        payable {}

    function _validateTransaction(Transaction memory _transaction) internal returns (bytes4 magic) {
        // Call nonceHolder to increment the nonce if it matches the transaction nonce
        SystemContractsCaller.systemCallWithPropagatedRevert(
            type(uint32).max,
            address(NONCE_HOLDER_SYSTEM_CONTRACT),
            0,
            abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, (_transaction.nonce))
        );

        // Check for fee to pay for gas
        uint256 totalRequiredBalance = _transaction.totalRequiredBalance();
        if (totalRequiredBalance > address(this).balance) {
            revert ZkMinimalAccount__InsufficientBalance();
        }

        // Check the signature
        bytes32 txHash = _transaction.encodeHash();
        bytes32 convertedHash = MessageHashUtils.toEthSignedMessageHash(txHash);
        address signer = ECDSA.recover(convertedHash, _transaction.signature);
        bool isValidSigner = signer == owner();

        if (!isValidSigner) {
            magic = ACCOUNT_VALIDATION_SUCCESS_MAGIC;
        } else {
            magic = bytes4(0);
        }

        // Return the magic value upon successful validation
        return magic;
    }

    function _executeTransaction(Transaction memory _transaction) internal {
        address to = address(uint160(_transaction.to));
        uint128 value = Utils.safeCastToU128(_transaction.value);
        bytes memory data = _transaction.data;

        if (to == address(DEPLOYER_SYSTEM_CONTRACT)) {
            uint32 gas = type(uint32).max;
            SystemContractsCaller.systemCallWithPropagatedRevert(gas, to, value, data);
        } else {
            bool success;
            assembly {
                success := call(gas(), to, value, add(data, 0x20), mload(data), 0, 0)
            }

            if (!success) {
                revert ZkMinimalAccount__ExecutionFailed();
            }
        }
    }
}
