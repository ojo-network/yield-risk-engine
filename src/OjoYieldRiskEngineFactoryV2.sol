// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./OjoYieldRiskEngineV2.sol";

contract OjoYieldRiskEngineFactoryV2 is Ownable {
    using Clones for address;

    address public immutable implementation;
    mapping(address => address[]) public OjoYieldRiskEngineAddresses;
    mapping(address => bool) public termsAccepted;

    uint256 public baseFee;
    uint256 public feeIncrement;
    uint256 public maxFee;
    uint256 public totalDeployments;
    address public feeRecipient;

    event OjoYieldRiskEngineCreated(address indexed feed);
    event FeeUpdated(uint256 indexed newBaseFee, uint256 indexed newFeeIncrement);
    event MaxFeeUpdated(uint256 indexed newMaxFee);
    event FeeRecipientUpdated(address indexed newFeeRecipient);
    event TermsAccepted(address indexed user);

    constructor(uint256 baseFee_, uint256 feeIncrement_, uint256 maxFee_) Ownable(msg.sender) {
        implementation = address(new OjoYieldRiskEngineV2());
        feeRecipient = msg.sender;
        baseFee = baseFee_;
        feeIncrement = feeIncrement_;
        maxFee = maxFee_;
        totalDeployments = 0;
    }

    function getCurrentCreationFee() public view returns (uint256) {
        uint256 calculatedFee = baseFee + (totalDeployments * feeIncrement);
        return calculatedFee > maxFee ? maxFee : calculatedFee;
    }

    /**
     * @notice Creates a new OjoYieldRiskEngine instance
     * @notice This gives the creator a license to operate a market with an Ojo Risk Engine
     * @dev Clones the implementation contract and initializes it with the provided parameters
     * @param basePriceFeed Address of the base price feed of the asset
     * @param yieldCap Yield cap value (in 1e18 precision)
     * @return ojoYieldRiskEngine Address of the newly created OjoYieldRiskEngine instance
     * @custom:requires The caller must send at least the required creation fee if no free deployments remaining
     * @custom:emits OjoYieldRiskEngineCreated when a new engine is created
     * @dev Any excess ETH sent above the creation fee will be refunded to the caller
     * @custom:security Operators should verify that the price feed is not experiencing any anomalies (e.g., price spikes)
     * at the time of initialization, as the initial price will be used as the base for all future yield calculations.
     * In extremely rare cases, price feed anomalies during initialization could lead to an incorrect yield cap baseline.
     */
    function createOjoYieldRiskEngine(
        address basePriceFeed,
        uint256 yieldCap
    ) external payable returns (address ojoYieldRiskEngine) {
        require(termsAccepted[msg.sender], "accept terms first");

        uint256 currentFee = getCurrentCreationFee();
        uint256 refundAmount = 0;

        if (currentFee > 0) {
            require(msg.value >= currentFee, "insufficient fee");
            refundAmount = msg.value - currentFee;
        } else {
            refundAmount = msg.value;
        }

        totalDeployments++;

        ojoYieldRiskEngine = implementation.clone();
        OjoYieldRiskEngineV2(ojoYieldRiskEngine).initialize(basePriceFeed, yieldCap);
        OjoYieldRiskEngineAddresses[msg.sender].push(ojoYieldRiskEngine);

        emit OjoYieldRiskEngineCreated(ojoYieldRiskEngine);

        if (currentFee > 0) {
            (bool success,) = feeRecipient.call{value: currentFee}("");
            require(success, "fee transfer failed");
        }

        if (refundAmount > 0) {
            (bool refundSuccess,) = msg.sender.call{value: refundAmount}("");
            require(refundSuccess, "refund failed");
        }
    }

    /**
     * @notice Allows users to accept the terms and conditions for creating risk engines
     * @dev Users must accept terms before they can create a risk engine
     * @dev Terms document can be found at: https://github.com/ojo-network/yield-risk-engine/blob/main/DISCLAIMER.md
     * @custom:emits TermsAccepted when a user accepts the terms
     */
    function acceptTerms() external {
        require(!termsAccepted[msg.sender], "already accepted");
        termsAccepted[msg.sender] = true;
        emit TermsAccepted(msg.sender);
    }

    function setFeeStructure(uint256 newBaseFee, uint256 newFeeIncrement) external onlyOwner {
        baseFee = newBaseFee;
        feeIncrement = newFeeIncrement;
        emit FeeUpdated(newBaseFee, newFeeIncrement);
    }

    function setMaxFee(
        uint256 newMaxFee
    ) external onlyOwner {
        maxFee = newMaxFee;
        emit MaxFeeUpdated(newMaxFee);
    }

    function setFeeRecipient(
        address _newRecipient
    ) external onlyOwner {
        require(_newRecipient != address(0), "zero address");
        feeRecipient = _newRecipient;
        emit FeeRecipientUpdated(_newRecipient);
    }
}
