// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
contract HelperConfig is Script{
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        address entryPoint;
        address account;
    }

    uint constant ETH_SEPOLIA_CHAINID = 11155111;
    uint constant ZSYNC_SEPOLIA_CHAINID = 300;
    uint constant LOCAL_CHAINID = 31337;
    address constant BURNER_WALLET;

    NetworkConfig public activeNetworkConfig;

    mapping(uint chainid => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAINID] = getEthSepoliaConfig();
        networkConfigs[ZSYNC_SEPOLIA_CHAINID] = getZsyncSepoliaConfig();
        
    }

    function getConfig() public view returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(uint chainId) public view returns (NetworkConfig memory) {
        if(chainId == LOCAL_CHAINID) {
            return getOrCreateAnvilConfig();
        } else if(networkConfigs[chainId].account != address(0)) {
            return networkConfigs[chainId];
        }
        return networkConfigs[chainId];
    }

    function getEthSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryPoint: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789,
            account: BURNER_WALLET
        });
    }

    function getZsyncSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryPoint: address(0),
            account: BURNER_WALLET
        });
    }

    

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if(activeNetworkConfig.account != address(0)) {
            return activeNetworkConfig;
        }

      // Deploy EntryPoint
    }
}