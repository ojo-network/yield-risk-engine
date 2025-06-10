// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/OjoYieldRiskEngineV2.sol";
import "../src/OjoYieldRiskEngineFactoryV2.sol";
import "./MockPriceFeed.sol";
import {UD60x18, wrap, unwrap} from "@prb/src/UD60x18.sol";

contract OjoYieldRiskEngineV2Test is Test {
    OjoYieldRiskEngineV2 public ojoYieldRiskEngine;
    OjoYieldRiskEngineFactoryV2 public factory;
    MockPriceFeed public basePriceFeed;

    int256 constant INITIAL_BASE_PRICE = 1e18;
    uint8 constant DECIMALS = 18;
    string constant BASE_DESCRIPTION = "STETH / ETH";
    uint256 constant VERSION = 1;
    uint256 constant ANNUAL_YIELD_CAP = 3e16; // 3% annual yield cap
    uint256 constant ONE = 1e18;
    uint256 constant SECONDS_PER_YEAR = 365 days;

    function setUp() public {
        basePriceFeed = new MockPriceFeed(INITIAL_BASE_PRICE, DECIMALS, BASE_DESCRIPTION, VERSION);
        factory = new OjoYieldRiskEngineFactoryV2(0, 0, 0);

        factory.acceptTerms();
        address riskEngineAddress = factory.createOjoYieldRiskEngine{value: 0}(address(basePriceFeed), ANNUAL_YIELD_CAP);
        ojoYieldRiskEngine = OjoYieldRiskEngineV2(riskEngineAddress);
    }

    function testInitialState() public {
        assertEq(address(ojoYieldRiskEngine.basePriceFeed()), address(basePriceFeed));
        assertEq(ojoYieldRiskEngine.annualYieldCap(), ANNUAL_YIELD_CAP);
        assertEq(ojoYieldRiskEngine.initialPrice(), INITIAL_BASE_PRICE);
        assertTrue(ojoYieldRiskEngine.initialTimestamp() > 0);
    }

    function testDescription() public {
        string memory description = ojoYieldRiskEngine.description();
        assertEq(description, "Ojo Yield Risk Engine STETH / ETH");
    }

    function testLatestRoundDataBelowYieldCap() public {
        (, int256 answer,,,) = ojoYieldRiskEngine.latestRoundData();
        assertEq(answer, INITIAL_BASE_PRICE);
    }

    function testLatestRoundDataAboveYieldCapImmediately() public {
        // Update base price to 5% higher immediately (should be capped at initial price)
        basePriceFeed.updateAnswer(105e16); // 1.05 ETH

        (, int256 answer,,,) = ojoYieldRiskEngine.latestRoundData();
        assertEq(answer, INITIAL_BASE_PRICE);
    }

    function testLatestRoundDataWithTimeProgress() public {
        // Fast forward 6 months
        skip(182 days);

        // Update price feed to get new timestamp
        basePriceFeed.updateAnswer(INITIAL_BASE_PRICE);

        // Calculate expected max price after 6 months using compound interest
        uint256 timeElapsed = 182 days;
        uint256 t = (timeElapsed * ONE) / SECONDS_PER_YEAR;
        uint256 base = ONE + ANNUAL_YIELD_CAP;

        UD60x18 baseUD = wrap(base);
        UD60x18 tUD = wrap(t);
        UD60x18 growthFactor = baseUD.pow(tUD);
        int256 expectedMaxPrice = (INITIAL_BASE_PRICE * int256(unwrap(growthFactor))) / int256(ONE);

        // Test price slightly below cap
        int256 priceBelow = expectedMaxPrice - 1e16;
        basePriceFeed.updateAnswer(priceBelow);
        (, int256 answer,,,) = ojoYieldRiskEngine.latestRoundData();
        assertEq(answer, priceBelow);

        // Test price above cap
        basePriceFeed.updateAnswer(expectedMaxPrice + 1e16);
        (, answer,,,) = ojoYieldRiskEngine.latestRoundData();
        assertEq(answer, expectedMaxPrice);
    }

    function testLatestRoundDataAfterOneYear() public {
        // Fast forward 1 year
        skip(365 days);

        // Update price feed to get new timestamp
        basePriceFeed.updateAnswer(INITIAL_BASE_PRICE);

        // Calculate expected max price after 1 year using compound interest
        uint256 base = ONE + ANNUAL_YIELD_CAP;
        UD60x18 baseUD = wrap(base);
        UD60x18 tUD = wrap(ONE);
        UD60x18 growthFactor = baseUD.pow(tUD);
        int256 expectedMaxPrice = (INITIAL_BASE_PRICE * int256(unwrap(growthFactor))) / int256(ONE);

        // Test price at exactly the cap
        basePriceFeed.updateAnswer(expectedMaxPrice);
        (, int256 answer,,,) = ojoYieldRiskEngine.latestRoundData();
        assertEq(answer, expectedMaxPrice);

        // Test price above cap
        basePriceFeed.updateAnswer(expectedMaxPrice + 1e16);
        (, answer,,,) = ojoYieldRiskEngine.latestRoundData();
        assertEq(answer, expectedMaxPrice);
    }

    function testGetCurrentMaxAllowedPrice() public {
        // Test at initialization
        (int256 maxPrice, uint256 currentYield) = ojoYieldRiskEngine.getCurrentMaxAllowedPrice();
        assertEq(maxPrice, INITIAL_BASE_PRICE);
        assertEq(currentYield, 0);

        // Test after 6 months
        skip(182 days);
        // Update price feed to get new timestamp
        basePriceFeed.updateAnswer(INITIAL_BASE_PRICE);

        (maxPrice, currentYield) = ojoYieldRiskEngine.getCurrentMaxAllowedPrice();

        // Calculate expected values after 6 months
        uint256 timeElapsed = 182 days;
        uint256 expectedYield = (ANNUAL_YIELD_CAP * timeElapsed) / SECONDS_PER_YEAR;

        uint256 t = (timeElapsed * ONE) / SECONDS_PER_YEAR;
        uint256 base = ONE + ANNUAL_YIELD_CAP;
        UD60x18 baseUD = wrap(base);
        UD60x18 tUD = wrap(t);
        UD60x18 growthFactor = baseUD.pow(tUD);
        int256 expectedMaxPrice = (INITIAL_BASE_PRICE * int256(unwrap(growthFactor))) / int256(ONE);

        assertEq(maxPrice, expectedMaxPrice);
        assertEq(currentYield, expectedYield);

        // Test after 1 year
        skip(183 days); // Complete the year
        // Update price feed to get new timestamp
        basePriceFeed.updateAnswer(INITIAL_BASE_PRICE);

        (maxPrice, currentYield) = ojoYieldRiskEngine.getCurrentMaxAllowedPrice();

        base = ONE + ANNUAL_YIELD_CAP;
        baseUD = wrap(base);
        tUD = wrap(ONE);
        growthFactor = baseUD.pow(tUD);
        expectedMaxPrice = (INITIAL_BASE_PRICE * int256(unwrap(growthFactor))) / int256(ONE);

        assertEq(maxPrice, expectedMaxPrice);
        assertEq(currentYield, ANNUAL_YIELD_CAP);
    }

    function testGetRoundData() public {
        // Fast forward 6 months
        skip(182 days);

        // Update price feed to get new timestamp
        basePriceFeed.updateAnswer(INITIAL_BASE_PRICE);

        // Update price and get the round ID
        basePriceFeed.updateAnswer(105e16); // 1.05 ETH
        uint80 roundId = uint80(basePriceFeed.latestRound());

        // Calculate expected max price
        uint256 timeElapsed = 182 days;
        uint256 t = (timeElapsed * ONE) / SECONDS_PER_YEAR;
        uint256 base = ONE + ANNUAL_YIELD_CAP;
        UD60x18 baseUD = wrap(base);
        UD60x18 tUD = wrap(t);
        UD60x18 growthFactor = baseUD.pow(tUD);
        int256 expectedMaxPrice = (INITIAL_BASE_PRICE * int256(unwrap(growthFactor))) / int256(ONE);

        // Get round data and verify capping
        (uint80 returnedRoundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            ojoYieldRiskEngine.getRoundData(roundId);

        assertEq(returnedRoundId, roundId);
        assertEq(answer, expectedMaxPrice);
        assertTrue(startedAt > 0);
        assertTrue(updatedAt > 0);
        assertEq(answeredInRound, roundId);
    }

    function testFactoryDeployment() public {
        // Get the first engine address for this deployer
        address engineAddress = factory.OjoYieldRiskEngineAddresses(address(this), 0);
        assertEq(engineAddress, address(ojoYieldRiskEngine));
    }
}
