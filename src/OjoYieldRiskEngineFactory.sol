// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./OjoYieldRiskEngine.sol";

contract OjoYieldRiskEngineFactory is Ownable {
    using Clones for address;

    address public immutable implementation;
    mapping(address => address) public OjoYieldRiskEngineAddresses;
    mapping(address => bool) public termsAccepted;

    uint256 public creationFee;
    address public feeRecipient;
    uint8 public freeDeploymentsRemaining;

    event OjoYieldRiskEngineCreated(address indexed feed);
    event FeeUpdated(uint256 indexed newFee);
    event FeeRecipientUpdated(address indexed newFeeRecipient);
    event TermsAccepted(address indexed user);

    constructor(
        uint256 creationFee_
    ) Ownable(msg.sender) {
        implementation = address(new OjoYieldRiskEngine());
        feeRecipient = msg.sender;
        creationFee = creationFee_;
        freeDeploymentsRemaining = 5;
    }

    /**
     * @notice Creates a new OjoYieldRiskEngine instance
     * @dev Clones the implementation contract and initializes it with the provided parameters
     * @param basePriceFeed Address of the base price feed of the asset
     * @param yieldCap Yield cap value (in 1e18 precision)
     * @return ojoYieldRiskEngine Address of the newly created OjoYieldRiskEngine instance
     * @custom:requires The caller must send at least the required creation fee if no free deployments remaining
     * @custom:emits OjoYieldRiskEngineCreated when a new engine is created
     * @dev Any excess ETH sent above the creation fee will be refunded to the caller
     */
    function createOjoYieldRiskEngine(
        address basePriceFeed,
        uint256 yieldCap
    ) external payable returns (address ojoYieldRiskEngine) {
        require(termsAccepted[msg.sender], "accept terms first");

        if (freeDeploymentsRemaining == 0) {
            require(msg.value >= creationFee, "insufficient fee");

            if (creationFee > 0) {
                (bool success,) = feeRecipient.call{value: creationFee}("");
                require(success, "fee transfer failed");

                uint256 refund = msg.value - creationFee;
                if (refund > 0) {
                    (bool refundSuccess,) = msg.sender.call{value: refund}("");
                    require(refundSuccess, "refund failed");
                }
            }
        } else {
            freeDeploymentsRemaining = freeDeploymentsRemaining - 1;
        }

        ojoYieldRiskEngine = implementation.clone();
        OjoYieldRiskEngine(ojoYieldRiskEngine).initialize(basePriceFeed, yieldCap);
        OjoYieldRiskEngineAddresses[msg.sender] = ojoYieldRiskEngine;

        emit OjoYieldRiskEngineCreated(ojoYieldRiskEngine);
    }

    /**
     * @notice Allows users to accept the terms and conditions for creating risk engines
     * @dev Users must accept terms before they can create a risk engine
     * @dev Terms document can be found at: https://example.com/terms.pdf
     * @custom:emits TermsAccepted when a user accepts the terms
     */
    function acceptTerms() external {
        require(!termsAccepted[msg.sender], "already accepted");
        termsAccepted[msg.sender] = true;
        emit TermsAccepted(msg.sender);
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
