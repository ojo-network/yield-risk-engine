// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/ERC4626PriceFeedFactory.sol";
import "../src/ERC4626PriceFeed.sol";

contract DeployERC4626PriceFeedFactory is Script {
    function run() external {
        vm.startBroadcast();

        ERC4626PriceFeedFactory factory = new ERC4626PriceFeedFactory();

        vm.stopBroadcast();

        console2.log("ERC4626PriceFeedFactory deployed at:", address(factory));
    }
}

contract CreateERC4626PriceFeed is Script {
    function run() external {
        address factory = vm.envAddress("FACTORY_ADDRESS");
        address vault = vm.envAddress("VAULT_ADDRESS");
        string memory description = vm.envString("PRICE_FEED_DESCRIPTION");

        vm.startBroadcast();

        address priceFeed = ERC4626PriceFeedFactory(factory).createPriceFeed(vault, description);

        vm.stopBroadcast();

        console2.log("ERC4626PriceFeed created at:", priceFeed);
    }
}
