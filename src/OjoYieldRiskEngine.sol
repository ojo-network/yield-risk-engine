// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "./interfaces/AggregatorV2V3Interface.sol";
import {AggregatorV2V3Interface} from "./interfaces/AggregatorV2V3Interface.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract OjoYieldRiskEngine is AggregatorV3Interface, Initializable {
    uint256 private constant ONE = 1e18;

    string private riskEngineDescription;

    AggregatorV2V3Interface public BasePriceFeed;
    uint256 public yieldCap;
    int256 public cappedAnswer;

    function initialize(address _basePriceFeed, uint256 _yieldCap) public initializer {
        require(_basePriceFeed != address(0), "zero address");

        AggregatorV2V3Interface basePriceFeed = AggregatorV2V3Interface(_basePriceFeed);

        BasePriceFeed = basePriceFeed;
        yieldCap = _yieldCap;

        (, int256 answer,,,) = BasePriceFeed.latestRoundData();
        require(answer > 0, "invalid price feed answer");

        cappedAnswer = answer + ((answer * int256(yieldCap)) / int256(ONE));

        riskEngineDescription = string(abi.encodePacked("Ojo Yield Risk Engine ", BasePriceFeed.description()));
    }

    function _capAnswer(
        int256 rawAnswer
    ) internal view returns (int256) {
        if (rawAnswer > cappedAnswer) {
            return cappedAnswer;
        }
        return rawAnswer;
    }

    function latestRoundData()
        public
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (uint80 _roundId, int256 rawAnswer, uint256 _startedAt, uint256 _updatedAt, uint80 _answeredInRound) =
            BasePriceFeed.latestRoundData();

        answer = _capAnswer(rawAnswer);

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
            BasePriceFeed.getRoundData(_roundId);

        answer = _capAnswer(rawAnswer);

        return (_roundIdResult, answer, _startedAt, _updatedAt, _answeredInRound);
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
