// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AggregatorV2V3Interface} from "./interfaces/AggregatorV2V3Interface.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract ERC4626PriceFeed is AggregatorV2V3Interface {
    IERC4626 public immutable vault;
    uint8 private immutable decimalsValue;
    string private descriptionValue;
    uint256 private immutable versionValue;
    uint80 private immutable currentRoundId;

    constructor(address _vault, string memory _description, uint256 _version) {
        require(_vault != address(0), "zero address");
        vault = IERC4626(_vault);
        decimalsValue = IERC20Metadata(vault.asset()).decimals();
        descriptionValue = _description;
        versionValue = _version;
        currentRoundId = 1;
    }

    function latestAnswer() external view override returns (int256) {
        return int256(vault.convertToAssets(1e18));
    }

    function latestTimestamp() external view override returns (uint256) {
        return block.timestamp;
    }

    function latestRound() external view override returns (uint256) {
        return currentRoundId;
    }

    function getAnswer(
        uint256 _roundId
    ) external view override returns (int256) {
        require(_roundId <= currentRoundId, "No data present");
        return int256(vault.convertToAssets(1e18));
    }

    function getTimestamp(
        uint256 _roundId
    ) external view override returns (uint256) {
        require(_roundId <= currentRoundId, "No data present");
        return block.timestamp;
    }

    function getRoundData(
        uint80 _roundId
    )
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        require(_roundId <= currentRoundId, "No data present");
        return (_roundId, int256(vault.convertToAssets(1e18)), block.timestamp, block.timestamp, _roundId);
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (currentRoundId, int256(vault.convertToAssets(1e18)), block.timestamp, block.timestamp, currentRoundId);
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
}
