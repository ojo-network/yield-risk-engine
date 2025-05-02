// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../src/OjoYieldRiskEngine.sol";
import "../src/OjoYieldRiskEngineFactory.sol";
import "../src/OjoYieldCapManager.sol";
import "./MockPriceFeed.sol";

contract OjoYieldRiskEngineTest is Test {
    OjoYieldRiskEngine public ojoYieldRiskEngine;
    OjoYieldRiskEngineFactory public factory;
    MockPriceFeed public basePriceFeed;
    MockPriceFeed public quotePriceFeed;
    OjoYieldCapManager public yieldCapManager;

    int256 constant INITIAL_BASE_PRICE = 103e16;
    int256 constant INITIAL_QUOTE_PRICE = 1e18;
    uint8 constant DECIMALS = 18;
    string constant DESCRIPTION = "STETH / ETH";
    uint256 constant VERSION = 1;
    uint256 constant YIELD_CAP = 5e16;

    function setUp() public {
        basePriceFeed = new MockPriceFeed(INITIAL_BASE_PRICE, DECIMALS, DESCRIPTION, VERSION);
        quotePriceFeed = new MockPriceFeed(INITIAL_QUOTE_PRICE, DECIMALS, DESCRIPTION, VERSION);
        yieldCapManager = new OjoYieldCapManager(YIELD_CAP);

        factory = new OjoYieldRiskEngineFactory();
        address riskEngineAddress =
            factory.createOjoYieldRiskEngine(address(basePriceFeed), address(quotePriceFeed), address(yieldCapManager));
        ojoYieldRiskEngine = OjoYieldRiskEngine(riskEngineAddress);
    }

    function testDescription() public {
        string memory description = ojoYieldRiskEngine.description();
        assertEq(description, "Ojo Yield Risk Engine STETH / ETH");
    }

    function testLatestRoundDataBelowYieldCap() public {
        (, int256 answer,,,) = ojoYieldRiskEngine.latestRoundData();

        (, int256 answer1,,,) = basePriceFeed.latestRoundData();

        // Verify that OjoPTFeed returns the base price
        assertEq(answer, answer1);
    }

    function testLatestRoundDataAboveYieldCap() public {
        // Update base price to a higher price than yield cap
        basePriceFeed.updateAnswer(18e17);

        (, int256 answer,,,) = ojoYieldRiskEngine.latestRoundData();

        (, int256 answer2,,,) = quotePriceFeed.latestRoundData();

        // Verify that OjoYieldRiskEngine returns price cap
        assertEq(answer, answer2 + int256(YIELD_CAP));
    }
}
