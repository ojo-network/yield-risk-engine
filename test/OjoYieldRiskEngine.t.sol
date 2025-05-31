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

        factory = new OjoYieldRiskEngineFactory(0, 0, 0);

        factory.acceptTerms();

        address riskEngineAddress = factory.createOjoYieldRiskEngine{value: 0}(address(basePriceFeed), YIELD_CAP);

        ojoYieldRiskEngine = OjoYieldRiskEngine(riskEngineAddress);
    }

    function testCreateWithoutAcceptingTerms() public {
        OjoYieldRiskEngineFactory newFactory = new OjoYieldRiskEngineFactory(0, 0, 0);

        vm.expectRevert("accept terms first");
        newFactory.createOjoYieldRiskEngine{value: 0}(address(basePriceFeed), YIELD_CAP);
    }

    function testIncrementalFee() public {
        uint256 baseFee = 0;
        uint256 feeIncrement = 0.002 ether;
        uint256 maxFee = 0.01 ether;
        OjoYieldRiskEngineFactory newFactory = new OjoYieldRiskEngineFactory(baseFee, feeIncrement, maxFee);

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

        // Fee reaches max vaule
        uint256 flatFeeExpected = newFactory.getCurrentCreationFee();
        assertEq(flatFeeExpected, maxFee, "Fee should be the max fee amount");

        address sixthEngine = newFactory.createOjoYieldRiskEngine{value: maxFee}(address(basePriceFeed), YIELD_CAP);
        assertTrue(sixthEngine != address(0), "Sixth engine should be created with flat fee");

        uint256 stillFlatFee = newFactory.getCurrentCreationFee();
        assertEq(stillFlatFee, maxFee, "Fee should remain flat");

        address seventhEngine = newFactory.createOjoYieldRiskEngine{value: maxFee}(address(basePriceFeed), YIELD_CAP);
        assertTrue(seventhEngine != address(0), "Seventh engine should be created with same flat fee");

        // Update max fee and fee increment to higher values
        uint256 newMaxFee = 0.04 ether;
        uint256 newFeeIncrement = 0.005 ether;
        newFactory.setMaxFee(newMaxFee);
        newFactory.setFeeStructure(baseFee, newFeeIncrement);

        expectedFee = newFactory.getCurrentCreationFee();
        uint256 expectedIncrementalFee = baseFee + (7 * newFeeIncrement);
        assertEq(expectedFee, expectedIncrementalFee, "Fee should use new increment after fee structure update");

        address eighthEngine =
            newFactory.createOjoYieldRiskEngine{value: expectedIncrementalFee}(address(basePriceFeed), YIELD_CAP);
        assertTrue(eighthEngine != address(0), "Eighth engine should be created with new fee structure");

        expectedFee = newFactory.getCurrentCreationFee();
        assertEq(expectedFee, newMaxFee, "Fee should be capped at new max fee");

        address ninthEngine = newFactory.createOjoYieldRiskEngine{value: newMaxFee}(address(basePriceFeed), YIELD_CAP);
        assertTrue(ninthEngine != address(0), "Ninth engine should be created at new max fee");

        uint256 finalFee = newFactory.getCurrentCreationFee();
        assertEq(finalFee, newMaxFee, "Fee should remain at new max fee");

        // Calculate total fees collected
        // Original fees: 0 + 0.002 + 0.004 + 0.006 + 0.008 + 0.01 + 0.01 = 0.040 ether
        // New fees: 0.035 (8th with new increment) + 0.04 (9th at new max) = 0.075 ether
        // Total: 0.040 + 0.075 = 0.115 ether
        uint256 originalFees =
            0 + feeIncrement + (2 * feeIncrement) + (3 * feeIncrement) + (4 * feeIncrement) + maxFee + maxFee;
        uint256 newFees = (7 * newFeeIncrement) + newMaxFee;
        uint256 expectedTotalFees = originalFees + newFees;
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
