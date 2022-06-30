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

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../interfaces/IERC20Meta.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/IController.sol";
import "../interfaces/IUniswapV2Router02.sol";


pragma experimental ABIEncoderV2;

/**
* @title Corn Finance Vault Base
* @author C.W.B.
*/
abstract contract VaultBase is ERC721, Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;


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


    // Number of minted vault tokens
    uint256 public tokenCounter;

    // Max number of vault tokens that can be minted
    uint256 public maxTokens;

    // Controller contract
    IController public controller;

    // All token orders
    // orders[orderId] --> Order
    Order[] internal orders;

    // All open order IDs
    uint256[] internal openOrderIds;

    // All open order IDs for a given token
    // tokenOpenOrderIds[tokenId][index] --> Order ID
    uint256[][] internal tokenOpenOrderIds;

    // tradeLength[tokenId][tradeId] --> Number of orders in the trade
    mapping(uint256 => mapping(uint256 => uint256)) internal tradeLength;

    // trades[tokenId][tradeId] --> Array of the order IDs in a given trade
    mapping(uint256 => mapping(uint256 => uint256[])) internal trades;

    // _tokenTradeLength[tokenId] --> Number of trades in a given token
    mapping(uint256 => uint256) public _tokenTradeLength;

    // strategies[tokenId] --> Strategy details
    Strategy[] internal strategies;

    // tokenAmounts[tokenId][ERC20] --> Amount of an ERC20 token that belongs to 'tokenId'
    mapping(uint256 => mapping(address => uint256)) internal tokenAmounts;

    // openOrderIndex[orderId] --> Index of 'orderId' within 'openOrderIds'
    mapping(uint256 => uint256) internal openOrderIndex;

    // Tokens approved for use within the vault
    address[] public tokens;

    // activeTokens[ERC20] --> true: Token is active; false: Token is inactive 
    mapping(address => bool) public activeTokens;

    // _tokenStrategies[ERC20] --> Token holding strategy
    mapping(address => IStrategy) internal _tokenStrategies;

    // minimumDeposit[ERC20] --> Minimum amount of an ERC20 token that can be deposited for a trade
    mapping(address => uint256) public minimumDeposit;

    // Multiply price input into 'createTrade()' by this value to handle decimals
    uint256 public constant PRICE_MULTIPLIER = 1e18;

    string public BASE_URI;


    // --------------------------------------------------------------------------------
    // --------------------------------------------------------------------------------
    // --------------------------------------------------------------------------------

    /**
    * @dev Vaults are owned by the Controller contract. The Controller is immutable.
    * @param _controller: Controller contract that will call all 'onlyOwner' functions
    * @param _maxTokens: Max number of vault tokens that can be minted
    * @param _name: Vault name
    * @param _symbol: Vault symbol
    * @param baseURI_: Vault URI
    */
    constructor(
        address _controller, 
        uint256 _maxTokens, 
        string memory _name, 
        string memory _symbol, 
        string memory baseURI_
    ) ERC721(_name, _symbol) {
        // Set Controller contract
        controller = IController(_controller);

        // Vault URI
        BASE_URI = baseURI_;

        // Set max tokens that can be minted
        require(_maxTokens > 1, "CornFi Vault Base: Max Tokens Cannot be Less Than 1");
        maxTokens = _maxTokens;

        // Mint a blank strategy to this contract.
        orders.push();
        strategies.push();
        _safeMint(address(this), tokenCounter++);
        tokenOpenOrderIds.push();

        // Set Controller contract as the owner
        transferOwnership(_controller);
    }


    // --------------------------------------------------------------------------------
    // //////////////////////// Contract Settings - Only Owner ////////////////////////
    // --------------------------------------------------------------------------------

    /**
    * @dev This contract is owned by the Controller. Call 'setBaseURI' from the Controller
    * to use this function. Sets URI for all vault tokens.
    * @param baseURI_: Vault URI
    */
    function setBaseURI(string memory baseURI_) external onlyOwner {
        BASE_URI = baseURI_;
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev This contract is owned by the Controller. Call 'setStrategy' from the Controller
    * to use this function. Maps an ERC20 to a holding strategy. Once an ERC20 token is
    * mapped to a holding strategy, the mapping is immutable.
    * @param _token: ERC20 token address
    * @param _strategy: Holding strategy contract
    * @param _minDeposit: Minimum amount of '_token' that can be deposited when creating a trade
    */
    function setStrategy(address _token, address _strategy, uint256 _minDeposit) external onlyOwner {
        // Only unmapped ERC20 tokens
        require(address(_tokenStrategies[_token]) == address(0), "CornFi Vaut Base: Token Already Mapped");

        require(_strategy != address(0), "CornFi Vault Base: Strategy is address(0)");

        // Map the ERC20 token to a holding strategy
        _tokenStrategies[_token] = IStrategy(_strategy);

        // Set the minimum deposit for the ERC20 token
        minimumDeposit[_token] = _minDeposit;

        // Add ERC20 token to 'tokens'
        tokens.push(_token);

        // Allow trading of the ERC20 token
        activeTokens[_token] = true;
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev This contract is owned by the Controller. Call 'changeMinimumDeposit' from the 
    * Controller to use this function. Owner can change the minimum amount of '_token'
    * that can be deposited when creating a trade.
    * @param _token: ERC20 token address
    * @param _minDeposit: Minimum amount of '_token' that can be deposited when creating a trade
    */
    function changeMinimumDeposit(address _token, uint256 _minDeposit) public onlyOwner {
        // Only active ERC20 tokens
        require(activeTokens[_token], "CornFi Vault Base: Invalid Token");

        // Set the minimum deposit for the ERC20 token
        minimumDeposit[_token] = _minDeposit;
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev This contract is owned by the Controller. Call 'deactivateToken' from the 
    * Controller to use this function. Deactivating a token will restrict future users 
    * from creating trades with the deactivated token. Once a token is deactivated, it 
    * cannot be reactivated.
    * @param _token: ERC20 token to deactivate
    */
    function deactivateToken(address _token) public onlyOwner {
        activeTokens[_token] = false;
    }


    // --------------------------------------------------------------------------------
    // ///////////////////////////// Read-Only Functions //////////////////////////////
    // --------------------------------------------------------------------------------

    /**
    * @return Length of all tokens added to this vault. Includes tokens that have been
    * deactivated.
    */
    function tokensLength() public view returns (uint256) {
        return tokens.length;
    }

    // --------------------------------------------------------------------------------

    /**
    * @param _token: ERC20 token address
    * @return Holding strategy contract mapped to '_token'
    */
    function strategy(address _token) public view returns (IStrategy) {
        return _tokenStrategies[_token];
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Only used for informational purposes. Use to get all of the orders within a
    * given trade. After the order IDs are returned, use 'order()' to view the actual
    * order.
    * @param _tokenId: Vault token
    * @param _tradeId: Trade owned by '_tokenId'
    * @return IDs of the orders within the trade
    */
    function trade(uint256 _tokenId, uint256 _tradeId) public view returns (uint256[] memory) {
        return trades[_tokenId][_tradeId];
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Use to view any order that has been created within this vault
    * @param _orderId: Order to view
    * @return Order details of a given order
    */
    function order(uint256 _orderId) public view returns (Order memory) {
        return orders[_orderId];
    }
    
    // --------------------------------------------------------------------------------

    /**
    * @return Number of all orders created within this vault
    */
    function ordersLength() public view returns (uint256) {
        return orders.length;
    }

    // --------------------------------------------------------------------------------

    /**
    * @return Number of all open orders within this vault
    */
    function openOrdersLength() public view returns (uint256) {
        return openOrderIds.length;
    }

    // --------------------------------------------------------------------------------

    /**
    * @param _tokenId: Vault token
    * @return Number of open orders for a given vault token
    */
    function tokenOpenOrdersLength(uint256 _tokenId) public view returns (uint256) {
        return tokenOpenOrderIds[_tokenId].length;
    }

    // --------------------------------------------------------------------------------

    /**
    * @param _index: Element of 'openOrderIds'
    * @return Order ID at the given index 
    */
    function openOrderId(uint256 _index) public view returns (uint256) {
        return openOrderIds[_index];
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev After the order IDs are returned, use 'order()' to view the actual order.
    * @param _tokenId: Vault token
    * @param _index: Element of an open order IDs array for a given vault token
    * @return Order ID at the given index of open order IDs for a vault token
    */
    function tokenOpenOrderId(uint256 _tokenId, uint256 _index) public view returns (uint256) {
        return tokenOpenOrderIds[_tokenId][_index];
    }

    // --------------------------------------------------------------------------------

    /**
    * @param _tokenId: Vault token
    * @return Array of ERC20 tokens and the respective amount owned by a given vault token
    */
    function viewTokenAmounts(uint256 _tokenId) public view returns (Token[] memory) {
        // Number of tokens included in the vault token strategy
        uint256 _tokensLength = strategies[_tokenId].tokens.length;
        Token[] memory _tokenAmounts = new Token[](_tokensLength);

        // Get amount of ERC20 tokens owned by the vault token 
        for(uint i = 0; i < strategies[_tokenId].tokens.length; i++) {
            _tokenAmounts[i] = Token(
                strategies[_tokenId].tokens[i], 
                tokenAmounts[_tokenId][strategies[_tokenId].tokens[i]]
            );
        }

        // Return ERC20 token amounts
        return _tokenAmounts;
    }

    // --------------------------------------------------------------------------------

    /**
    * @param _tokenId: Vault token
    * @return Trade details specific to a given vault token
    */
    function viewStrategy(uint256 _tokenId) public view returns (Strategy memory) {
        return strategies[_tokenId];
    }

    // --------------------------------------------------------------------------------
    
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return BASE_URI;
    }
    

    // --------------------------------------------------------------------------------
    // ////////////////////////////// Internal Functions //////////////////////////////
    // --------------------------------------------------------------------------------

    /**
    * @dev Use to create an order. This function will add the created order to the list
    * of open order IDs as well as configuring trade data. The format of '_tokens',
    * '_amounts', and '_times' are specific to the vault that inherits this contract.
    * @param _tokenId: Vault token
    * @param _tradeId: Trade owned by the vault token that will include the created order
    * @param _tokens:
    *   [0] = from token
    *   [1] = to token
    * @param _amounts: !!! SPECIFIC TO THE VAULT THAT INHERITS THIS CONTRACT !!!
    * @param _times: Expiration times
    * @return Order ID of the created order
    */
    function _createOrder(
        uint256 _tokenId, 
        uint256 _tradeId, 
        address[2] memory _tokens, 
        uint256[3] memory _amounts, 
        uint[] memory _times
    ) internal returns (uint256) {
        // Tokens must be unique
        require(
            _tokens[0] != _tokens[1], 
            "CornFi Vault Base: Identical Tokens"
        );

        // Trades can only be created with active tokens
        require(
            activeTokens[_tokens[0]] && activeTokens[_tokens[1]], 
            "CornFi Vault Base: Invalid Tokens"
        );

        // Reverse mapping for the index within 'openOrderIds' of the order being created
        openOrderIndex[orders.length] = openOrderIds.length;

        // Add the order ID of the created order to 'openOrderIds'
        openOrderIds.push(orders.length);

        // First order for a vault token
        if(_tokenId == tokenOpenOrderIds.length) {
            tokenOpenOrderIds.push([orders.length]);
        }
        // Vault token does not currently have any open orders
        else if(tokenOpenOrderIds[_tokenId].length == 0) {
            tokenOpenOrderIds[_tokenId] = [orders.length];
        }
        // Vault token currently has open orders
        else {
            // Create a new array of open order IDs with one extra element for the order
            // being created.
            uint256[] memory _prevIds = new uint256[](tokenOpenOrderIds[_tokenId].length.add(1));

            // Add all of the current open order IDs
            for(uint i = 0; i < tokenOpenOrderIds[_tokenId].length; i++) {
                _prevIds[i] = tokenOpenOrderIds[_tokenId][i];
            }

            // Add the new open order ID
            _prevIds[tokenOpenOrderIds[_tokenId].length] = orders.length;
            tokenOpenOrderIds[_tokenId] = _prevIds;
        }

        // Create a new trade and add the created order to it
        if(_tradeId == _tokenTradeLength[_tokenId]) {
            trades[_tokenId][_tradeId] = [orders.length];
            _tokenTradeLength[_tokenId]++;
        }
        // The created order is part of the current trade
        else {
            // Create a new array of order IDs with one extra element for the order
            // being created.
            uint256[] memory _prevTradeOrderIds = new uint256[](trades[_tokenId][_tradeId].length.add(1));

            // Add all of the current order IDs within the trade
            for(uint i = 0; i < trades[_tokenId][_tradeId].length; i++) {
                _prevTradeOrderIds[i] = trades[_tokenId][_tradeId][i];
            }

            // Add the new order ID to the trade
            _prevTradeOrderIds[trades[_tokenId][_tradeId].length] = orders.length;
            trades[_tokenId][_tradeId] = _prevTradeOrderIds;
        }

        // Increment the number of orders within the trade
        tradeLength[_tokenId][_tradeId]++;

        // Ensure the order was added to the correct trade
        require(
            tradeLength[_tokenId][_tradeId] <= strategies[_tokenId].amounts.length.sub(1), 
            "CornFi Vault Base: Trade Length Error"
        );

        // Create the order and add it to 'orders'
        orders.push(Order(_tokenId, _tradeId, orders.length, 0, _tokens, _amounts, _times));

        // Return the order ID of the created order
        return orders.length.sub(1);
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Closes an open order
    * @param _orderId: Open order to close
    */
    function _removeOrder(uint256 _orderId) internal {
        Order memory _order = order(_orderId);//orders[_orderId];

        // Remove open order from all open orders list
        _removeOpenOrder(_orderId);

        // Remove open order from vault token open orders list
        _removeTokenOpenOrder(_order.tokenId, _orderId);
    }
    
    // --------------------------------------------------------------------------------

    /**
    * @dev Removes an open order from 'openOrderIds' and 'openOrderIndex'. Do not call
    * this function directly. Use '_removeOrder()'.
    * @param _orderId: Open order to remove
    */
    function _removeOpenOrder(uint256 _orderId) internal {
        openOrderIds[openOrderIndex[_orderId]] = openOrderIds[openOrderIds.length.sub(1)];
        openOrderIndex[openOrderIds[openOrderIds.length.sub(1)]] = openOrderIndex[_orderId];
        openOrderIds.pop();
        delete openOrderIndex[_orderId];
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Removes an open order from 'tokenOpenOrderIds'. Do not call this function
    * directly. Use '_removeOrder()'.
    * @param _tokenId: Vault token
    * @param _orderId: Open order to remove
    */
    function _removeTokenOpenOrder(uint256 _tokenId, uint256 _orderId) internal {
        uint256[] memory _tokenOpenOrderIds = new uint256[](tokenOpenOrderIds[_tokenId].length.sub(1));
        uint j = 0;
        for(uint i = 0; i < tokenOpenOrderIds[_tokenId].length; i++) {
            if(tokenOpenOrderIds[_tokenId][i] != _orderId) {
                _tokenOpenOrderIds[j++] = tokenOpenOrderIds[_tokenId][i];
            }
        }
        tokenOpenOrderIds[_tokenId] = _tokenOpenOrderIds;
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Set the strategy (trade details) when a user creates a trade. Once a strategy
    * is set for a vault token, the data is immutable. 
    * 
    *           !!! STRATEGY DATA FORMAT WILL DIFFER ACCROSS ALL VAULTS !!!
    *
    * Refer to a specific vault that inherits this contract to determine what the strategy
    * data means.
    * @param _tokens: ERC20 tokens used in the trade
    * @param _amounts: Amount in of an ERC20 token, buy/sell prices, etc.
    * @param _times: Expiration times
    */
    function _setStrategy(
        address[] memory _tokens, 
        uint256[] memory _amounts, 
        uint[] memory _times
    ) internal {
        strategies.push(Strategy(_tokens, _amounts, _times));
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Use to calculate the amount out of a swap when the decimals of the tokens being
    * swapped are different. Be aware that 'from amount' is multiplied by 1e8 because 
    * '_price' = (price * 1e8). This allows users to place trades at rates below '1'.
    * @param _fromToken: ERC20 token to swap
    * @param _toToken: ERC20 token received from swap
    * @param _fromAmount: Amount of '_fromToken' going into the swap
    * @param _price: Rate of ('_fromToken' / '_toToken') * 1e8
    */
    function _getAmountOut(
        address _fromToken, 
        address _toToken, 
        uint256 _fromAmount, 
        uint256 _price
    ) internal view returns (uint256) {
        uint8 decimalDiff;
        bool pos;

        uint8 fromDecimals = IERC20Meta(_fromToken).decimals();
        uint8 toDecimals = IERC20Meta(_toToken).decimals();

        // 'To token' has either more or an equivalent number of decimals than 'from token'
        if(toDecimals >= fromDecimals) {
            // Calculate the difference in decimals between the two tokens
            decimalDiff = toDecimals - fromDecimals;
            pos = true;
        }
        // 'To token' has fewer decimals than 'from token'
        else {
            // Calculate the difference in decimals between the two tokens
            decimalDiff = fromDecimals - toDecimals;
            pos = false;
        }

        // If 'to token' has more or an equivalent number of decimals than 'from token', 
        // calculate 'to amount' and multiply by the difference in decimals.
        // If 'to token' has fewer decimals than 'from token', calculate 'to amount' and 
        // divide by the difference in decimals.
        uint256 toAmount = _fromAmount.mul(PRICE_MULTIPLIER).div(_price);
        return pos ? toAmount.mul(10 ** uint256(decimalDiff)) : toAmount.div(10 ** uint256(decimalDiff));
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Use only to create the initial trade. For creating orders use '_createOrder'.
    * This function will set the unique strategy for the user, transfer the starting 
    * amount from the user, and mint a vault token.
    * @param _from: Address of the caller
    * @param _tokens:
    *   [0] = from token
    *   [1] = to token
    * @param _amounts: 
    *   [0] = from amount
    *   !!! REMAINING ELEMENTS ARE SPECIFIC TO THE VAULT THAT INHERITS THIS CONTRACT !!!
    * @param _times: 
    *   [0] = Expiration time
    */
    function _createTrade(
        address _from, 
        address[] memory _tokens, 
        uint256[] memory _amounts, 
        uint[] memory _times
    ) internal returns (uint256) {
        // Restrict the number of vault tokens that can be minted
        require(tokenCounter < maxTokens, "CornFi Vault Base: Max Tokens Reached");

        // Revert if deposit amount is less than the minimum deposit
        require(
            _amounts[0] >= minimumDeposit[_tokens[0]], 
            "CornFi Vault Base: Minimum Deposit Not Met"
        );

        // Create the strategy
        _setStrategy(_tokens, _amounts, _times);

        IERC20 depositToken = IERC20(_tokens[0]);

        // For a security check after transfer
        uint256 balanceBefore = depositToken.balanceOf(address(this));

        // Transfer deposit amount from user
        depositToken.safeTransferFrom(_from, address(this), _amounts[0]);

        // Ensure full amount is transferred
        require(
            depositToken.balanceOf(address(this)).sub(balanceBefore) == _amounts[0], 
            "CornFi Vault Base: Deposit Error"
        );

        IStrategy strat = _tokenStrategies[_tokens[0]];

        // Deposit fee
        uint256 depositFee = strat.depositFee(_amounts[0]);

        if(depositFee > 0) {
            IERC20(_tokens[0]).safeTransfer(controller.DepositFees(), depositFee);
        }

        // Adjust token amount to include fee
        uint256 amountInWithFee = _amounts[0].sub(depositFee);
        tokenAmounts[tokenCounter][_tokens[0]] = amountInWithFee;

        // Deposit ERC20 token into holding strategy
        IERC20(_tokens[0]).approve(address(strat), amountInWithFee);
        strat.deposit(address(this), _tokens[0], amountInWithFee);  

        // Mint a vault token to the caller
        _safeMint(_from, tokenCounter++);

        return amountInWithFee;
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev After calling this function, all orders associated with '_tokenId' will be
    * closed and their tokens will be returned to the token owner. The token is then
    * burnt and cannot be used again. Callers can only withdraw from vault tokens that
    * they own.
    * @param _from: Address of the caller
    * @param _tokenId: Vault token to be withdrawn
    */
    function _withdraw(address _from, uint256 _tokenId) internal {
        // Caller can only withdraw from vault tokens they own
        require(
            ownerOf(_tokenId) == _from, 
            "CornFi Vault Base: Caller is Not the Token Owner"
        );

        // Withdraw all tokens associated with a vault token and send tokens to the owner
        Strategy memory strat = strategies[_tokenId];
        for(uint i = 0; i < strat.tokens.length; i++) {
            // Withdraw tokens with amounts over zero
            if(tokenAmounts[_tokenId][strat.tokens[i]] > 0) {
                // Withdraw the token and send to vault token owner
                _tokenStrategies[strat.tokens[i]].withdraw(
                    _from, 
                    strat.tokens[i], 
                    tokenAmounts[_tokenId][strat.tokens[i]]
                );
                tokenAmounts[_tokenId][strat.tokens[i]] = 0;
            }
        }

        // Get all open orders associated with '_tokenId'
        uint256[] memory orderIds = tokenOpenOrderIds[_tokenId];

        // Close the open orders
        for(uint j = 0; j < orderIds.length; j++) {
            _removeOpenOrder(orderIds[j]);
            // Orders that are closed but not filled will have a timestamp of '1' vs. '0'
            // when active and not filled or the timestamp of when the order was filled.
            orders[orderIds[j]].timestamp = 1;
        }

        // Remove all vault token open orders
        delete tokenOpenOrderIds[_tokenId];

        // Burn the vault token
        _burn(_tokenId);
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Use when filling orders. Adjusts token amounts associated with the owning
    * vault token and closes the open order.
    *
    * !!!  CALL THIS FUNCTION ONLY AFTER COMPLETING THE SWAP, ACCOUNTING FOR FEES,  !!!
    * !!!  AND SETTING 'amounts[1]' OF THE ORDER TO THE ACTUAL AMOUNT THE USER      !!!
    * !!!  WILL RECEIVE.                                                            !!!
    *
    * @param _orderId: Order to close
    */
    function _closeOrderHelper(uint256 _orderId) internal {
        Order memory _order = order(_orderId);

        // Adjust 'to token' amounts to reflect the amount received from the swap
        tokenAmounts[_order.tokenId][_order.tokens[1]] = tokenAmounts[_order.tokenId][_order.tokens[1]].add(_order.amounts[1]);
        
        // Adjust 'from token' amounts to reflect the amount used for the swap
        tokenAmounts[_order.tokenId][_order.tokens[0]] = tokenAmounts[_order.tokenId][_order.tokens[0]].sub(_order.amounts[0]);
        
        // Close trade
        orders[_orderId].timestamp = block.timestamp;

        // Remove open order
        _removeOrder(_orderId);
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Use to fill orders. Ensures that the order is active and fills the order when
    * trade conditions are met.
    * @param _order: Order to fill
    * @param _router: Router used to fill the order
    * @param _path: Path used to fill the order
    * @return (minimumAmountOut, amountOut) Returns the amount out including slippage and
    * the actual amount out from the swap.
    */
    function _swap(
        Order memory _order, 
        IUniswapV2Router02 _router, 
        address[] memory _path
    ) internal returns (uint256, uint256) {
        // Check for an expiration time. Orders with '0' as the expiration time will not
        // expire.
        if(_order.times[0] > 0) {
            // Revert if expiration time has passed
            require(block.timestamp < _order.times[0], "CornFi Vault Base: Expired Order");
        }

        // Only fill active orders
        require(_order.timestamp == 0, "CornFi Vault Base: Order is Inactive");

        // Withdraw tokens from holding strategy
        strategy(_order.tokens[0]).withdraw(address(this), _order.tokens[0], _order.amounts[0]);

        uint256 lastElement = _path.length.sub(1);

        // Path must start with the 'from token' and end with the 'to token' 
        require(
            _path[0] == _order.tokens[0] &&
            _path[lastElement] == _order.tokens[1], 
            "CornFi Vault Base: Invalid Path"
        );

        // Check if tokens were deactivated since order was created
        require(
            activeTokens[_path[0]] && activeTokens[_path[lastElement]], 
            "CornFi Vault Base: Invalid Tokens"
        );

        // Get current amount out from the swap and account for slippage
        uint256 amountOut = _router.getAmountsOut(_order.amounts[0], _path)[lastElement];
        uint256 minAmountOut = controller.slippage(amountOut); 
        
        // Swap tokens
        IERC20(_order.tokens[0]).approve(address(_router), _order.amounts[0]);
        uint256 swapAmountOut = _router.swapExactTokensForTokens(
            _order.amounts[0], 
            minAmountOut, 
            _path, 
            address(this), 
            block.timestamp.add(60)
        )[lastElement];

        IStrategy strat = strategy(_order.tokens[1]);

        // Set target amount
        if(_order.amounts[2] == 0) {
            orders[_order.orderId].amounts[2] = _order.amounts[1];
        }

        // Transaction fees
        uint256 txFee = strategy(_order.tokens[0]).txFee(amountOut);

        if(txFee > 0) {
            IERC20(_order.tokens[1]).safeTransfer(controller.Fees(), txFee);

            // Adjust user balance
            orders[_order.orderId].amounts[1] = amountOut.sub(txFee);
        }
        else {
            orders[_order.orderId].amounts[1] = amountOut;
        }

        // Deposit swapped tokens into respective holding strategy
        IERC20(_order.tokens[1]).approve(address(strat), orders[_order.orderId].amounts[1]);
        strat.deposit(address(this), _order.tokens[1], orders[_order.orderId].amounts[1]);

        // Close order, remove from open orders list
        _closeOrderHelper(_order.orderId);
        return (minAmountOut, swapAmountOut);
    }
}