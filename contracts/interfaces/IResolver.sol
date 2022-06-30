// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./IUniswapV2Router02.sol";


interface IResolver {
    function checker(
        uint256 _vaultId, 
        uint256 _orderId, 
        address _fromToken, 
        address _toToken, 
        uint256 _fromAmount
    ) external view returns (bool, bytes memory);

    function findBestPathExactIn(
        address _fromToken, 
        address _toToken, 
        uint256 _amountIn
    ) external view returns (address, address[] memory, uint256);

    function findBestPathExactOut(
        address _fromToken, 
        address _toToken, 
        uint256 _amountOut
    ) external view returns (address, address[] memory, uint256);

    function getAmountOut(
        IUniswapV2Router02 _router, 
        uint256 _amountIn, 
        address _fromToken, 
        address _connectorToken, 
        address _toToken
    ) external view returns (uint256);
}