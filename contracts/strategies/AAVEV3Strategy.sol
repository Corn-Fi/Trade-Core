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
import "../interfaces/IAaveStakeV3.sol";


pragma experimental ABIEncoderV2;

/**
* @title Corn Finance AAVE V3 Holding Strategy
* @author C.W.B.
*/
contract AAVEV3Strategy is StrategyBase {
    using SafeERC20 for IERC20;

    struct Tokens {
        address token;
        address amToken;
    }

    // AAVE lending pool
    IAaveStakeV3 public constant LendingPool = IAaveStakeV3(0x794a61358D6845594F94dc1DB02A252b5b4814aD);

    // AAVE rewards contract
    IAaveStakeV3 public constant Rewards = IAaveStakeV3(0x929EC64c34a17401F460460D4B9390518E5B473e);

    // Whitelisted ERC20 tokens that can be deposited into this contract
    address[] public tokens;

    // AAVE market tokens associated with 'tokens'
    address[] public aaveMarketTokens;

    // tokenToAm[ERC20] --> AAVE market token
    // ex. tokenToAm[USDC] --> amUSDC
    mapping(address => address) public tokenToAm;


    // --------------------------------------------------------------------------------
    // //////////////////////////////////// Events ////////////////////////////////////
    // --------------------------------------------------------------------------------
    event TokenAdded(address token, address amToken);


    // --------------------------------------------------------------------------------
    // --------------------------------------------------------------------------------
    // --------------------------------------------------------------------------------

    /**
    * @param _controller: Corn Finance Controller contract 
    */
    constructor( 
        IController _controller,
        address _rebalancer
    ) StrategyBase(_controller, 0, 1000, 0, 1000, _rebalancer, 0, 0) {

        Tokens[16] memory _tokens = [
            Tokens(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063, 0x82E64f49Ed5EC1bC6e43DAD4FC8Af9bb3A2312EE), // DAI, amDAI
            Tokens(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174, 0x625E7708f30cA75bfd92586e17077590C60eb4cD), // USDC, amUSDC
            Tokens(0xc2132D05D31c914a87C6611C10748AEb04B58e8F, 0x6ab707Aca953eDAeFBc4fD23bA73294241490620), // USDT, amUSDT
            Tokens(0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6, 0x078f358208685046a11C85e8ad32895DED33A249), // WBTC, amWBTC
            Tokens(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619, 0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8), // WETH, amWETH
            Tokens(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270, 0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97), // WMATIC, amWMATIC
            Tokens(0x85955046DF4668e1DD369D2DE9f3AEB98DD2A369, 0x724dc807b04555b71ed48a6896b6F41593b8C637), // DPI, amDPI
            Tokens(0x172370d5Cd63279eFa6d502DAB29171933a610AF, 0x513c7E3a9c69cA3e22550eF58AC1C0088e918FFf), // CRV, amCRV
            Tokens(0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39, 0x191c10Aa4AF7C30e871E70C95dB0E4eb77237530), // LINK, amLINK
            Tokens(0x0b3F868E0BE5597D5DB7fEB59E1CADBb0fdDa50a, 0xc45A479877e1e9Dfe9FcD4056c699575a1045dAA), // SUSHI, amSUSHI
            Tokens(0x9a71012B13CA4d3D0Cdc72A177DF3ef03b0E76A3, 0x8ffDf2DE812095b1D19CB146E4c004587C0A0692), // BAL, amBAL
            Tokens(0x385Eeac5cB85A38A9a07A70c73e0a3271CfB54A7, 0x8Eb270e296023E9D92081fdF967dDd7878724424), // GHST, amGHST
            Tokens(0xD6DF932A45C0f255f85145f286eA0b292B21C90B, 0xf329e36C7bF6E5E86ce2150875a84Ce77f477375), // AAVE, amAAVE
            Tokens(0xE111178A87A3BFf0c8d18DECBa5798827539Ae99, 0x38d693cE1dF5AaDF7bC62595A37D667aD57922e5), // EURS, amEURS
            Tokens(0x4e3Decbb3645551B8A19f0eA1678079FCB33fB4c, 0x6533afac2E7BCCB20dca161449A13A32D391fb00), // JEUR, amJEUR
            Tokens(0xE0B52e49357Fd4DAf2c15e02058DCE6BC0057db4, 0x8437d7C167dFB82ED4Cb79CD44B7a32A1dd95c77)  // AGEUR, amAGEUR
        ];
        for(uint i = 0; i < _tokens.length; i++) {
            _addToken(_tokens[i].token, _tokens[i].amToken);
        }
    }

    // --------------------------------------------------------------------------------
    // ///////////////////////////// Only Owner Functions /////////////////////////////
    // --------------------------------------------------------------------------------

    /**
    * @dev Use to add an ERC20 token and its respective AAVE market token. Only add
    * tokens that can be deposited into AAVE. This function is restricted to only the
    * owner of this contract.
    * @param _token: Tokens(ERC20 token address, AAVE market token equivalent)
    */
    function addToken(Tokens memory _token) external onlyOwner {
        _addToken(_token.token, _token.amToken);
    }

    // --------------------------------------------------------------------------------
    // ////////////////////////// Only Rebalancer Functions ///////////////////////////
    // --------------------------------------------------------------------------------

    /**
    * @dev Rebalance an ERC20 token held within this strategy. Claims the difference
    * between the token balance of the contract and the total deposits of the token.
    * Use to claim the interest made from staking tokens in AAVE.
    * @param _token: ERC20 token address to rebalance
    */
    function rebalanceTokenAAVE(address _token) external onlyRebalancer {
        // Difference between current balance and total deposits is the interest made
        uint256 interest = IERC20(tokenToAm[_token]).balanceOf(address(this)) - totalDeposits[_token];

        // Withdraw the interest made and send to the fee wallet
        if(interest > 0) {
            LendingPool.withdraw(_token, interest, feeAddress);

            require(
                IERC20(tokenToAm[_token]).balanceOf(address(this)) >= totalDeposits[_token],
                "CornFi AAVE Strategy: Balance Error"
            );

            emit Claim(_token, interest);
        }
        else {
            revert("CornFi AAVE Strategy: Token Already Balanced");
        }
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
                "CornFi AAVE Strategy: Balance Error"
            ); 
        }
        else {
            revert("CornFi AAVE Strategy: Token is Balanced");
        }
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Claim AAVE WMATIC incentive rewards from staking ERC20 tokens. Sends rewards
    * to the dev wallet. 
    */
    function claim() external onlyRebalancer {
        Rewards.claimAllRewards(aaveMarketTokens, feeAddress);
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Claim AAVE WMATIC incentive rewards from staking ERC20 tokens. Sends rewards
    * to the dev wallet. 
    */
    function emergencyClaim(address[] memory _amTokens) external onlyRebalancer {
        Rewards.claimAllRewards(_amTokens, feeAddress);
    }


    // --------------------------------------------------------------------------------
    // /////////////////////////////// Vault Functions ////////////////////////////////
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
        require(tokenToAm[_token] != address(0), "CornFi AAVE Strategy: Invalid Token");

        _deposit(_from, _token, _amount);

        // Approve AAVE lending pool to take (deposit) a token
        IERC20(_token).approve(address(LendingPool), _amount);

        // Deposit assets into AAVE lending pool
        LendingPool.supply(_token, _amount, address(this), uint16(0));
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
        require(tokenToAm[_token] != address(0), "CornFi AAVE Strategy: Invalid Token");

        // Difference between current balance and total deposits is the interest made
        uint256 interest = IERC20(tokenToAm[_token]).balanceOf(address(this)) - totalDeposits[_token];

        _withdraw(_token, _amount);

        // No interest made
        if(interest == 0) {
            // Withdraw tokens from AAVE and transfer to owner
            LendingPool.withdraw(_token, _amount, _from);
        }
        // Interest made
        else {
            // Withdraw tokens from AAVE and tranfer to this contract
            LendingPool.withdraw(_token, _amount + interest, address(this));

            // Transfer tokens to order owner
            IERC20(_token).safeTransfer(_from, _amount);
            
            // Claim interest
            IERC20(_token).safeTransfer(feeAddress, interest);
        }

        // Make sure the remaining token balance is correct
        require(
            IERC20(tokenToAm[_token]).balanceOf(address(this)) >= totalDeposits[_token],
            "CornFi AAVE Strategy: Balance Error"
        );
    }

    // --------------------------------------------------------------------------------
    // ////////////////////////////// Internal Functions //////////////////////////////
    // --------------------------------------------------------------------------------

    /**
    * @dev Use to add an ERC20 token and its respective AAVE market token. Only add
    * tokens that can be deposited into AAVE.
    * @param _token: ERC20 token address
    * @param _amToken: AAVE market token equivalent of '_token' 
    */
    function _addToken(address _token, address _amToken) internal {
        require(tokenToAm[_token] == address(0), "CornFi AAVE Strategy: Token already added");

        // Map token to AAVE market token
        tokenToAm[_token] = _amToken;

        // Add the token
        tokens.push(_token);

        // Add the AAVE market token
        aaveMarketTokens.push(_amToken);

        emit TokenAdded(_token, _amToken);
    }
}