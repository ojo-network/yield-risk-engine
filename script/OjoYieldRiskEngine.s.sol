// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/OjoYieldRiskEngineFactory.sol";
import "../src/OjoYieldRiskEngine.sol";

contract DeployOjoYieldRiskEngineFactory is Script {
    function run() external {
        uint256 creationFee = vm.envUint("CREATION_FEE");

        vm.startBroadcast();

        OjoYieldRiskEngineFactory factory = new OjoYieldRiskEngineFactory(creationFee);

        console.log("OjoYieldRiskEngineFactory deployed at:", address(factory));

        vm.stopBroadcast();
    }
}

contract CreateOjoYieldRiskEngine is Script {
    function run() external {
        address ojoYieldRiskEngineFactory = vm.envAddress("OJO_YIELD_RISK_ENGINE_FACTORY");
        address basePriceFeed = vm.envAddress("BASE_PRICE_FEED");
        uint256 yieldCap = vm.envUint("YIELD_CAP");
        uint256 creationFee = vm.envUint("CREATION_FEE");

        vm.startBroadcast();

        OjoYieldRiskEngineFactory factory = OjoYieldRiskEngineFactory(ojoYieldRiskEngineFactory);

        address riskEngine = factory.createOjoYieldRiskEngine{value: creationFee}(basePriceFeed, yieldCap);

        console.log("New OjoYieldRiskEngine created at:", riskEngine);

        vm.stopBroadcast();
    }
}
