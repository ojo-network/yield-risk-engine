// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./OjoYieldRiskEngine.sol";

contract OjoYieldRiskEngineFactory is Ownable {
    using Clones for address;

    address public immutable implementation;
    mapping(address => address) public OjoYieldRiskEngineAddresses;

    uint256 public creationFee;
    address public feeRecipient;

    event OjoYieldRiskEngineCreated(address indexed feed);
    event FeeUpdated(uint256 newFee);
    event FeeRecipientUpdated(address newFeeRecipient);

    constructor(
        uint256 creationFee_
    ) Ownable(msg.sender) {
        implementation = address(new OjoYieldRiskEngine());
        feeRecipient = msg.sender;
        creationFee = creationFee_;
    }

    /**
     * @notice Creates a new OjoYieldRiskEngine instance
     * @dev Clones the implementation contract and initializes it with the provided parameters
     * @param basePriceFeed Address of the price feed for the base asset
     * @param quotePriceFeed Address of the price feed for the quote asset
     * @param yieldCapManager Address of the yield cap manager contract
     * @return ojoYieldRiskEngine Address of the newly created OjoYieldRiskEngine instance
     * @custom:requires The caller must send at least the required creation fee
     * @custom:emits OjoYieldRiskEngineCreated when a new engine is created
     * @dev Any excess ETH sent above the creation fee will be refunded to the caller
     */
    function createOjoYieldRiskEngine(
        address basePriceFeed,
        address quotePriceFeed,
        address yieldCapManager
    ) external payable returns (address ojoYieldRiskEngine) {
        require(msg.value >= creationFee, "insufficient fee");

        ojoYieldRiskEngine = implementation.clone();
        OjoYieldRiskEngine(ojoYieldRiskEngine).initialize(basePriceFeed, quotePriceFeed, yieldCapManager);
        OjoYieldRiskEngineAddresses[msg.sender] = ojoYieldRiskEngine;

        if (creationFee > 0) {
            (bool success,) = feeRecipient.call{value: creationFee}("");
            require(success, "fee transfer failed");

            uint256 refund = msg.value - creationFee;
            if (refund > 0) {
                (bool refundSuccess,) = msg.sender.call{value: refund}("");
                require(refundSuccess, "refund failed");
            }
        }

        emit OjoYieldRiskEngineCreated(ojoYieldRiskEngine);
    }

    function setCreationFee(
        uint256 _newFee
    ) external onlyOwner {
        creationFee = _newFee;
        emit FeeUpdated(_newFee);
    }

    function setFeeRecipient(
        address _newRecipient
    ) external onlyOwner {
        require(_newRecipient != address(0), "zero address");
        feeRecipient = _newRecipient;
        emit FeeRecipientUpdated(_newRecipient);
    }
}
