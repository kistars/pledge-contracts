// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract MockOracle is Ownable {
    mapping(uint256 => uint256) internal decimalsMap;
    mapping(address => uint256) internal priceMap;
    uint256 internal decimals = 1;

    constructor() Ownable(msg.sender) {}

    function setPrice(address asset, uint256 price) public onlyOwner {
        priceMap[asset] = price;
    }

    function getPrice(address asset) public view returns (uint256) {
        return priceMap[asset];
    }

    function getPrices(uint256[] memory assets) public view returns (uint256[] memory) {
        uint256 len = assets.length;
        uint256[] memory prices = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            prices[i] = getUnderlyingPrice(assets[i]);
        }
        return prices;
    }

    function getUnderlyingPrice(uint256 underlying) public view returns (uint256) {
        return priceMap[address(uint160(underlying))];
    }
}
