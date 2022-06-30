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

import "../interfaces/IController.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


pragma experimental ABIEncoderV2;

/**
* @title Corn Finance Strategy Base
* @author C.W.B.
*/
abstract contract StrategyBase is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    // Controller contract
    IController public immutable controller;
    
    // totalDeposits[ERC20] --> Amount deposited into this contract
    mapping(address => uint256) public totalDeposits;

    // vaultDeposits[vault][ERC20] --> Amount 'vault' has deposited into this contract
    mapping(address => mapping(address => uint256)) public vaultDeposits;

    // Fee wallet
    address public constant feeAddress = 0x93F835b9a2eec7D2E289c1E0D50Ad4dEd88b253f;

    // Address that can call 'onlyRebalancer' functions
    address public Rebalancer;

    // Numerator of unstaked/staked ratio
    uint256 public rebalancePoints;

    // Denominator of unstaked/staked ratio
    uint256 public rebalanceBasePoints;

    // Deposit fee
    // Fee = points / base points
    uint256 public immutable DEPOSIT_FEE_POINTS;
    uint256 public immutable DEPOSIT_FEE_BASE_POINTS;

    // Transaction fee
    // Fee = points / base points
    uint256 public immutable TX_FEE_POINTS;
    uint256 public immutable TX_FEE_BASE_POINTS;


    // --------------------------------------------------------------------------------
    // //////////////////////////////////// Events ////////////////////////////////////
    // --------------------------------------------------------------------------------
    event Deposit(address indexed vault, address indexed token, uint256 amount);
    event Withdraw(address indexed vault, address indexed token, uint256 amount);
    event Claim(address indexed token, uint256 amount);


    // --------------------------------------------------------------------------------
    // ////////////////////////////////// Modifiers ///////////////////////////////////
    // --------------------------------------------------------------------------------

    /**
    * @dev Allows access to only currently active vaults and deactivated vaults. Vaults
    * that have not been added to the controller contract are restricted.
    */
    modifier onlyVault {
        require(
            controller.vault(msg.sender) != controller.NOT_A_VAULT(), 
            "CornFi Strategy Base: Vault Only Function"
        );
      _;
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Allows access to only currently active vaults. Vaults that have not been 
    * added to the controller contract and deactivated vaults are restricted.
    */
    modifier onlyActiveVault {
        require(
            controller.vault(msg.sender) == controller.ACTIVE_VAULT(), 
            "CornFi Strategy Base: Active Vault Only Function"
        );
      _;
    }

    // --------------------------------------------------------------------------------

    modifier onlyRebalancer {
        require(msg.sender == Rebalancer, "CornFi Strategy Base: Invalid Caller");
        _;
    }


    // --------------------------------------------------------------------------------
    // --------------------------------------------------------------------------------
    // --------------------------------------------------------------------------------

    /**
    * @param _controller: Corn Finance Controller contract 
    */
    constructor(
        IController _controller, 
        uint256 _depositFeePoints, 
        uint256 _depositFeeBasePoints, 
        uint256 _txFeePoints, 
        uint256 _txFeeBasePoints,
        address _rebalancer,
        uint256 _rebalancePoints,
        uint256 _rebalanceBasePoints
    ) {
        controller = _controller;
        DEPOSIT_FEE_POINTS = _depositFeePoints;
        DEPOSIT_FEE_BASE_POINTS = _depositFeeBasePoints;
        TX_FEE_POINTS = _txFeePoints;
        TX_FEE_BASE_POINTS = _txFeeBasePoints;
        _rebalanceSettings(_rebalancer, _rebalancePoints, _rebalanceBasePoints);
    }

    // --------------------------------------------------------------------------------

    /**
    * @param _amountIn: Amount of an ERC20 token
    * @return The corresponding deposit fee amount 
    */
    function depositFee(uint256 _amountIn) external view returns (uint256) {
        if(DEPOSIT_FEE_POINTS > 0) {
            return _amountIn.mul(DEPOSIT_FEE_POINTS).div(DEPOSIT_FEE_BASE_POINTS);
        }
        else {
            return 0;
        }
    }

    // --------------------------------------------------------------------------------

    /**
    * @param _amountIn: Amount of an ERC20 token
    * @return The corresponding transaction fee amount 
    */
    function txFee(uint256 _amountIn) external view returns (uint256) {
        if(TX_FEE_POINTS > 0) {
            return _amountIn.mul(TX_FEE_POINTS).div(TX_FEE_BASE_POINTS);
        }
        else {
            return 0;
        }
    }

    // --------------------------------------------------------------------------------

    function rebalanceSettings(
        address _rebalancer, 
        uint256 _rebalancePoints, 
        uint256 _rebalanceBasePoints
    ) external onlyOwner {
        _rebalanceSettings(_rebalancer, _rebalancePoints, _rebalanceBasePoints);
    }

    // --------------------------------------------------------------------------------

    /**
    * @param _rebalancer: Caller approved to rebalance
    */
    function _rebalanceSettings(
        address _rebalancer, 
        uint256 _rebalancePoints, 
        uint256 _rebalanceBasePoints
    ) internal {
        Rebalancer = _rebalancer;
        require(
            _rebalancePoints <= _rebalanceBasePoints, 
            "CornFi Strategy Base: Invalid Rebalance Ratio"
        );
        rebalancePoints = _rebalancePoints;
        rebalanceBasePoints = _rebalanceBasePoints;
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Only currently active vaults can deposits tokens into this holding strategy.
    * This function can only be called from one of the approved vaults added to the
    * Controller contract. Tokens are deposited into holding strategies when calling
    * 'createTrade()' and 'fillOrder()' in the Controller contract.
    * @param _from: Vault token owner
    * @param _token: ERC20 token address
    * @param _amount: Amount of '_token' to deposit
    */
    function _deposit(address _from, address _token, uint256 _amount) internal {
        if(_amount > 0) {
            IERC20 depositToken = IERC20(_token);

            // For a security check after transfer
            uint256 balanceBefore = depositToken.balanceOf(address(this));

            // Transfer deposit amount from user
            depositToken.safeTransferFrom(_from, address(this), _amount);

            // Ensure full amount is transferred
            require(
                depositToken.balanceOf(address(this)).sub(balanceBefore) == _amount, 
                "CornFi Strategy Base: Deposit Error"
            );

            // Increase the total deposits
            totalDeposits[_token] = totalDeposits[_token].add(_amount);

            // Increase the vault deposits
            vaultDeposits[msg.sender][_token] = vaultDeposits[msg.sender][_token].add(_amount);

            emit Deposit(msg.sender, _token, _amount);
        }
        else {
            revert("CornFi Strategy Base: Deposit Amount '0'");
        }
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Any vault that has deposited tokens into this strategy can withdraw their
    * tokens even after a vault is deactivated. This function can only be called from 
    * one of the approved vaults added to the Controller contract. Users are only able
    * to withdraw tokens from a holding strategy through withdrawing their vault token
    * by calling 'withdraw()' in the Controller contract.
    * @param _from: Vault token owner
    * @param _token: ERC20 token address
    * @param _amount: Amount of '_token' to withdraw
    */
    function _withdrawTransfer(address _from, address _token, uint256 _amount) internal {
        // This prevents the owner from creating a malicious vault that could withdraw all tokens
        require(
            _amount <= vaultDeposits[msg.sender][_token], 
            "CornFi Strategy Base: Vault Withdraw Amount Exceeded"
        );
        
        if(_amount > 0) {
            // Transfer tokens from this contract to the owner
            IERC20(_token).safeTransfer(_from, _amount);

            // Subtract withdrawn amount from total deposited amount
            totalDeposits[_token] = totalDeposits[_token].sub(_amount);

            // Subtract withdrawn amount from the vault deposited amount
            vaultDeposits[msg.sender][_token] = vaultDeposits[msg.sender][_token].sub(_amount);

            emit Withdraw(msg.sender, _token, _amount);
        }
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Any vault that has deposited tokens into this strategy can withdraw their
    * tokens even after a vault is deactivated. This function can only be called from 
    * one of the approved vaults added to the Controller contract. Users are only able
    * to withdraw tokens from a holding strategy through withdrawing their vault token
    * by calling 'withdraw()' in the Controller contract.
    * @param _token: ERC20 token address
    * @param _amount: Amount of '_token' to withdraw
    */
    function _withdraw(address _token, uint256 _amount) internal {
        // This prevents the owner from creating a malicious vault that could withdraw all tokens
        require(
            _amount <= vaultDeposits[msg.sender][_token], 
            "CornFi Strategy Base: Vault Withdraw Amount Exceeded"
        );
        
        if(_amount > 0) {
            // Subtract withdrawn amount from total deposited amount
            totalDeposits[_token] = totalDeposits[_token].sub(_amount);

            // Subtract withdrawn amount from the vault deposited amount
            vaultDeposits[msg.sender][_token] = vaultDeposits[msg.sender][_token].sub(_amount);

            emit Withdraw(msg.sender, _token, _amount);
        }
    }
}