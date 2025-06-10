// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "./interfaces/AggregatorV2V3Interface.sol";
import {AggregatorV2V3Interface} from "./interfaces/AggregatorV2V3Interface.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UD60x18, wrap, unwrap} from "@prb/src/UD60x18.sol";

contract OjoYieldRiskEngineV2 is AggregatorV3Interface, Initializable {
    uint256 private constant ONE = 1e18;
    uint256 private constant SECONDS_PER_YEAR = 365 days;

    string private riskEngineDescription;
    AggregatorV2V3Interface public basePriceFeed;

    uint256 public annualYieldCap;

    uint256 public initialTimestamp;
    int256 public initialPrice;

    function initialize(address _basePriceFeed, uint256 _annualYieldCap) public initializer {
        require(_basePriceFeed != address(0), "zero address");
        require(_annualYieldCap > 0, "invalid yield cap");

        basePriceFeed = AggregatorV2V3Interface(_basePriceFeed);
        annualYieldCap = _annualYieldCap;

        (, int256 price,, uint256 timestamp,) = basePriceFeed.latestRoundData();
        require(price > 0, "invalid price feed answer");

        initialPrice = price;
        initialTimestamp = timestamp;

        riskEngineDescription = string(abi.encodePacked("Ojo Yield Risk Engine ", basePriceFeed.description()));
    }

    function _calculateMaxAllowedPrice(
        uint256 timestamp
    ) internal view returns (int256) {
        if (timestamp <= initialTimestamp) {
            return initialPrice;
        }

        uint256 timeElapsed = timestamp - initialTimestamp;
        uint256 t = (timeElapsed * ONE) / SECONDS_PER_YEAR; // Fixed-point year fraction

        // Base = 1 + r
        uint256 base = ONE + annualYieldCap;

        // growthFactor = (1 + r)^t
        UD60x18 baseUD = wrap(base);
        UD60x18 tUD = wrap(t);
        UD60x18 growthFactor = baseUD.pow(tUD);

        // maxPrice = initialPrice * growthFactor / 1e18
        return (initialPrice * int256(unwrap(growthFactor))) / int256(ONE);
    }

    function _capAnswer(int256 rawAnswer, uint256 timestamp) internal view returns (int256) {
        int256 maxAllowedPrice = _calculateMaxAllowedPrice(timestamp);
        return rawAnswer > maxAllowedPrice ? maxAllowedPrice : rawAnswer;
    }

    function getCurrentMaxAllowedPrice() external view returns (int256 maxPrice, uint256 currentYieldPercent) {
        (,,, uint256 latestTimestamp,) = basePriceFeed.latestRoundData();
        maxPrice = _calculateMaxAllowedPrice(latestTimestamp);

        if (latestTimestamp <= initialTimestamp) {
            return (maxPrice, 0);
        }

        uint256 timeElapsed = latestTimestamp - initialTimestamp;
        currentYieldPercent = (annualYieldCap * timeElapsed) / SECONDS_PER_YEAR;

        return (maxPrice, currentYieldPercent);
    }

    function latestRoundData()
        public
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (uint80 _roundId, int256 rawAnswer, uint256 _startedAt, uint256 _updatedAt, uint80 _answeredInRound) =
            basePriceFeed.latestRoundData();

        answer = _capAnswer(rawAnswer, _updatedAt);

        return (_roundId, answer, _startedAt, _updatedAt, _answeredInRound);
    }

    function getRoundData(
        uint80 _roundId
    )
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (uint80 _roundIdResult, int256 rawAnswer, uint256 _startedAt, uint256 _updatedAt, uint80 _answeredInRound) =
            basePriceFeed.getRoundData(_roundId);

        answer = _capAnswer(rawAnswer, _updatedAt);

        return (_roundIdResult, answer, _startedAt, _updatedAt, _answeredInRound);
    }

    function latestRound() public view returns (uint80) {
        return uint80(AggregatorV2V3Interface(basePriceFeed).latestRound());
    }

    function decimals() external view returns (uint8) {
        return AggregatorV2V3Interface(basePriceFeed).decimals();
    }

    function description() external view returns (string memory) {
        return riskEngineDescription;
    }

    function version() external view returns (uint256) {
        return AggregatorV2V3Interface(basePriceFeed).version();
    }
}
