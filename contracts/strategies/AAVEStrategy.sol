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
import "../interfaces/IAaveStake.sol";


pragma experimental ABIEncoderV2;

/**
* @title Corn Finance AAVE Holding Strategy
* @author C.W.B.
*/
contract AAVEStrategy is StrategyBase {
    using SafeERC20 for IERC20;

    struct Tokens {
        address token;
        address amToken;
    }

    // AAVE lending pool
    IAaveStake public constant LendingPool = IAaveStake(0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf);

    // AAVE rewards contract
    IAaveStake public constant Rewards = IAaveStake(0x357D51124f59836DeD84c8a1730D72B749d8BC23);

    // Whitelisted ERC20 tokens that can be deposited into this contract
    address[] public tokens;

    // AAVE market tokens associated with 'tokens'
    address[] public aaveMarketTokens;

    // tokenToAm[ERC20] --> AAVE market token
    // ex. tokenToAm[USDC] --> amUSDC
    mapping(address => address) public tokenToAm;

    // AAVE incentives reward token
    address public constant rewardToken = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;


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

        Tokens[13] memory _tokens = [
            Tokens(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063, 0x27F8D03b3a2196956ED754baDc28D73be8830A6e), // DAI, amDAI
            Tokens(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174, 0x1a13F4Ca1d028320A707D99520AbFefca3998b7F), // USDC, amUSDC
            Tokens(0xc2132D05D31c914a87C6611C10748AEb04B58e8F, 0x60D55F02A771d515e077c9C2403a1ef324885CeC), // USDT, amUSDT
            Tokens(0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6, 0x5c2ed810328349100A66B82b78a1791B101C9D61), // WBTC, amWBTC
            Tokens(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619, 0x28424507fefb6f7f8E9D3860F56504E4e5f5f390), // WETH, amWETH
            Tokens(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270, 0x8dF3aad3a84da6b69A4DA8aeC3eA40d9091B2Ac4), // WMATIC, amWMATIC
            Tokens(0x85955046DF4668e1DD369D2DE9f3AEB98DD2A369, 0x81fB82aAcB4aBE262fc57F06fD4c1d2De347D7B1), // DPI, amDPI
            Tokens(0x172370d5Cd63279eFa6d502DAB29171933a610AF, 0x3Df8f92b7E798820ddcCA2EBEA7BAbda2c90c4aD), // CRV, amCRV
            Tokens(0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39, 0x0Ca2e42e8c21954af73Bc9af1213E4e81D6a669A), // LINK, amLINK
            Tokens(0x0b3F868E0BE5597D5DB7fEB59E1CADBb0fdDa50a, 0x21eC9431B5B55c5339Eb1AE7582763087F98FAc2), // SUSHI, amSUSHI
            Tokens(0x9a71012B13CA4d3D0Cdc72A177DF3ef03b0E76A3, 0xc4195D4060DaEac44058Ed668AA5EfEc50D77ff6), // BAL, amBAL
            Tokens(0x385Eeac5cB85A38A9a07A70c73e0a3271CfB54A7, 0x080b5BF8f360F624628E0fb961F4e67c9e3c7CF1), // GHST, amGHST
            Tokens(0xD6DF932A45C0f255f85145f286eA0b292B21C90B, 0x1d2a0E5EC8E5bBDCA5CB219e649B565d8e5c3360)  // AAVE, amAAVE
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
    function rebalanceToken(address _token) external onlyRebalancer {
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
    * @dev Claim AAVE WMATIC incentive rewards from staking ERC20 tokens. Sends rewards
    * to the dev wallet. 
    */
    function claim() external onlyRebalancer {
        // Claim Aave WMATIC rewards, if any
        if(Rewards.getRewardsBalance(aaveMarketTokens, address(this)) > 0) {
            uint256 reward = Rewards.claimRewards(aaveMarketTokens, type(uint256).max, feeAddress);

            emit Claim(rewardToken, reward);
        }
        else {
            revert("CornFi AAVE Strategy: Nothing to Claim");
        }
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
        LendingPool.deposit(_token, _amount, address(this), uint16(0));
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

        _withdraw(_token, _amount);

        // Withdraw tokens from AAVE and transfer to owner
        LendingPool.withdraw(_token, _amount, _from);
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
        // Map token to AAVE market token
        tokenToAm[_token] = _amToken;

        // Add the token
        tokens.push(_token);

        // Add the AAVE market token
        aaveMarketTokens.push(_amToken);

        emit TokenAdded(_token, _amToken);
    }
}