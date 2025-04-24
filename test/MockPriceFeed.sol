// src/test/MockAggregator.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import "../src/interfaces/AggregatorV2V3Interface.sol";

contract MockPriceFeed is AggregatorV2V3Interface {
    struct RoundData {
        int256 answer;
        uint256 timestamp;
    }

    mapping(uint80 => RoundData) private rounds;
    uint80 private currentRoundId;
    uint8 private decimalsValue;
    string private descriptionValue;
    uint256 private versionValue;

    constructor(int256 _initialAnswer, uint8 _decimals, string memory _description, uint256 _version) {
        currentRoundId = 1; // Start from round 1
        rounds[currentRoundId] = RoundData({answer: _initialAnswer, timestamp: block.timestamp});
        decimalsValue = _decimals;
        descriptionValue = _description;
        versionValue = _version;
    }

    function latestAnswer() external view override returns (int256) {
        return rounds[currentRoundId].answer;
    }

    function latestTimestamp() external view override returns (uint256) {
        return rounds[currentRoundId].timestamp;
    }

    function latestRound() external view override returns (uint256) {
        return currentRoundId;
    }

    function getAnswer(
        uint256 _roundId
    ) external view override returns (int256) {
        require(rounds[uint80(_roundId)].timestamp != 0, "No data present");
        return rounds[uint80(_roundId)].answer;
    }

    function getTimestamp(
        uint256 _roundId
    ) external view override returns (uint256) {
        require(rounds[uint80(_roundId)].timestamp != 0, "No data present");
        return rounds[uint80(_roundId)].timestamp;
    }

    function getRoundData(
        uint80 _roundId
    )
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        require(rounds[_roundId].timestamp != 0, "No data present");
        RoundData memory roundData = rounds[_roundId];
        return (_roundId, roundData.answer, roundData.timestamp, roundData.timestamp, _roundId);
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (
            currentRoundId,
            rounds[currentRoundId].answer,
            rounds[currentRoundId].timestamp,
            rounds[currentRoundId].timestamp,
            currentRoundId
        );
    }

    function decimals() external view override returns (uint8) {
        return decimalsValue;
    }

    function description() external view override returns (string memory) {
        return descriptionValue;
    }

    function version() external view override returns (uint256) {
        return versionValue;
    }

    function updateAnswer(
        int256 _newAnswer
    ) external {
        currentRoundId++;
        rounds[currentRoundId] = RoundData({answer: _newAnswer, timestamp: block.timestamp});
    }
}
