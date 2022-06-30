// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./IUniswapV2Router02.sol";
import "./IStrategy.sol";

pragma experimental ABIEncoderV2;

interface IVaultBase {
    struct Order {
        uint256 tokenId;
        uint256 tradeId;
        uint256 orderId;
        uint timestamp;
        address[2] tokens;
        uint256[3] amounts;
        uint[] times;
    }

    struct Strategy {
        address[] tokens;
        uint256[] amounts;
        uint[] times;
    }

    struct Token {
        address token;
        uint256 amount;
    }

    function tokenCounter() external view returns (uint256);
    function maxTokens() external view returns (uint256);
    function owner() external view returns (address);
    function _tokenTradeLength(uint256 _tokenId) external view returns (uint256);
    function setStrategy(address _token, address _strategy, uint256 _minDeposit) external;
    function changeMinimumDeposit(address _token, uint256 _minDeposit) external;
    function strategy(address _token) external view returns (IStrategy);
    function minimumDeposit(address _token) external view returns (uint256);

    function trade(uint256 _tokenId, uint256 _tradeId) external view returns (uint256[] memory);
    function order(uint256 _orderId) external view returns (Order memory);
    function ordersLength() external view returns (uint256);
    function openOrdersLength() external view returns (uint256);
    function openOrderId(uint256 _index) external view returns (uint256);
    function tokenOpenOrdersLength(uint256 _tokenId) external view returns (uint256);
    function tokenOpenOrderId(uint256 _tokenId, uint256 _index) external view returns (uint256);
    function viewTokenAmounts(uint256 _tokenId) external view returns (Token[] memory);
    function viewStrategy(uint256 _tokenId) external view returns (Strategy memory);
    function tokenURI(uint256 _tokenId) external view returns (string memory);

    function createTrade(address _from, address[] memory _tokens, uint256[] memory _amounts, uint[] memory _times) external returns (uint256[] memory);
    function fillOrder(uint256 _orderId, IUniswapV2Router02 _router, address[] memory _path) external returns (Order[] memory, uint256[] memory);
    function withdraw(address _from, uint256 _tokenId) external;

    function balanceOf(address _owner) external view returns (uint256);
    function tokenOfOwnerByIndex(address _owner, uint256 _index) external view returns (uint256);
    function ownerOf(uint256 _tokenId) external view returns (address);

    function tokens(uint256 _index) external view returns (address);
    function tokensLength() external view returns (uint256);
    function deactivateToken(address _token) external;
    function activeTokens(address _token) external view returns (bool);

    function setBaseURI(string memory) external;
    function BASE_URI() external view returns (string memory);
    function PRICE_MULTIPLIER() external view returns (uint256);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);

    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}