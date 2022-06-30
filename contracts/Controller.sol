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

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IVaultBase.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IPokeMe.sol";
import "./interfaces/IResolver.sol";
import "./interfaces/IStrategy.sol";
import "./interfaces/IGasTank.sol";


/**
* @title Corn Finance Controller
* @author C.W.B.
*/
contract Controller is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct UserTokens {
        address vault;
        uint256 tokenId;
    }

    uint8 public constant NOT_A_VAULT = 0;
    uint8 public constant ACTIVE_VAULT = 1;
    uint8 public constant DEACTIVATED_VAULT = 2;

    // Gelato address that receives the gas fee after execution
    address payable public constant gelato = payable(0x7598e84B2E114AB62CAB288CE5f7d5f6bad35BbA);

    // Native token
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // Contract that will call this contract to fill orders
    IPokeMe public PokeMe = IPokeMe(0x527a819db1eb0e34426297b03bae11F2f8B3A19E);

    // Contract for finding the best router and path for a given swap
    IResolver public Resolver;

    // Token used to pay Gelato for executing transactions
    address public GasToken = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // true: Gelato is active - Gelato will monitor orders and fill when executable
    // false: Gelato is inactive - Dev will monitor orders and fill when executable
    bool public Gelato;

    // taskIds[vaultId][tokenId] --> Gelato task ID
    // Gelato tasks are only created when 'Gelato' = true
    mapping(uint256 => mapping(uint256 => bytes32)) public taskIds;

    // tokenMaxGas[vaultId][tokenId] --> Max gas price (gwei)
    // Filling order txs will revert if the gas price exceeds what the user set
    mapping(uint256 => mapping(uint256 => uint256)) public tokenMaxGas;

    // All routers used for filling orders
    IUniswapV2Router02[] public routers;

    // activeRouters[router] --> true: Router is active; false: Router is inactive
    // Note: Deactivated routers are not removed from 'routers', be sure that the
    // router being used returns 'true' from the mapping below before using to 
    // fill orders.
    mapping(IUniswapV2Router02 => bool) public activeRouters;

    // All vaults
    IVaultBase[] public vaults;

    // _vaults[vault] --> 0: Vault not present in Controller; 1: Vault is active;
    // 2: Vault is deactivated
    mapping(address => uint8) internal _vaults;

    // _vaultIds[vault] --> Vault index of 'vaults' (i.e. vault ID)
    mapping(address => uint256) internal _vaultIds;

    // Dev wallet for protocol fees
    address public constant Fees = 0x93F835b9a2eec7D2E289c1E0D50Ad4dEd88b253f;

    // Community treasury for deposit fees
    address public constant DepositFees = 0xfC484aFB55D9EA9E186D8De55A0Aa24cbe772a19;

    // Slippage setting for when filling orders
    // slippage = SLIPPAGE_POINTS / SLIPPAGE_BASE_POINTS
    // 0.5% slippage --> SLIPPAGE_POINTS = 5; SLIPPAGE_BASE_POINTS = 1000
    uint256 public SLIPPAGE_POINTS;
    uint256 public SLIPPAGE_BASE_POINTS;

    // Contracts that hold trade tokens
    address[] public holdingStrategies;

    // _holdingStrategies[strategy] --> true: Active holding strategy; false: Holding
    // strategy not added yet.
    mapping(address => bool) internal _holdingStrategies;

    IGasTank public GasTank = IGasTank(0xCfbCCC95E48D481128783Fa962a1828f47Fc8A42);


    // --------------------------------------------------------------------------------
    // //////////////////////////////////// Events ////////////////////////////////////
    // --------------------------------------------------------------------------------
    event CreateTrade(address indexed _creator, uint256 indexed _vaultId, uint256 _tokenId);
    event CreateOrder(address indexed _creator, uint256 indexed _vaultId, uint256 _orderId);
    event FillOrder(address indexed _orderOwner, uint256 indexed _vaultId, uint256 indexed _tokenId, uint256 _orderId);
    event Withdraw(address indexed _owner, uint256 indexed _vaultId, uint256 indexed _tokenId);

    
    // --------------------------------------------------------------------------------
    // ////////////////////////////////// Modifiers ///////////////////////////////////
    // --------------------------------------------------------------------------------

    /**
    * @dev Restricts the caller to only the Gelato 'PokeMe' contract 
    */
    modifier onlyGelato() {
        require(
            msg.sender == address(PokeMe), 
            "CornFi Controller: Gelato Only Function"
        );
        require(Gelato, "CornFi Controller: Gelato Disabled");
        _;
    }


    // --------------------------------------------------------------------------------
    // --------------------------------------------------------------------------------
    // --------------------------------------------------------------------------------
    // --------------------------------------------------------------------------------

    /**
    * @param _slippagePoints: Highest acceptable slippage amount when executing swaps
    * @param _slippageBasePoints: (_slippagePoints / _slippageBasePoints) --> slippage %
    * @param _routers: Approved routers used for executing swaps. No new routers can be
    * added after deploying this contract.
    * @param _resolver: Gelato resolver contract used to find the router and swap path
    * that provides the highest output amount.
    */
    constructor(
        uint256 _slippagePoints,
        uint256 _slippageBasePoints,
        IUniswapV2Router02[] memory _routers,
        address _resolver
    ) {
        _setSlippage(_slippagePoints, _slippageBasePoints);
        Gelato = true;
        
        Resolver = IResolver(_resolver);
        for(uint i = 0; i < _routers.length; i++) {
            _addRouter(_routers[i]);
        }
    }


    // --------------------------------------------------------------------------------
    // //////////////////////// Contract Settings - Only Owner ////////////////////////
    // --------------------------------------------------------------------------------

    /**
    * @dev After calling, 'createTrade', 'fillOrder', 'fillOrderGelato', and 'depositGas'
    * functions will be disabled. Users will only be able to withdraw their trades and
    * any deposited gas. Only the owner of this contract can call this function.
    */
    function pause() external onlyOwner {
        _pause();
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Enables 'createTrade', 'fillOrder', 'fillOrderGelato', and 'depositGas'
    * functions. Only the owner of this contract can call this function.
    */
    function unpause() external onlyOwner {
        _unpause();
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Set the URI of a vault to display an image. Only the owner of this contract 
    * can call this function.
    * @param _vaultId: Vault that will have its URI set
    * @param _URI: IPFS link
    */
    function setVaultURI(uint256 _vaultId, string memory _URI) external onlyOwner {
        vaults[_vaultId].setBaseURI(_URI);
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Add a router to fill orders through
    * @param _router: Uniswap V2 router to add 
    */
    function addRouter(IUniswapV2Router02 _router) external onlyOwner {
        require(!activeRouters[_router], "CornFi Controller: Router already added");
        _addRouter(_router);
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Deactivated router will no longer be able to be used for filling orders.
    * Only the owner of this contract can call this function.
    * @param _router: Router to deactivate 
    */
    function deactivateRouter(IUniswapV2Router02 _router) external onlyOwner {
        activeRouters[_router] = false;
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Add a vault for trading. Vault must inherit 'VaultBase.sol' and meet the
    * vault standard for proper functionality. Only the owner of this contract can call 
    * this function.
    * @param _vault: Address of vault to add
    */
    function addVault(address _vault) external onlyOwner {
        require(_vaults[_vault] == NOT_A_VAULT);
        _vaultIds[_vault] = vaults.length;
        vaults.push(IVaultBase(_vault));
        _vaults[_vault] = ACTIVE_VAULT;
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Disables the 'createTrade', 'fillOrder', and 'fillOrderGelato' functions.
    * Once a vault is deactivated, users will only be able to withdraw their trades.
    * Deactivated vaults cannot be reactivated. Only the owner of this contract can 
    * call this function.
    * @param _vault: Address of vault to deactivate
    */
    function deactivateVault(address _vault) external onlyOwner {
        _vaults[_vault] = DEACTIVATED_VAULT;
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Set the slippage amount for each order being filled. Only the owner of this 
    * contract can call this function.
    * @param _slippagePoints: This value divided by '_slippageBasePoints' gives the 
    * slippage percentage.
    * @param _slippageBasePoints: Max amount of slippage points
    */
    function setSlippage(
        uint256 _slippagePoints, 
        uint256 _slippageBasePoints
    ) external onlyOwner {
        _setSlippage(_slippagePoints, _slippageBasePoints);
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Configure Gelato settings. Enable/disable filling orders with Gelato. Only 
    * the owner of this contract can call this function.
    * @param _pokeMe: Gelato contract that will call this contract
    * @param _resolver: Contract that the Gelato executor will call for the input data
    * used when calling this contract.
    * @param _gelato: true: Gelato fills orders; false: Dev fills orders
    */
    function gelatoSettings(
        IPokeMe _pokeMe, 
        IResolver _resolver, 
        bool _gelato,
        IGasTank _gasTank
    ) external onlyOwner {
        PokeMe = _pokeMe;
        Resolver = _resolver;
        Gelato = _gelato;
        GasTank = _gasTank;
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Deactivate an ERC20 token for a vault. Once a token is deactivated, it cannot
    * be reactivated. Only the owner can call this function.
    * @param _vaultId: Index of vault in 'vaults'
    * @param _token: ERC20 token address  
    */
    function deactivateToken(uint256 _vaultId, address _token) external onlyOwner {
        return vaults[_vaultId].deactivateToken(_token);
    } 

    // --------------------------------------------------------------------------------

    /**
    * @dev Map a holding strategy contract to an ERC20 token. A token can only be mapped
    * to holding strategy once. Only the owner of this contract can call this function.
    * @param _vaultId: Index of vault in 'vaults'
    * @param _token: ERC20 token address
    * @param _strategy: Holding strategy contract
    * @param _minDeposit: Minimum amount of '_token' that can be deposited when creating
    * a trade. 
    */
    function setTokenStrategy(
        uint256 _vaultId, 
        address _token, 
        address _strategy, 
        uint256 _minDeposit
    ) external onlyOwner {
        // Map the holding strategy to the ERC20 token
        vaults[_vaultId].setStrategy(_token, _strategy, _minDeposit);

        // Add the holding strategy address if not already done
        if(!_holdingStrategies[_strategy]) {
            holdingStrategies.push(_strategy);
            _holdingStrategies[_strategy] = true;
        }
    } 

    // --------------------------------------------------------------------------------

    /**
    * @dev Map multiple holding strategies to ERC20 tokens. A token can only be mapped
    * to holding strategy once. Only the owner of this contract can call this function.
    * @param _vaultId: Index of vault in 'vaults'
    * @param _tokens: ERC20 token addresses
    * @param _strategies: Holding strategy contracts
    * @param _minDeposits: Minimum amount of '_tokens[n]' that can be deposited when 
    * creating a trade. 
    */
    function setTokenStrategies(
        uint256 _vaultId, 
        address[] memory _tokens, 
        address[] memory _strategies, 
        uint256[] memory _minDeposits
    ) external onlyOwner {
        require(
            _tokens.length == _strategies.length && _tokens.length == _minDeposits.length, 
            "CornFi Controller: Invalid Lengths"
        );

        for(uint i = 0; i < _tokens.length; i++) {
            // Map the holding strategy to the ERC20 token
            vaults[_vaultId].setStrategy(_tokens[i], _strategies[i], _minDeposits[i]);

            // Add the holding strategy address if not already done
            if(!_holdingStrategies[_strategies[i]]) {
                holdingStrategies.push(_strategies[i]);
                _holdingStrategies[_strategies[i]] = true;
            }
        }
    } 

    // --------------------------------------------------------------------------------

    /**
    * @dev Change the minimum deposit amount for an ERC20 token when creating a trade.
    * ERC20 token must already be mapped to a holding strategy before calling this
    * function. Only the owner of this contract can call this function. 
    */
    function changeTokenMinimumDeposit(
        uint256 _vaultId, 
        address _token, 
        uint256 _minDeposit
    ) external onlyOwner {              
        vaults[_vaultId].changeMinimumDeposit(_token, _minDeposit);
    }


    // --------------------------------------------------------------------------------
    // ///////////////////////////// Read-Only Functions //////////////////////////////
    // --------------------------------------------------------------------------------

    /**
    * @notice Use to get the minimum amount out of a swap
    * @param _amountIn: Amount of a given ERC20 token
    * @return Adjusts '_amountIn' to account for slippage
    */
    function slippage(uint256 _amountIn) public view returns (uint256) {
        return _amountIn.sub(_amountIn.mul(SLIPPAGE_POINTS).div(SLIPPAGE_BASE_POINTS));
    }

    // --------------------------------------------------------------------------------

    /**
    * @param _vault: Address of vault
    * @return 0: Not added to this contract; 1 = Active vault; 2 = Deactivated vault
    */
    function vault(address _vault) public view returns (uint8) {
        return _vaults[_vault];
    }

    // --------------------------------------------------------------------------------

    /**
    * @param _vault: Address of vault
    * @return Reverse mapping vault address to index in 'vaults'
    */
    function vaultId(address _vault) public view returns (uint256) {
        return _vaultIds[_vault];
    }

    // --------------------------------------------------------------------------------

    /**
    * @notice Includes active and added then deactivated vaults
    * @return Number of added vaults 
    */
    function vaultsLength() public view returns (uint256) {
        return vaults.length;
    }

    // --------------------------------------------------------------------------------

    /**
    * @notice The prices used when creating trades need to be multiplied by the value
    * returned from this function. This is done to handle the decimals.
    * @param _vaultId: Index of vault in 'vaults'
    * @return Value to multiply with the price 
    */
    function priceMultiplier(uint256 _vaultId) external view returns (uint256) {
        return vaults[_vaultId].PRICE_MULTIPLIER();
    }

    // --------------------------------------------------------------------------------
    // //////////////////////// Vault State Changing Functions ////////////////////////
    // --------------------------------------------------------------------------------

    /**
    * @notice Create a trade with one of the approved vaults. The format for '_tokens',
    * '_amounts', and '_times' is specific to the vault. Refer to the vault being used
    * to verify the correct data format. Trades are only created with active vaults.
    * The strating amount of the trade is deposited upon creating a trade. A deposit fee
    * is taken from the deposited amount. When Gelato is active, a task is created for
    * each open order.
    * @param _vaultId: Index of vault in 'vaults'
    * @param _tokens: Specific to the vault used. Refer to vault documentation.
    * @param _amounts: Specific to the vault used. Refer to vault documentation.
    * @param _times: Specific to the vault used. Refer to vault documentation.
    * @param _maxGas: In gwei. The maximum gas price that any order within this trade
    * can be executed at.
    */
    function createTrade(
        uint256 _vaultId, 
        address[] memory _tokens, 
        uint256[] memory _amounts, 
        uint[] memory _times, 
        uint256 _maxGas
    ) external whenNotPaused nonReentrant {
        // Active vaults only
        require(
            vault(address(vaults[_vaultId])) == ACTIVE_VAULT, 
            "CornFi Controller: Inactive Vault"
        );

        // Create a trade and get the created orders 
        uint256[] memory orderIds = vaults[_vaultId].createTrade(
            msg.sender, 
            _tokens, 
            _amounts, 
            _times
        );
        IVaultBase.Order[] memory orders = _viewOrders(_vaultId, orderIds);

        emit CreateTrade(msg.sender, _vaultId, orders[0].tokenId);

        // Max gas price for when filling orders. Lower gas price saves the user ETH,
        // but increases the risk that their orders will not get filled during network
        // congestion.
        tokenMaxGas[_vaultId][orders[0].tokenId] = _maxGas;

        // When Gelato is active, create a task for the orders created. Gelato will monitor
        // each order and execute when trade conditions are met.
        _createGelatoTasks(msg.sender, _vaultId, orders);
    }

    // --------------------------------------------------------------------------------

    /**
    * @notice Fill open orders when trade conditions are met. Only Gelato executors
    * can call this function. This function is the primary method used to fill orders. 
    * If Gelato is no longer used, orders are filled through calling 'fillOrder()'
    * instead. Gelato executor will call 'checker()' in Resolver.sol first to get the 
    * router and path with the highest output amount. Gelato executor is refunded the 
    * gas cost from the ETH the order owner has deposited.
    * @param _vaultId: Index of vault in 'vaults'
    * @param _orderId: Order to fill
    * @param _router: Router used to fill the order
    * @param _path: Swap path used to fill the order
    */
    function fillOrderGelato(
        uint256 _vaultId, 
        uint256 _orderId, 
        IUniswapV2Router02 _router, 
        address[] memory _path
    ) external whenNotPaused onlyGelato nonReentrant {
        // Order to fill
        IVaultBase.Order memory _order = _viewOrder(_vaultId, _orderId);

        _verifyOrder(_router, _vaultId, _order);

        // Fill the order
        (
            IVaultBase.Order[] memory orders, 
            uint256[] memory filledOrders
        ) = vaults[_vaultId].fillOrder(_orderId, _router, _path);

        // Owner of the order being filled
        address orderOwner = vaults[_vaultId].ownerOf(_order.tokenId);

        emit FillOrder(orderOwner, _vaultId, _order.tokenId, _orderId);

        _cancelGelatoTasks(_vaultId, filledOrders);       

        _createGelatoTasks(orderOwner, _vaultId, orders);                                        

        (uint256 fee, ) = PokeMe.getFeeDetails();
        
        GasTank.pay(orderOwner, gelato, fee);
    }

    // --------------------------------------------------------------------------------

    /**
    * @notice Withdraws the ERC20 tokens owned by a vault token and returns to the token
    * owner. All open orders associated with the vault token are closed and the vault
    * token is burnt.
    * @param _vaultId: Index of vault in 'vaults'
    * @param _tokenId: Vault token  
    */
    function withdraw(uint256 _vaultId, uint256 _tokenId) external nonReentrant {
        // Get open orders for the vault token
        IVaultBase.Order[] memory _orders = _viewOpenOrdersByToken(_vaultId, _tokenId);

        // Cancel the tasks with Gelato 
        for(uint i = 0; i < _orders.length; i++) {
            if(taskIds[_vaultId][_orders[i].orderId] != 0) {
                PokeMe.cancelTask(taskIds[_vaultId][_orders[i].orderId]);
            }
        }

        // Withdraw ERC20 tokens and burn vault token
        vaults[_vaultId].withdraw(msg.sender, _tokenId);

        emit Withdraw(msg.sender, _vaultId, _tokenId);
    }


    // --------------------------------------------------------------------------------
    // ////////////////////////////// Internal Functions //////////////////////////////
    // --------------------------------------------------------------------------------    

    /**
    * @dev Whitelists a Uniswap V2 router for filling orders
    * @param _router: Router address
    */
    function _addRouter(IUniswapV2Router02 _router) internal {
        routers.push(_router);
        activeRouters[_router] = true;
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Sets the slippage amount used when filling orders
    * @param _slippagePoints: This value divided by '_slippageBasePoints' gives the 
    * slippage percentage.
    * @param _slippageBasePoints: Max amount of slippage points
    */
    function _setSlippage(uint256 _slippagePoints, uint256 _slippageBasePoints) internal {
        // Max slippage allowed is 2%
        require(
            _slippagePoints.mul(50) <= _slippageBasePoints, 
            "CornFi Controller: Max Slippage Exceeded"
        );
        SLIPPAGE_POINTS = _slippagePoints;
        SLIPPAGE_BASE_POINTS = _slippageBasePoints;
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Cancels a Gelato task for given orders. Orders cannot get filled after Gelato
    * task is canceled.
    * @param _vaultId: Index of vault in 'vaults'
    * @param _orderIds: List of orders to cancel Gelato tasks for
    */
    function _cancelGelatoTasks(uint256 _vaultId, uint256[] memory _orderIds) internal {
        // If the order has an associated task ID, cancel the task
        for(uint i = 0; i < _orderIds.length; i++) {   
            if(taskIds[_vaultId][_orderIds[i]] != bytes32(0)) { 
                PokeMe.cancelTask(taskIds[_vaultId][_orderIds[i]]);     
            }
        }
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Creates a Gelato task for given orders. Orders can get filled automatically 
    * after Gelato tasks are created.
    * @param _orderOwner: Owner of the orders
    * @param _vaultId: Index of vault in 'vaults'
    * @param _orders: List of orders to create Gelato tasks for
    */
    function _createGelatoTasks(
        address _orderOwner, 
        uint256 _vaultId, 
        IVaultBase.Order[] memory _orders
    ) internal {
        // When using Gelato to fill orders.
        // An order ID greater than '0' indicates a new order was created. Create a new
        // task with Gelato to monitor and fill the created order.
        if(Gelato) {
            for(uint j = 0; j < _orders.length; j++) {                                                          
                if(_orders[j].orderId != 0) {                                                            

                    emit CreateOrder(_orderOwner, _vaultId, _orders[j].orderId);

                    // Create a task with Gelato to monitor and fill the created order
                    taskIds[_vaultId][_orders[j].orderId] = PokeMe.createTaskNoPrepayment(
                        address(this), 
                        this.fillOrderGelato.selector, 
                        address(Resolver), 
                        abi.encodeWithSelector(
                            Resolver.checker.selector, 
                            _vaultId, 
                            _orders[j].orderId, 
                            _orders[j].tokens[0], 
                            _orders[j].tokens[1], 
                            _orders[j].amounts[0]
                        ),
                        GasToken
                    );
                }
            }     
        }             
    }

    // --------------------------------------------------------------------------------
    
    /**
    * @dev Verify an approved router is used to fill the order and ensure transaction
    * gas price is below the user set max.
    * @param _router: Router used to fill orderd
    * @param _vaultId: Index of vault in 'vaults'
    * @param _order: Order to fill
    */
    function _verifyOrder(
        IUniswapV2Router02 _router, 
        uint256 _vaultId, 
        IVaultBase.Order memory _order
    ) internal view {
        // Revert if the router is not whitelisted. 
        require(activeRouters[_router], "CornFi Controller: Invalid Router");

        // When tokenMaxGas = 0, the order can be fill at any gas price.
        // Otherwise, ensure that the gas price is below the user set max.
        if(tokenMaxGas[_vaultId][_order.tokenId] > 0) {
            require(
                tx.gasprice <= tokenMaxGas[_vaultId][_order.tokenId], 
                "CornFi Controller: Gas Price Too High"
            );
        }
    }

    // --------------------------------------------------------------------------------

    /**
    * @notice View a single order. Order can be open or closed.
    * @param _vaultId: Index of vault in 'vaults'
    * @param _orderId: Order to view
    * @return Order details 
    */
    function _viewOrder(
        uint256 _vaultId, 
        uint256 _orderId
    ) internal view returns (IVaultBase.Order memory) {
        return vaults[_vaultId].order(_orderId);
    }

    // --------------------------------------------------------------------------------

    /**
    * @notice View multiple orders. 
    * @param _vaultId: Index of vault in 'vaults'
    * @param _orderIds: Orders to view
    * @return Array of order details 
    */
    function _viewOrders(
        uint256 _vaultId, 
        uint256[] memory _orderIds
    ) internal view returns (IVaultBase.Order[] memory) {
        IVaultBase _vault = vaults[_vaultId];
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
    function _viewOpenOrdersByToken(
        uint256 _vaultId, 
        uint256 _tokenId
    ) internal view returns (IVaultBase.Order[] memory) {
        IVaultBase _vault = vaults[_vaultId];

        // Get number of open orders for a vault token
        uint256 orderLength = _vault.tokenOpenOrdersLength(_tokenId);

        IVaultBase.Order[] memory _orders = new IVaultBase.Order[](orderLength);

        // Loop through open orders
        for(uint i = 0; i < orderLength; i++) {
            _orders[i] = _vault.order(_vault.tokenOpenOrderId(_tokenId, i));
        }
        return _orders;
    }
}