// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/OjoYieldRiskEngineFactory.sol";
import "../src/OjoYieldRiskEngine.sol";
import "../src/OjoYieldCapManager.sol";

contract DeployOjoYieldRiskEngineFactory is Script {
    function run() external {
        vm.startBroadcast();

        OjoYieldRiskEngineFactory factory = new OjoYieldRiskEngineFactory();

        console.log("OjoYieldRiskEngineFactory deployed at:", address(factory));

        vm.stopBroadcast();
    }
}

contract DeployOjoYieldCapManager is Script {
    function run() external {
        uint256 yieldCap = vm.envUint("YIELD_CAP");

        vm.startBroadcast();

        OjoYieldCapManager yieldCapManager = new OjoYieldCapManager(yieldCap);

        console.log("OjoYieldCapManager deployed at:", address(yieldCapManager));
        console.log("Initial yield cap set to:", yieldCap);

        vm.stopBroadcast();
    }
}

contract CreateOjoYieldRiskEngine is Script {
    function run() external {
        address ojoYieldRiskEngineFactory = vm.envAddress("OJO_YIELD_RISK_ENGINE_FACTORY");
        address basePriceFeed = vm.envAddress("BASE_PRICE_FEED");
        address quotePriceFeed = vm.envAddress("QUOTE_PRICE_FEED");
        address yieldCapManager = vm.envAddress("YIELD_CAP_MANAGER");

        vm.startBroadcast();

        OjoYieldRiskEngineFactory factory = OjoYieldRiskEngineFactory(ojoYieldRiskEngineFactory);

        address riskEngine = factory.createOjoYieldRiskEngine(basePriceFeed, quotePriceFeed, yieldCapManager);

        console.log("New OjoYieldRiskEngine created at:", riskEngine);

        vm.stopBroadcast();
    }
}
