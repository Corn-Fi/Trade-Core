// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./IVaultBase.sol";
import "./IUniswapV2Router02.sol";
import "./IPokeMe.sol";
import "./IResolver.sol";
import "./IStrategy.sol";
import "./IGasTank.sol";


pragma experimental ABIEncoderV2;

interface IController {
    
    struct UserTokens {
        address vault;
        uint256 tokenId;
    }

    // --------------------------------------------------------------------------------
    // ///////////////////////////// Only Owner Functions /////////////////////////////
    // --------------------------------------------------------------------------------

    function pause() external;
    function unpause() external;
    function setVaultURI(uint256 _vaultId, string memory _URI) external;
    function deactivateRouter(IUniswapV2Router02 _router) external;
    function addVault(address _vault) external;
    function deactivateVault(address _vault) external;
    function setSlippage(uint256 _slippagePoints, uint256 _slippageBasePoints) external;
    function gelatoSettings(IPokeMe _pokeMe, IResolver _resolver, bool _gelato) external;
    function deactivateToken(uint256 _vaultId, address _token) external;
    function setTokenStrategy(uint256 _vaultId, address _token, address _strategy, uint256 _minDeposit) external;
    function changeTokenMinimumDeposit(uint256 _vaultId, address _token, uint256 _minDeposit) external;

    // --------------------------------------------------------------------------------
    // ///////////////////////////// Read-Only Functions //////////////////////////////
    // --------------------------------------------------------------------------------

    function NOT_A_VAULT() external view returns (uint8);
    function ACTIVE_VAULT() external view returns (uint8);
    function DEACTIVATED_VAULT() external view returns (uint8);
    function gelato() external view returns (address);
    function ETH() external view returns (address);
    function PokeMe() external view returns (IPokeMe);
    function Resolver() external view returns (IResolver);
    function GasToken() external view returns (address);
    function Gelato() external view returns (bool);
    function taskIds(uint256 _vaultId, uint256 _orderId) external view returns (bytes32);
    function tokenMaxGas(uint256 _vaultId, uint256 _tokenId) external view returns (uint256);
    function GasTank() external view returns (IGasTank);

    function routers(uint256 _index) external view returns (IUniswapV2Router02);
    function activeRouters(IUniswapV2Router02 _router) external view returns (bool);
    function vaults(uint256 _index) external view returns (IVaultBase);
    function Fees() external view returns (address);
    function DepositFees() external view returns (address);
    function SLIPPAGE_POINTS() external view returns (uint256);
    function SLIPPAGE_BASE_POINTS() external view returns (uint256);
    function holdingStrategies(uint256 _index) external view returns (address);
    function priceMultiplier(uint256 _vaultId) external view returns (uint256);
    
    function tokenStrategy(uint256 _vaultId, address _token) external view returns (IStrategy);
    function tokenMinimumDeposit(uint256 _vaultId, address _token) external view returns (uint256);
    function tokens(uint256 _vaultId, uint256 _index) external view returns (address);
    function activeTokens(uint256 _vaultId, address _token) external view returns (bool);
    function tokensLength(uint256 _vaultId) external view returns (uint256);
    function slippage(uint256 _amountIn) external view returns (uint256);
    function vaultURI(uint256 _vaultId) external view returns (string memory);
    function vault(address _vault) external view returns (uint8);
    function vaultId(address _vault) external view returns (uint256);
    function vaultsLength() external view returns (uint256);
    
    function viewTrades(
        uint256 _vaultId, 
        uint256 _tokenId, 
        uint256[] memory _tradeIds
    ) external view returns (IVaultBase.Order[][] memory);
    
    function viewOrder(
        uint256 _vaultId, 
        uint256 _orderId
    ) external view returns (IVaultBase.Order memory);
    
    function viewOrders(
        uint256 _vaultId, 
        uint256[] memory _orderIds
    ) external view returns (IVaultBase.Order[] memory);
    
    function viewOpenOrdersByToken(
        uint256 _vaultId, 
        uint256 _tokenId
    ) external view returns (IVaultBase.Order[] memory);
    
    function viewOpenOrdersInRange(
        uint256 _vaultId, 
        uint256 _start, 
        uint256 _end
    ) external view returns (IVaultBase.Order[] memory);
    
    function ordersLength(uint256 _vaultId) external view returns (uint256);
    function openOrdersLength(uint256 _vaultId) external view returns (uint256);
    
    function tokenOpenOrdersLength(
        uint256 _vaultId, 
        uint256 _tokenId
    ) external view returns (uint256);
    
    function tokenLength(uint256 _vaultId) external view returns (uint256);

    function tokenTradeLength(
        uint256 _vaultId, 
        uint256 _tokenId
    ) external view returns (uint256);

    function vaultTokensByOwner(address _owner) external view returns (UserTokens[] memory);


    // --------------------------------------------------------------------------------
    // /////////////////////////////// Vault Functions ////////////////////////////////
    // --------------------------------------------------------------------------------

    function createTrade(
        uint256 _vaultId, 
        address[] memory _tokens, 
        uint256[] memory _amounts, 
        uint[] memory _times, 
        uint256 _maxGas
    ) external;

    function fillOrderGelato(
        uint256 _vaultId, 
        uint256 _orderId, 
        IUniswapV2Router02 _router, 
        address[] memory _path
    ) external;

    function withdraw(uint256 _vaultId, uint256 _tokenId) external;
}