// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/OjoYieldRiskEngineFactoryV2.sol";
import "../src/OjoYieldRiskEngineV2.sol";

contract DeployOjoYieldRiskEngineFactoryV2 is Script {
    function run() external {
        uint256 baseFee = vm.envUint("BASE_FEE");
        uint256 feeIncrement = vm.envUint("FEE_INCREMENT");
        uint256 maxFee = vm.envUint("MAX_FEE");

        vm.startBroadcast();

        OjoYieldRiskEngineFactoryV2 factory = new OjoYieldRiskEngineFactoryV2(baseFee, feeIncrement, maxFee);

        console.log("OjoYieldRiskEngineFactoryV2 deployed at:", address(factory));

        vm.stopBroadcast();
    }
}

contract CreateOjoYieldRiskEngineV2 is Script {
    function run() external {
        address ojoYieldRiskEngineFactory = vm.envAddress("OJO_YIELD_RISK_ENGINE_FACTORY");
        address basePriceFeed = vm.envAddress("BASE_PRICE_FEED");
        uint256 yieldCap = vm.envUint("YIELD_CAP");
        uint256 creationFee = vm.envUint("CREATION_FEE");

        vm.startBroadcast();

        OjoYieldRiskEngineFactoryV2 factory = OjoYieldRiskEngineFactoryV2(ojoYieldRiskEngineFactory);

        address riskEngine = factory.createOjoYieldRiskEngine{value: creationFee}(basePriceFeed, yieldCap);

        console.log("New OjoYieldRiskEngine created at:", riskEngine);

        vm.stopBroadcast();
    }
}
