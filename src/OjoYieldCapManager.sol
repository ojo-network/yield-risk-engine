// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.22;

import {IOjoYieldCapManager} from "./interfaces/IOjoYieldCapManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title YieldCapManager
 * @notice Manages the yield cap for the OjoYieldRiskEngine
 * @dev This contract allows the owner to set and update the yield cap
 */
contract OjoYieldCapManager is IOjoYieldCapManager, Ownable {
    uint256 private yieldCap;

    event YieldCapUpdated(uint256 oldYieldCap, uint256 newYieldCap);

    /**
     * @notice Constructor that sets the initial yield cap
     * @param _initialYieldCap The initial yield cap value (in 1e18 precision)
     */
    constructor(
        uint256 _initialYieldCap
    ) Ownable(msg.sender) {
        yieldCap = _initialYieldCap;
        emit YieldCapUpdated(0, _initialYieldCap);
    }

    /**
     * @notice Returns the current yield cap value
     * @return The yield cap value in 1e18 precision
     */
    function getYieldCap() external view returns (uint256) {
        return yieldCap;
    }

    /**
     * @notice Updates the yield cap value
     * @param _newYieldCap The new yield cap value (in 1e18 precision)
     * @dev Only callable by the contract owner
     */
    function updateYieldCap(
        uint256 _newYieldCap
    ) external onlyOwner {
        uint256 oldYieldCap = yieldCap;
        yieldCap = _newYieldCap;
        emit YieldCapUpdated(oldYieldCap, _newYieldCap);
    }
}
