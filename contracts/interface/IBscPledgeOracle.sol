// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBscPledgeOracle {
    function getPrice(address asset) external view returns (uint256);
    function getUnderlyingPrice(uint256 cToken) external view returns (uint256);
    function getPrices(uint256[] calldata assets) external view returns (uint256[] memory);
}
