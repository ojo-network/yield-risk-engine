// SPDX-License-Identifier: SEE LICENSE IN LICENSE
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
    uint256 constant CREATION_FEE = 0.01 ether;
    uint256 constant ONE = 1e18;

    receive() external payable {}

    function setUp() public {
        basePriceFeed = new MockPriceFeed(INITIAL_BASE_PRICE, DECIMALS, BASE_DESCRIPTION, VERSION);

        factory = new OjoYieldRiskEngineFactory(CREATION_FEE);

        factory.acceptTerms();

        address riskEngineAddress =
            factory.createOjoYieldRiskEngine{value: CREATION_FEE}(address(basePriceFeed), YIELD_CAP);

        ojoYieldRiskEngine = OjoYieldRiskEngine(riskEngineAddress);
    }

    function testCreateWithoutAcceptingTerms() public {
        OjoYieldRiskEngineFactory newFactory = new OjoYieldRiskEngineFactory(CREATION_FEE);

        vm.expectRevert("accept terms first");
        newFactory.createOjoYieldRiskEngine{value: CREATION_FEE}(address(basePriceFeed), YIELD_CAP);
    }

    function testFreeDeploymentsAndCreationFee() public {
        uint256 freeDeployments = 5;
        OjoYieldRiskEngineFactory newFactory = new OjoYieldRiskEngineFactory(CREATION_FEE);

        newFactory.acceptTerms();

        for (uint256 i = 0; i < freeDeployments; i++) {
            address riskEngine = newFactory.createOjoYieldRiskEngine{value: 0}(address(basePriceFeed), YIELD_CAP);
            assertTrue(riskEngine != address(0), "Risk engine should be created");
        }

        vm.expectRevert("insufficient fee");
        newFactory.createOjoYieldRiskEngine{value: 0}(address(basePriceFeed), YIELD_CAP);

        address sixthRiskEngine =
            newFactory.createOjoYieldRiskEngine{value: CREATION_FEE}(address(basePriceFeed), YIELD_CAP);
        assertTrue(sixthRiskEngine != address(0), "Risk engine should be created with fee");
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
