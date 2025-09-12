// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {MinimalAccount} from "../src/ethereum/MinimalAccount.sol";

contract DeployMinimal is Script {
    function run() public {
        vm.startBroadcast();

        vm.stopBroadcast();
    }
}
