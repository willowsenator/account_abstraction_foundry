// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {DeployMinimal} from "../../script/DeployMinimal.s.sol";
import {MinimalAccount} from "../../src/ethereum/MinimalAccount.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp, PackedUserOperation, IEntryPoint} from "../../script/SendPackedUserOp.s.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract MinimalAccountTest is Test {
    using MessageHashUtils for bytes32;

    DeployMinimal deployer;
    HelperConfig.NetworkConfig public activeNetworkConfig;
    MinimalAccount public minimalAccount;
    ERC20Mock public usdc;
    SendPackedUserOp public sendPackedUserOp;

    address randomUser = makeAddr("randomUser");

    uint256 constant AMOUNT = 1e18;

    function setUp() external {
        deployer = new DeployMinimal();
        (activeNetworkConfig, minimalAccount) = deployer.deployMinimalAccount();
        usdc = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOp();
    }

    function testOwnerCanExecuteCommands() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory funcData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        // Act
        vm.prank(minimalAccount.owner());
        minimalAccount.execute(dest, value, funcData);

        // Assert
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }

    function testNonOwnerCannotExecuteCommands() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory funcData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        // Act
        vm.prank(randomUser);
        vm.expectRevert(MinimalAccount.MinimalAccount__NotFromEntryPointOrOwner.selector);
        minimalAccount.execute(dest, value, funcData);
    }

    function testRecoverSignedOp() public view {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory funcData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, funcData);

        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generatedSignedUserOp(executeCallData, activeNetworkConfig, address(minimalAccount));
        bytes32 userOpHash = IEntryPoint(activeNetworkConfig.entryPoint).getUserOpHash(packedUserOp);
        // Act
        address currentSigner = ECDSA.recover(userOpHash.toEthSignedMessageHash(), packedUserOp.signature);

        // Assert
        assertEq(currentSigner, minimalAccount.owner());
    }

    // 1. Sign user ops
    // 2. Call validate userops
    // 3. Assert the return is correct
    function testValidationOfUserOps() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory funcData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, funcData);

        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generatedSignedUserOp(executeCallData, activeNetworkConfig, address(minimalAccount));
        bytes32 userOpHash = IEntryPoint(activeNetworkConfig.entryPoint).getUserOpHash(packedUserOp);
        uint256 missingAccountFunds = 1e18;

        vm.deal(address(minimalAccount), missingAccountFunds);

        // Act
        vm.prank(activeNetworkConfig.entryPoint);
        uint256 validationData = minimalAccount.validateUserOp(packedUserOp, userOpHash, missingAccountFunds);

        // Assert
        assertEq(validationData, 0);
    }

    function testEntryPointCanExecuteCommands() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory funcData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, funcData);

        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generatedSignedUserOp(executeCallData, activeNetworkConfig, address(minimalAccount));
        //bytes32 userOpHash = IEntryPoint(activeNetworkConfig.entryPoint).getUserOpHash(packedUserOp);
        uint256 missingAccountFunds = 1e18;

        vm.deal(address(minimalAccount), missingAccountFunds);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;

        // Act
        // EntryPoint v0.9 only accepts handleOps from an EOA that is also tx.origin
        vm.prank(randomUser, randomUser);
        IEntryPoint(activeNetworkConfig.entryPoint).handleOps(ops, payable(randomUser));

        // Assert
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }
}
