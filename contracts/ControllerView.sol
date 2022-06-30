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

import "./interfaces/IVaultBase.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IResolver.sol";
import "./interfaces/IStrategy.sol";
import "./interfaces/IController.sol";



pragma experimental ABIEncoderV2;

contract ControllerView is Ownable {
    using SafeMath for uint256;

    struct UserTokens {
        address vault;
        uint256 tokenId;
    }

    IController public Controller;
    IResolver public Resolver;

    constructor(address _controller, address _resolver) {
        Controller = IController(_controller);
        Resolver = IResolver(_resolver);
    }

    // --------------------------------------------------------------------------------
    // ///////////////////////////// Only Owner Functions /////////////////////////////
    // --------------------------------------------------------------------------------

    /**
    * OoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOo
    */
    function setContracts(address _controller, address _resolver) external onlyOwner {
        Controller = IController(_controller);
        Resolver = IResolver(_resolver);
    }


    // --------------------------------------------------------------------------------
    // ///////////////////////////// Read-Only Functions //////////////////////////////
    // --------------------------------------------------------------------------------

    /**
    * OoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOo
    */
    function findBestPathExactIn(
        address _fromToken, 
        address _toToken, 
        uint256 _amountIn
    ) external view returns (address, address[] memory, uint256) {
        return Resolver.findBestPathExactIn(_fromToken, _toToken, _amountIn);
    }                                                                                                

    // --------------------------------------------------------------------------------

    /**
    * OoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOo
    */
    function findBestPathExactOut(
        address _fromToken, 
        address _toToken, 
        uint256 _amountOut
    ) external view returns (address, address[] memory, uint256) {
        return Resolver.findBestPathExactOut(_fromToken, _toToken, _amountOut);
    }                                                                                                

    // --------------------------------------------------------------------------------

    /**
    * @param _vaultId: Index of vault in 'vaults'
    * @param _token: ERC20 token address
    * @return Minimum amount of '_token' that can be deposited while creating a trade
    */
    function tokenMinimumDeposit(uint256 _vaultId, address _token) external view returns (uint256) {                                 
        return Controller.vaults(_vaultId).minimumDeposit(_token);                                                                     
    }   

    // --------------------------------------------------------------------------------

    /**
    * @notice Array of all ERC20 tokens mapped to a holding strategy within a vault.
    * Active and deactivated tokens are included. Use 'activeTokens()' to verify if the
    * token is active or not.
    * @param _vaultId: Index of vault in 'vaults'
    * @param _index: Index of 'tokens' within a vault
    * @return ERC20 token address
    */
    function tokens(uint256 _vaultId, uint256 _index) external view returns (address) {
        return Controller.vaults(_vaultId).tokens(_index);
    }  

    // --------------------------------------------------------------------------------

    /**
    * @param _vaultId: Index of vault in 'vaults'
    * @param _token: ERC20 token address
    * @return true: ERC20 token is active and can be used to create a trade; false: ERC20
    * token is inactive and cannot be used to create a trade
    */
    function activeTokens(uint256 _vaultId, address _token) external view returns (bool) {
        return Controller.vaults(_vaultId).activeTokens(_token);
    }   

    // --------------------------------------------------------------------------------
 
    /**
    * @param _vaultId: Index of vault in 'vaults'
    * @return Number of ERC20 tokens mapped to a holding strategy in a vault
    */
    function tokensLength(uint256 _vaultId) external view returns (uint256) {
        return Controller.vaults(_vaultId).tokensLength();
    }                        

    // --------------------------------------------------------------------------------

    /**
    * OoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOo
    */
    function tokenFees(
        uint256 _vaultId, 
        address _token
    ) external view returns (uint256, uint256, uint256, uint256) {
        IStrategy strat = Controller.vaults(_vaultId).strategy(_token);
        return (
            strat.DEPOSIT_FEE_POINTS(), 
            strat.DEPOSIT_FEE_BASE_POINTS(),
            strat.TX_FEE_POINTS(),
            strat.TX_FEE_BASE_POINTS()
        );
    }

    // --------------------------------------------------------------------------------

    /**
    * OoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOo
    */
    function tokenAmounts(
        uint256 _vaultId, 
        uint256 _tokenId
    ) external view returns (IVaultBase.Token[] memory) {
        return Controller.vaults(_vaultId).viewTokenAmounts(_tokenId);
    }

    // --------------------------------------------------------------------------------

    /**
    * @param _vault: Address of vault
    * @return 0: Not added to this contract; 1 = Active vault; 2 = Deactivated vault
    */
    function vault(address _vault) public view returns (uint8) {
        return Controller.vault(_vault);
    }

    // --------------------------------------------------------------------------------

    /**
    * @param _vault: Address of vault
    * @return Reverse mapping vault address to index in 'vaults'
    */
    function vaultId(address _vault) public view returns (uint256) {
        return Controller.vaultId(_vault);
    }

    // --------------------------------------------------------------------------------

    /**
    * @notice Includes active and added then deactivated vaults
    * @return Number of added vaults 
    */
    function vaultsLength() public view returns (uint256) {
        return Controller.vaultsLength();
    }

    // --------------------------------------------------------------------------------

    /**
    * @notice The prices used when creating trades need to be multiplied by the value
    * returned from this function. This is done to handle the decimals.
    * @param _vaultId: Index of vault in 'vaults'
    * @return Value to multiply with the price 
    */
    function priceMultiplier(uint256 _vaultId) external view returns (uint256) {
        return Controller.vaults(_vaultId).PRICE_MULTIPLIER();
    }

    // --------------------------------------------------------------------------------

    /**
    * @param _vaultId: Index of vault in 'vaults'
    * @param _tokenId: Vault token
    * @param _tradeIds: Trades within the vault token
    * @return Order[trade ID][order index] - Returns the trades and their orders 
    */
    function viewTrades(
        uint256 _vaultId, 
        uint256 _tokenId, 
        uint256[] memory _tradeIds
    ) external view returns (IVaultBase.Order[][] memory) {
        IVaultBase _vault = Controller.vaults(_vaultId);

        // Check for valid token ID
        require(
            _tokenId <= _vault.tokenCounter(), 
            "CornFi Controller View: Token ID Out of Range"
        );

        IVaultBase.Order[][] memory tradeOrders = new IVaultBase.Order[][](_tradeIds.length);

        // Loop through the trades
        for(uint i = 0; i < _tradeIds.length; i++) {

            // Check for valid trade ID
            require(
                _tradeIds[i] <= _vault._tokenTradeLength(_tokenId), 
                "CornFi Controller View: Trade ID Out of Range"
            );

            // Get the trade and its orders
            tradeOrders[i] = _viewTrade(_vault, _tokenId, _tradeIds[i]);
        }
        return tradeOrders;
    }

    // --------------------------------------------------------------------------------

    /**
    * @notice View a single order. Order can be open or closed.
    * @param _vaultId: Index of vault in 'vaults'
    * @param _orderId: Order to view
    * @return Order details 
    */
    function viewOrder(
        uint256 _vaultId, 
        uint256 _orderId
    ) public view returns (IVaultBase.Order memory) {
        return Controller.vaults(_vaultId).order(_orderId);
    }

    // --------------------------------------------------------------------------------

    /**
    * @notice View multiple orders. 
    * @param _vaultId: Index of vault in 'vaults'
    * @param _orderIds: Orders to view
    * @return Array of order details 
    */
    function viewOrders(
        uint256 _vaultId, 
        uint256[] memory _orderIds
    ) public view returns (IVaultBase.Order[] memory) {
        IVaultBase _vault = Controller.vaults(_vaultId);
        IVaultBase.Order[] memory _orders = new IVaultBase.Order[](_orderIds.length);

        // Loop through orders
        for(uint i = 0; i < _orderIds.length; i++) {
            _orders[i] = _vault.order(_orderIds[i]);
        }
        return _orders;
    }

    // --------------------------------------------------------------------------------

    /**
    * @param _vaultId: Index of vault in 'vaults'
    * @param _tokenId: Vault token
    * @return All open orders for a given vault token
    */ 
    function viewOpenOrdersByToken(
        uint256 _vaultId, 
        uint256 _tokenId
    ) public view returns (IVaultBase.Order[] memory) {
        IVaultBase _vault = Controller.vaults(_vaultId);

        // Get number of open orders for a vault token
        uint256 orderLength = _vault.tokenOpenOrdersLength(_tokenId);

        IVaultBase.Order[] memory _orders = new IVaultBase.Order[](orderLength);

        // Loop through open orders
        for(uint i = 0; i < orderLength; i++) {
            _orders[i] = _vault.order(_vault.tokenOpenOrderId(_tokenId, i));
        }
        return _orders;
    }

    // --------------------------------------------------------------------------------

    /**
    * @notice View multiple open orders in one call. Call may revert if the range is
    * too big.
    * @param _vaultId: Index of vault in 'vaults'
    * @param _start: Start index of 'openOrderIds' within the vault
    * @param _end: End index of 'openOrderIds' within the vault
    * @return Open orders inside the given range
    */ 
    function viewOpenOrdersInRange(
        uint256 _vaultId, 
        uint256 _start, 
        uint256 _end
    ) external view returns (IVaultBase.Order[] memory) {
        IVaultBase _vault = Controller.vaults(_vaultId);
        require(_end <= _vault.openOrdersLength(), "CornFi Controller View: Query Out of Range");
        IVaultBase.Order[] memory _orders = new IVaultBase.Order[](_end.sub(_start).add(1));
        for(uint i = _start; i <= _end; i++) {
            _orders[i.sub(_start)] = _vault.order(_vault.openOrderId(i));
        }
        return _orders;
    }

    // --------------------------------------------------------------------------------

    /**
    * @param _vaultId: Index of vault in 'vaults'
    * @return Number of orders created in the vault 
    */
    function ordersLength(uint256 _vaultId) external view returns (uint256) {
        return Controller.vaults(_vaultId).ordersLength();
    }

    // --------------------------------------------------------------------------------

    /**
    * @param _vaultId: Index of vault in 'vaults'
    * @return Number of open orders in the vault 
    */
    function openOrdersLength(uint256 _vaultId) external view returns (uint256) {
        return Controller.vaults(_vaultId).openOrdersLength();
    }

    // --------------------------------------------------------------------------------

    /**
    * @param _vaultId: Index of vault in 'vaults'
    * @param _tokenId: Vault token
    * @return Number of open orders for a token in a vault 
    */
    function tokenOpenOrdersLength(
        uint256 _vaultId, 
        uint256 _tokenId
    ) external view returns (uint256) {
        return Controller.vaults(_vaultId).tokenOpenOrdersLength(_tokenId);
    }

    // --------------------------------------------------------------------------------

    /**
    * @param _vaultId: Index of vault in 'vaults'
    * @return Number of all minted tokens in a vault (includes burnt tokens) 
    */
    function tokenLength(uint256 _vaultId) external view returns (uint256) {
        return Controller.vaults(_vaultId).tokenCounter();
    }

    // --------------------------------------------------------------------------------

    /**
    * @param _vaultId: Index of vault in 'vaults'
    * @param _tokenId: Vault token
    * @return Number of trades within a vault token 
    */
    function tokenTradeLength(
        uint256 _vaultId, 
        uint256 _tokenId
    ) external view returns (uint256) {
        return Controller.vaults(_vaultId)._tokenTradeLength(_tokenId);
    }

    // --------------------------------------------------------------------------------

    /**
    * @param _owner: Owner of vault tokens
    * @return All vault tokens the user owns. Returns the vault address and token ID
    */
    function vaultTokensByOwner(address _owner) external view returns (UserTokens[] memory) {
        uint256 _tokensLength = 0;

        // Get number of tokens the user owns accross all vaults
        for(uint256 k = 0; k < vaultsLength(); k++) {
            _tokensLength += Controller.vaults(k).balanceOf(_owner);
        }

        UserTokens[] memory userTokens = new UserTokens[](_tokensLength);
        uint256 counter = 0;

        // Loop through all vaults
        for(uint256 i = 0; i < vaultsLength(); i++) {
            // Loop through all tokens user owns within a vault
            for(uint256 j = 0; j < Controller.vaults(i).balanceOf(_owner); j++) {
                userTokens[counter++] = UserTokens(
                    address(Controller.vaults(i)), 
                    Controller.vaults(i).tokenOfOwnerByIndex(_owner, j)
                );
            }
        }

        return userTokens;
    }

    // --------------------------------------------------------------------------------

    /**
    * OoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOo
    */
    function tokenMaxGas(uint256 _vaultId, uint256 _tokenId) external view returns (uint256) {
        return Controller.tokenMaxGas(_vaultId, _tokenId);
    }

    // --------------------------------------------------------------------------------

    /**
    * OoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOo
    */
    function userGasAmounts(address _user) external view returns (uint256) {
        return Controller.GasTank().userGasAmounts(_user);
    }

    // --------------------------------------------------------------------------------

    /**
    * OoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOo
    */
    function vaults(uint256 _index) external view returns (IVaultBase) {
        return Controller.vaults(_index);
    }

    // --------------------------------------------------------------------------------

    /**
    * OoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOo
    */
    function vaultDetails(
        uint256 _vaultId
    ) external view returns (string memory, string memory, string memory, address) {
        return (
            Controller.vaults(_vaultId).name(),
            Controller.vaults(_vaultId).symbol(),
            Controller.vaults(_vaultId).BASE_URI(),
            address(Controller.vaults(_vaultId))
        );
    }


    // --------------------------------------------------------------------------------
    // ////////////////////////////// Internal Functions //////////////////////////////
    // --------------------------------------------------------------------------------    

    /**
    * @param _vault: Vault holding the trade
    * @param _tokenId: Vault token
    * @param _tradeId: Trade owned by the vault token
    * @return Orders within the trade 
    */
    function _viewTrade(
        IVaultBase _vault, 
        uint256 _tokenId, 
        uint256 _tradeId
    ) internal view returns (IVaultBase.Order[] memory) {
        // Get IDs of the orders within the trade 
        uint256[] memory tradeOrderIds = _vault.trade(_tokenId, _tradeId);

        IVaultBase.Order[] memory tradeOrders = new IVaultBase.Order[](tradeOrderIds.length);

        // Loop through the orders
        for(uint i = 0; i < tradeOrderIds.length; i++) {
            tradeOrders[i] = _vault.order(tradeOrderIds[i]);
        }
        return tradeOrders;
    }
}