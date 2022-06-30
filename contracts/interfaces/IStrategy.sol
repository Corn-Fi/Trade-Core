// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;


pragma experimental ABIEncoderV2;

interface IStrategy {
    struct Tokens {
        address token;
        address amToken;
    }

    event Deposit(address indexed vault, address indexed token, uint256 amount);
    event Withdraw(address indexed vault, address indexed token, uint256 amount);
    event TokenAdded(address token, address amToken);


    function depositFee(uint256 _amountIn) external view returns (uint256);
    function txFee(uint256 _amountIn) external view returns (uint256);
    function fillerFee(uint256 _amountIn) external view returns (uint256);
    function deposit(address _from, address _token, uint256 _amount) external;
    function withdraw(address _from, address _token, uint256 _amount) external;
    function vaultDeposits(address _vault, address _token) external view returns (uint256);

    function DEPOSIT_FEE_POINTS() external view returns (uint256);
    function DEPOSIT_FEE_BASE_POINTS() external view returns (uint256);
    function TX_FEE_POINTS() external view returns (uint256);
    function TX_FEE_BASE_POINTS() external view returns (uint256);
    function rebalanceToken(address _token) external;
    function claim() external;
    function balanceRatio(address _token) external view returns (uint256, uint256);
    function rebalancePoints() external view returns (uint256);
    function rebalanceBasePoints() external view returns (uint256);
}