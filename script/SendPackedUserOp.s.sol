// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MinimalAccount} from "../src/ethereum/MinimalAccount.sol";
import {console2} from "forge-std/console2.sol";

contract SendPackedUserOp is Script {
    using MessageHashUtils for bytes32;

    function run() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        address dest = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8; // USDC Sepolia
        uint256 value = 0;
        bytes memory functData = abi.encodeWithSelector(IERC20.approve.selector, dest, 1e18);
        bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functData);

        address deployed = vm.envAddress("MINIMAL_ACCOUNT_ADDRESS");
        require(deployed != address(0), "MINIMAL_ACCOUNT_ADDRESS not set");
        console2.log("Using deployed account:", deployed);
        PackedUserOperation memory userOp = generatedSignedUserOp(executeCallData, config, deployed);
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        vm.startBroadcast();
        IEntryPoint entryPoint = IEntryPoint(config.entryPoint);
        entryPoint.handleOps(ops, payable(config.account));
        vm.stopBroadcast();
    }

    function generatedSignedUserOp(
        bytes memory callData,
        HelperConfig.NetworkConfig memory config,
        address minimalAccount
    ) public view returns (PackedUserOperation memory) {
        // 1. Generate unsigned data
        uint256 nonce = IEntryPoint(config.entryPoint).getNonce(minimalAccount, 0);
        PackedUserOperation memory userOp = _generateUnsignedUserOp(callData, minimalAccount, nonce);

        // 2. Get UserOpHash
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOp);
        bytes32 digest = userOpHash.toEthSignedMessageHash();

        // 3: Sign it, and return it
        uint8 v;
        bytes32 r;
        bytes32 s;

        if (block.chainid == 31337) {
            uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
            (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
        } else {
            uint256 pk = vm.envUint("OWNER_PRIVATE_KEY");
            require(pk != 0, "Owner key not set in env");
            (v, r, s) = vm.sign(pk, digest);
        }

        userOp.signature = abi.encodePacked(r, s, v); // Note the order
        return userOp;
    }

    function _generateUnsignedUserOp(bytes memory callData, address sender, uint256 nonce)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        uint128 verificationGasLimit = 300000;
        uint128 callGasLimit = verificationGasLimit;
        uint128 maxPriorityFeePerGas = 1;
        uint128 maxFeePerGas = maxPriorityFeePerGas;
        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"",
            callData: callData,
            accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | callGasLimit),
            preVerificationGas: verificationGasLimit,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeePerGas),
            paymasterAndData: hex"",
            signature: hex""
        });
    }
}
