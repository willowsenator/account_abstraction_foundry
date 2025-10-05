// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IAccount} from "@foundry-era-contracts/interfaces/IAccount.sol";
import {Transaction} from "@foundry-era-contracts/libraries/MemoryTransactionHelper.sol";

contract ZkMinimalAccount is IAccount {
    function validateTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction memory _transaction)
        external
        payable
        returns (bytes4 magic)
    {
        
    }

    function executeTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction memory _transaction)
        external
        payable
    {}

    function executeTransactionFromOutside(Transaction calldata _transaction) external payable {}

    function payForTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction memory _transaction)
        external
        payable
    {}

    function prepareForPaymaster(bytes32 _txHash, bytes32 _possibleSignedHash, Transaction memory _transaction)
        external
        payable
    {}
}
