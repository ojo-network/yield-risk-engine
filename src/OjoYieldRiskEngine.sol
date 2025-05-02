// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "./interfaces/AggregatorV2V3Interface.sol";
import {AggregatorV2V3Interface} from "./interfaces/AggregatorV2V3Interface.sol";
import {IOjoYieldCapManager} from "./interfaces/IOjoYieldCapManager.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract OjoYieldRiskEngine is AggregatorV3Interface, Initializable {
    uint256 private constant ONE = 1e18;

    string private riskEngineDescription;

    AggregatorV2V3Interface public BasePriceFeed;
    AggregatorV2V3Interface public QuotePriceFeed;
    IOjoYieldCapManager public OjoYieldCapManager;

    error GetRoundDataCanBeOnlyCalledWithLatestRound(uint80 requestedRoundId);

    function initialize(address _basePriceFeed, address _quotePriceFeed, address _yieldCapManager) public initializer {
        require(_basePriceFeed != address(0), "zero address");
        require(_quotePriceFeed != address(0), "zero address");
        require(_yieldCapManager != address(0), "zero address");

        AggregatorV2V3Interface basePriceFeed = AggregatorV2V3Interface(_basePriceFeed);
        AggregatorV2V3Interface quotePriceFeed = AggregatorV2V3Interface(_quotePriceFeed);

        require(
            basePriceFeed.decimals() == quotePriceFeed.decimals(),
            "basePriceFeed decimals not equal to quotePriceFeed decimals"
        );

        BasePriceFeed = basePriceFeed;
        QuotePriceFeed = quotePriceFeed;
        OjoYieldCapManager = IOjoYieldCapManager(_yieldCapManager);
        riskEngineDescription = string(abi.encodePacked("Ojo Yield Risk Engine ", BasePriceFeed.description()));
    }

    function latestRoundData()
        public
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (uint80 roundId, int256 rawAnswer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            BasePriceFeed.latestRoundData();

        answer = rawAnswer;

        (, int256 quoteAnswer,,,) = QuotePriceFeed.latestRoundData();

        uint256 yieldCap = OjoYieldCapManager.getYieldCap();

        int256 cappedAnswer = quoteAnswer + ((quoteAnswer * int256(yieldCap)) / int256(ONE));

        if (answer > cappedAnswer) {
            answer = cappedAnswer;
        }

        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }

    function getRoundData(
        uint80 _roundId
    )
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        if (_roundId != latestRound()) {
            revert GetRoundDataCanBeOnlyCalledWithLatestRound(_roundId);
        }
        return latestRoundData();
    }

    function latestRound() public view returns (uint80) {
        return uint80(AggregatorV2V3Interface(BasePriceFeed).latestRound());
    }

    function decimals() external view returns (uint8) {
        return AggregatorV2V3Interface(BasePriceFeed).decimals();
    }

    function description() external view returns (string memory) {
        return riskEngineDescription;
    }

    function version() external view returns (uint256) {
        return AggregatorV2V3Interface(BasePriceFeed).version();
    }
}
