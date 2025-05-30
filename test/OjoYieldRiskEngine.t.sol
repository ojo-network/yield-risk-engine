// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../src/OjoYieldRiskEngine.sol";
import "../src/OjoYieldRiskEngineFactory.sol";
import "./MockPriceFeed.sol";

contract OjoYieldRiskEngineTest is Test {
    OjoYieldRiskEngine public ojoYieldRiskEngine;
    OjoYieldRiskEngineFactory public factory;
    MockPriceFeed public basePriceFeed;

    int256 constant INITIAL_BASE_PRICE = 1e18;
    uint8 constant DECIMALS = 18;
    string constant BASE_DESCRIPTION = "STETH / ETH";
    uint256 constant VERSION = 1;
    uint256 constant YIELD_CAP = 5e16;
    uint256 constant ONE = 1e18;

    receive() external payable {}

    function setUp() public {
        basePriceFeed = new MockPriceFeed(INITIAL_BASE_PRICE, DECIMALS, BASE_DESCRIPTION, VERSION);

        factory = new OjoYieldRiskEngineFactory(0, 0);

        factory.acceptTerms();

        address riskEngineAddress = factory.createOjoYieldRiskEngine{value: 0}(address(basePriceFeed), YIELD_CAP);

        ojoYieldRiskEngine = OjoYieldRiskEngine(riskEngineAddress);
    }

    function testCreateWithoutAcceptingTerms() public {
        OjoYieldRiskEngineFactory newFactory = new OjoYieldRiskEngineFactory(0, 0);

        vm.expectRevert("accept terms first");
        newFactory.createOjoYieldRiskEngine{value: 0}(address(basePriceFeed), YIELD_CAP);
    }

    function testIncrementalFee() public {
        uint256 baseFee = 0;
        uint256 feeIncrement = 0.002 ether;
        OjoYieldRiskEngineFactory newFactory = new OjoYieldRiskEngineFactory(baseFee, feeIncrement);

        // Set a different fee recipient than the test contract to test refund functionality
        address feeRecipient = makeAddr("feeRecipient");
        newFactory.setFeeRecipient(feeRecipient);

        newFactory.acceptTerms();

        uint256 expectedFee = newFactory.getCurrentCreationFee();
        assertEq(expectedFee, 0, "First deployment should be free");

        address firstEngine = newFactory.createOjoYieldRiskEngine{value: 0}(address(basePriceFeed), YIELD_CAP);
        assertTrue(firstEngine != address(0), "First engine should be created for free");

        expectedFee = newFactory.getCurrentCreationFee();
        assertEq(expectedFee, feeIncrement, "Second deployment should cost feeIncrement");

        address secondEngine =
            newFactory.createOjoYieldRiskEngine{value: feeIncrement}(address(basePriceFeed), YIELD_CAP);
        assertTrue(secondEngine != address(0), "Second engine should be created with fee");

        expectedFee = newFactory.getCurrentCreationFee();
        assertEq(expectedFee, 2 * feeIncrement, "Third deployment should cost 2 * feeIncrement");

        address thirdEngine =
            newFactory.createOjoYieldRiskEngine{value: 2 * feeIncrement}(address(basePriceFeed), YIELD_CAP);
        assertTrue(thirdEngine != address(0), "Third engine should be created with higher fee");

        expectedFee = newFactory.getCurrentCreationFee();
        assertEq(expectedFee, 3 * feeIncrement, "Fourth deployment should cost 3 * feeIncrement");

        vm.expectRevert("insufficient fee");
        newFactory.createOjoYieldRiskEngine{value: 2 * feeIncrement}(address(basePriceFeed), YIELD_CAP);

        address fourthEngine =
            newFactory.createOjoYieldRiskEngine{value: 3 * feeIncrement}(address(basePriceFeed), YIELD_CAP);
        assertTrue(fourthEngine != address(0), "Fourth engine should be created with correct fee");

        uint256 balanceBefore = address(this).balance;
        expectedFee = newFactory.getCurrentCreationFee();
        uint256 overpayment = expectedFee + 0.01 ether;

        address fifthEngine = newFactory.createOjoYieldRiskEngine{value: overpayment}(address(basePriceFeed), YIELD_CAP);
        assertTrue(fifthEngine != address(0), "Fifth engine should be created with overpayment");

        uint256 balanceAfter = address(this).balance;
        assertEq(balanceBefore - balanceAfter, expectedFee, "Should only charge the required fee, refunding excess");

        // Apply flat fee to deployments
        uint256 flatFee = 0.005 ether;
        newFactory.setFeeStructure(flatFee, 0);

        uint256 flatFeeExpected = newFactory.getCurrentCreationFee();
        assertEq(flatFeeExpected, flatFee, "Fee should be the flat fee amount");

        address sixthEngine = newFactory.createOjoYieldRiskEngine{value: flatFee}(address(basePriceFeed), YIELD_CAP);
        assertTrue(sixthEngine != address(0), "Sixth engine should be created with flat fee");

        uint256 stillFlatFee = newFactory.getCurrentCreationFee();
        assertEq(stillFlatFee, flatFee, "Fee should remain flat after deployment");

        address seventhEngine = newFactory.createOjoYieldRiskEngine{value: flatFee}(address(basePriceFeed), YIELD_CAP);
        assertTrue(seventhEngine != address(0), "Seventh engine should be created with same flat fee");

        // Fees paid: 0 (1st) + 0.002 (2nd) + 0.004 (3rd) + 0.006 (4th) + 0.008 (5th) + 0.005 (6th) + 0.005 (7th) = 0.030 ether
        uint256 expectedTotalFees =
            0 + feeIncrement + (2 * feeIncrement) + (3 * feeIncrement) + (4 * feeIncrement) + flatFee + flatFee;
        assertEq(feeRecipient.balance, expectedTotalFees, "Fee recipient should have received correct total fees");
    }

    function testDescription() public {
        string memory description = ojoYieldRiskEngine.description();
        assertEq(description, "Ojo Yield Risk Engine STETH / ETH");
    }

    function testLatestRoundDataBelowYieldCap() public {
        (, int256 answer,,,) = ojoYieldRiskEngine.latestRoundData();

        (, int256 answer1,,,) = basePriceFeed.latestRoundData();

        // Verify that OjoYieldRiskEngine returns the base price
        assertEq(answer, answer1);
    }

    function testLatestRoundDataAboveYieldCap() public {
        // Update base price to a higher price than yield cap
        basePriceFeed.updateAnswer(211e16);

        (, int256 answer,,,) = ojoYieldRiskEngine.latestRoundData();

        // Verify that OjoYieldRiskEngine returns price cap
        assertEq(answer, INITIAL_BASE_PRICE + ((INITIAL_BASE_PRICE * int256(YIELD_CAP)) / int256(ONE)));
    }
}
