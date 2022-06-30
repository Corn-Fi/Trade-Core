// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

interface IAaveStakeV3 {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external payable; 
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
    function claimAllRewards(address[] calldata assets, address to) external returns (address[] memory, uint256[] memory);
}