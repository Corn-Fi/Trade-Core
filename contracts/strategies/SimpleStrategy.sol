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

import "./StrategyBase.sol";


/**
* @title Corn Finance Simple Holding Strategy
* @author C.W.B.
*/
contract SimpleStrategy is StrategyBase {
    using SafeERC20 for IERC20;

    /**
    * @dev Set the deposit fee to 0.4% and transaction fee to 0.1%
    * @param _controller: Corn Finance Controller contract 
    */
    constructor(
        IController _controller,
        address _rebalancer
    ) StrategyBase(_controller, 4, 1000, 1, 1000, _rebalancer, 0, 0) {}

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
    function deposit(address _from, address _token, uint256 _amount) external onlyActiveVault {
        _deposit(_from, _token, _amount);
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
    function withdraw(address _from, address _token, uint256 _amount) external onlyVault {
        _withdrawTransfer(_from, _token, _amount);
        require(
            IERC20(_token).balanceOf(address(this)) >= totalDeposits[_token],
            "CornFi Simple Strategy: Balance Error"
        );  
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Rebalance an ERC20 token held within this strategy. Claims the difference
    * between the token balance of the contract and the total deposits of the token.
    * @param _token: ERC20 token address to rebalance
    */
    function rebalanceToken(address _token) external onlyRebalancer {
        uint256 balance = IERC20(_token).balanceOf(address(this));
        if(balance > totalDeposits[_token]) {
            uint256 interest = balance - totalDeposits[_token]; 
            IERC20(_token).safeTransfer(feeAddress, interest);
            require(
                IERC20(_token).balanceOf(address(this)) >= totalDeposits[_token],
                "CornFi Simple Strategy: Balance Error"
            ); 
        }
        else {
            revert("CornFi Simple Strategy: Token is Balanced");
        }
    }
}