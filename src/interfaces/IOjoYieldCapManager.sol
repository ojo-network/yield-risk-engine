// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.22;

/**
 * @title IOjoYieldCapManager
 * @notice Interface for managing yield caps
 * @dev This interface provides functionality to retrieve yield cap values
 */
interface IOjoYieldCapManager {
    /**
     * @notice Returns the current yield cap value
     * @return The yield cap value in 1e18 precision
     */
    function getYieldCap() external view returns (uint256);
}
