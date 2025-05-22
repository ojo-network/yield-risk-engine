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

    int256 constant INITIAL_BASE_PRICE = 206e16;
    int256 constant INITIAL_QUOTE_PRICE = 2e18;
    uint8 constant DECIMALS = 18;
    string constant BASE_DESCRIPTION = "STETH / USD";
    string constant QUOTE_DESCRIPTION = "ETH / USD";
    uint256 constant VERSION = 1;
    uint256 constant YIELD_CAP = 5e16;
    uint256 constant CREATION_FEE = 0.01 ether;
    uint256 constant ONE = 1e18;

    receive() external payable {}

    function setUp() public {
        basePriceFeed = new MockPriceFeed(INITIAL_BASE_PRICE, DECIMALS, BASE_DESCRIPTION, VERSION);
        quotePriceFeed = new MockPriceFeed(INITIAL_QUOTE_PRICE, DECIMALS, QUOTE_DESCRIPTION, VERSION);
        yieldCapManager = new OjoYieldCapManager(YIELD_CAP);

        factory = new OjoYieldRiskEngineFactory(CREATION_FEE);

        address riskEngineAddress = factory.createOjoYieldRiskEngine{value: CREATION_FEE}(
            address(basePriceFeed), address(quotePriceFeed), address(yieldCapManager)
        );

        ojoYieldRiskEngine = OjoYieldRiskEngine(riskEngineAddress);
    }

    function testDescription() public {
        string memory description = ojoYieldRiskEngine.description();
        assertEq(description, "Ojo Yield Risk Engine STETH / USD");
    }

    function testLatestRoundDataBelowYieldCap() public {
        (, int256 answer,,,) = ojoYieldRiskEngine.latestRoundData();

        (, int256 answer1,,,) = basePriceFeed.latestRoundData();

        // Verify that OjoYieldRiskEngine returns the base price
        assertEq(answer, answer1);
    }

    function testLatestRoundDataAboveYieldCap() public {
        // Update base price to a higher price than yield cap
        basePriceFeed.updateAnswer(211e16);

        (, int256 answer,,,) = ojoYieldRiskEngine.latestRoundData();

        (, int256 answer2,,,) = quotePriceFeed.latestRoundData();

        // Verify that OjoYieldRiskEngine returns price cap
        assertEq(answer, answer2 + ((answer2 * int256(YIELD_CAP)) / int256(ONE)));
    }
}
