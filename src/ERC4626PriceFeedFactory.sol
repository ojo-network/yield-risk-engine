// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC4626PriceFeed.sol";

contract ERC4626PriceFeedFactory is Ownable {
    using Clones for address;

    address public immutable implementation;
    mapping(address => address[]) public priceFeedsByVault;

    event PriceFeedCreated(address indexed vault, address indexed priceFeed);

    constructor() Ownable(msg.sender) {
        implementation = address(new ERC4626PriceFeed());
    }

    function createPriceFeed(address vault, string memory description) external returns (address priceFeed) {
        require(vault != address(0), "zero vault address");

        priceFeed = implementation.clone();
        ERC4626PriceFeed(priceFeed).initialize(vault, description);
        priceFeedsByVault[vault].push(priceFeed);

        emit PriceFeedCreated(vault, priceFeed);
    }
}
