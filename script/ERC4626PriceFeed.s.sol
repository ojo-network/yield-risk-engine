// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/ERC4626PriceFeed.sol";

contract DeployERC4626PriceFeed is Script {
    function run() external {
        address vault = vm.envAddress("VAULT_ADDRESS");
        string memory description = vm.envString("PRICE_FEED_DESCRIPTION");
        uint256 version = vm.envUint("PRICE_FEED_VERSION");

        vm.startBroadcast();

        ERC4626PriceFeed priceFeed = new ERC4626PriceFeed(vault, description, version);

        vm.stopBroadcast();

        console2.log("ERC4626PriceFeed deployed at:", address(priceFeed));
    }
}
