// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { ethers } = require("hardhat");
const hre = require("hardhat");
const { addresses } = require("./addresses");

const ERC20 = require("../artifacts/contracts/interfaces/IERC20.sol/IERC20.json");
const CONTROLLER = require("../artifacts/contracts/Controller.sol/Controller.json");
const CONTROLLER_VIEW = require("../artifacts/contracts/ControllerView.sol/ControllerView.json");
const GAS_TANK = require("../artifacts/contracts/interfaces/IGasTank.sol/IGasTank.json");

// ----------------------------------------------------------------------------------
// //////////////////////////////// Helper Functions ////////////////////////////////
// ----------------------------------------------------------------------------------

async function fetchSigner() {
  const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY);
  const signer = wallet.connect(provider);
  console.log(`connected to ${signer.address}`);
  return signer;
}

// ----------------------------------------------------------------------------------

async function fetchContract(address, abi, signer) {
  const contract = new ethers.Contract(address, abi, signer);
  console.log(`loaded contract ${contract.address}`);
  return contract;
}

// ----------------------------------------------------------------------------------
// ///////////////////////////////// User Functions /////////////////////////////////
// ----------------------------------------------------------------------------------

async function approveStrategyWithERC20(tokenAddress, strategyAddress, amount, signer) {
  const erc20 = await fetchContract(tokenAddress, ERC20.abi, signer)
  return await erc20.approve(strategyAddress, amount);
}

// ----------------------------------------------------------------------------------

async function approveControllerWithGasTank(signer) {
  const gasTank = await fetchContract(addresses.gasTank, GAS_TANK.abi, signer);
  return await gasTank.approve(addresses.controller, true);
}

// ----------------------------------------------------------------------------------

async function depositGasTank(amount, signer) {
  const gasTank = await fetchContract(addresses.gasTank, GAS_TANK.abi, signer);
  return await gasTank.deposit(signer.address, amount);
}

// ----------------------------------------------------------------------------------

async function withdrawGasTank(amount, signer) {
  const gasTank = await fetchContract(addresses.gasTank, GAS_TANK.abi, signer);
  return await gasTank.withdraw(amount);
}

// ----------------------------------------------------------------------------------

async function createLimitOrder(
  fromToken, 
  fromTokenDecimals,
  toToken, 
  amountIn, 
  price,      // amountIn / desiredAmountOut
  expirationTime, 
  maxGas, 
  signer
) {
  const amountInAdj = ethers.utils.parseUnits(amountIn, fromTokenDecimals);
  const priceAdj = ethers.utils.parseEther(price);
  const maxGasAdj = ethers.utils.parseUnits(maxGas, "gwei");

  const controller = await fetchContract(addresses.controller, CONTROLLER.abi, signer);
  return await controller.createTrade(0, [fromToken, toToken], [amountInAdj, priceAdj], [expirationTime], maxGasAdj);
}

// ----------------------------------------------------------------------------------

async function withdraw(vaultId, tokenId, signer) {
  const controller = await fetchContract(addresses.controller, CONTROLLER.abi, signer);
  return await controller.withdraw(vaultId, tokenId);
}

// ----------------------------------------------------------------------------------

async function vaultTokensByOwner(owner, signer) {
  const controllerView = await fetchContract(addresses.controllerView, CONTROLLER_VIEW.abi, signer);
  const vaultTokens = await controllerView.vaultTokensByOwner(owner);
  const vaults = [];
  for(const vault of vaultTokens) {
      vaults.push({
          vault: vault.vault,
          tokenId: vault.tokenId.toNumber()
      })
  }
  return vaults;
}

// ----------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------

async function main() {
  const signer = await fetchSigner();
  const v = await vaultTokensByOwner(signer.address, signer);
  console.log(v);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
