// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./OjoYieldRiskEngine.sol";

contract OjoYieldRiskEngineFactory {
    using Clones for address;

    address public immutable implementation;
    mapping(address => address) public OjoYieldRiskEngineAddresses;

    event OjoYieldRiskEngineCreated(address indexed feed);

    constructor() {
        implementation = address(new OjoYieldRiskEngine());
    }

    function createOjoYieldRiskEngine(
        address basePriceFeed,
        address quotePriceFeed,
        address yieldCapManager
    ) external returns (address ojoYieldRiskEngine) {
        ojoYieldRiskEngine = implementation.clone();
        OjoYieldRiskEngine(ojoYieldRiskEngine).initialize(basePriceFeed, quotePriceFeed, yieldCapManager);
        OjoYieldRiskEngineAddresses[msg.sender] = ojoYieldRiskEngine;
        emit OjoYieldRiskEngineCreated(ojoYieldRiskEngine);
    }
}
