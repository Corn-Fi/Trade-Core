// SPDX-License-Identifier: MIT

//                                                 ______   __                                                   
//                                                /      \ /  |                                                  
//   _______   ______    ______   _______        /$$$$$$  |$$/  _______    ______   _______    _______   ______  
//  /       | /      \  /      \ /       \       $$ |_ $$/ /  |/       \  /      \ /       \  /       | /      \ 
// /$$$$$$$/ /$$$$$$  |/$$$$$$  |$$$$$$$  |      $$   |    $$ |$$$$$$$  | $$$$$$  |$$$$$$$  |/$$$$$$$/ /$$$$$$  |
// $$ |      $$ |  $$ |$$ |  $$/ $$ |  $$ |      $$$$/     $$ |$$ |  $$ | /    $$ |$$ |  $$ |$$ |      $$    $$ |
// $$ \_____ $$ \__$$ |$$ |      $$ |  $$ |      $$ |      $$ |$$ |  $$ |/$$$$$$$ |$$ |  $$ |$$ \_____ $$$$$$$$/ 
// $$       |$$    $$/ $$ |      $$ |  $$ |      $$ |      $$ |$$ |  $$ |$$    $$ |$$ |  $$ |$$       |$$       |
//  $$$$$$$/  $$$$$$/  $$/       $$/   $$/       $$/       $$/ $$/   $$/  $$$$$$$/ $$/   $$/  $$$$$$$/  $$$$$$$/
//                         .-.
//         .-""`""-.    |(@ @)
//      _/`oOoOoOoOo`\_ \ \-/
//     '.-=-=-=-=-=-=-.' \/ \
//       `-=.=-.-=.=-'    \ /\
//          ^  ^  ^       _H_ \

pragma solidity 0.8.13;

import "./VaultBase.sol";


pragma experimental ABIEncoderV2;

/**
* @title Corn Finance Limit Order Vault
* @author C.W.B.
*/
contract LimitOrderVault is VaultBase {
    constructor(
        address _controller, 
        string memory _URI
    ) VaultBase(
        _controller, 
        type(uint256).max, 
        "Corn Finance Limit Order Strategy", 
        "CFNFT", 
        _URI
    ) {}

    /**
    * @dev This contract is owned by the Controller. Call 'createTrade' from the Controller
    * to use this function.
    * @notice The number of sell prices determines how many orders to create. The amount 
    * in for the sell orders is the total amount deposited divided by the number of sell 
    * prices. Each sell order will have the same amount in.
    * Example:
    *     - amount in: 100 USDC
    *     - to token: WMATIC
    *     - sell price 1: 0.9 WMATIC / 1 USDC
    *     - sell price 2: 0.7 WMATIC / 1 USDC
    *     - sell price 3: 0.5 WMATIC / 1 USDC
    *     - sell price 4: 0.4 WMATIC / 1 USDC
    *
    *     * amount out = amount in / sell price *
    *
    *     Sell order 1: 25 USDC --> 27.77 WMATIC
    *     Sell order 2: 25 USDC --> 35.71 WMATIC
    *     Sell order 3: 25 USDC --> 50 WMATIC
    *     Sell order 4: 25 USDC --> 62.5 WMATIC
    * @param _from: Controller contract will forward 'msg.sender'
    * @param _tokens:
    *   [0] = from token 
    *   [1] = to token
    * @param _amounts: 
    *   [0] = {required} starting amount
    *   [1] = {required} sell price (1) (token[0] / token[1]) * PRICE_MULTIPLIER()
    *   [2] = {optional} sell price (2) (token[0] / token[1]) * PRICE_MULTIPLIER()
    *   [3] = {optional} sell price (3) (token[0] / token[1]) * PRICE_MULTIPLIER()
    *   [4] = {optional} sell price (4) (token[0] / token[1]) * PRICE_MULTIPLIER()
    * @param _times:
    *   [0] = Expiration time in Unix. Orders will not be filled after this time.
    * @return Order IDs of the created orders. Limit Order vault creates all orders
    * at the time of creating the trade. Number of order IDs returned is the
    * number of sell prices inputted.
    */
    function createTrade(
        address _from, 
        address[] memory _tokens, 
        uint256[] memory _amounts, 
        uint[] memory _times
    ) external onlyOwner returns (uint256[] memory) {
        // Only one expiration time allowed
        require(_times.length == 1);

        // Trade consists of only two tokens
        require(_tokens.length == 2);

        // Limit limit orders to 4. Deposit amount occupies the first element
        require(
            _amounts.length >= 2 && _amounts.length <= 5, 
            "CornFi Limit Order Vault: Invalid Amounts Length"
        );

        // Create the trade
        uint256 amountInWithFee = _createTrade(_from, _tokens, _amounts, _times);

        // Calculate the amount in for the orders
        uint256 orderAmountIn = amountInWithFee / (_amounts.length - 1);

        // Order IDs of the created orders
        uint256[] memory orderIds = new uint256[](_amounts.length - 1);

        // Avoid stack too deep error
        uint256[] memory amounts = _amounts;
        address[] memory tokens = _tokens;

        // Create all of the limit orders
        for(uint i = 1; i < amounts.length; i++) {
            orderIds[i-1] = _createOrder(
                // Token counter is incremented in '_createTrade()'. Need to subtract
                // '1' to get the correct token ID.
                tokenCounter - 1,

                // Trade ID is '0' since this is the first trade
                0, 

                // ['from' token, 'to' token]
                [
                    tokens[0], 
                    tokens[1]
                ], 

                // [amount in, amount out needed, (Not used in this vault. Enter '0')]
                [
                    orderAmountIn, 
                    _getAmountOut(tokens[0], tokens[1], orderAmountIn, amounts[i]), 
                    0
                ], 

                // Expiration time for this order
                _times
            );
        }
        
        // Return the order IDs of the created orders
        return orderIds;
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev This contract is owned by the Controller. Call 'fillOrder' from the Controller
    * to use this function.
    * @param _orderId: Order to fill
    * @param _router: Router used to perform the swap (i.e. fill the order)
    * @param _path: Path used to perform the swap
    * @return Since Limit Order vault does not create any new orders after filling orders,
    * '[]' is returned.
    */
    function fillOrder(
        uint256 _orderId, 
        IUniswapV2Router02 _router, 
        address[] memory _path
    ) external onlyOwner returns (Order[] memory, uint256[] memory) {
        Order memory order_ = order(_orderId);

        Order[] memory _orders;
        uint256[] memory filledOrders = new uint256[](1);
        filledOrders[0] = order_.orderId;

        // Fill order
        (uint256 minAmountOut, ) = _swap(order_, _router, _path);

        // Revert if swap amount out is too low
        require(
            minAmountOut >= order_.amounts[1], 
            "CornFi Limit Order Vault: Insufficent Output Amount"
        );

        return (_orders, filledOrders);
    }
    
    // --------------------------------------------------------------------------------

    /**
    * @dev This contract is owned by the Controller. Call 'withdraw' from the Controller
    * to use this function.
    * @notice After calling this function, all orders associated with '_tokenId' are
    * closed and their tokens are returned to the token owner. The token is then
    * burnt and cannot be used again.
    * @param _from: Controller contract will forward 'msg.sender'
    * @param _tokenId: Vault token to withdraw
    */
    function withdraw(address _from, uint256 _tokenId) external onlyOwner {
        _withdraw(_from, _tokenId);
    }

}