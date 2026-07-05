const hre = require("hardhat");

const VAULT_ADDRESS = "0x2c787E4f5448A95f4F9B63cfb30cCEC5Ba31D43A";
const COLD_WALLET = "0x62Dd399bED5aB37A6E5720d7c1D7B1a3b9c9dE06";

const HouseCredit = await hre.ethers.getContractFactory("HouseCredit");
const houseCredit = await HouseCredit.deploy();
await houseCredit.waitForDeployment();
console.log("HouseCredit deployed to:", await houseCredit.getAddress());

const TiggyVault = await hre.ethers.getContractFactory("TiggyVault");
const tiggyVault = await TiggyVault.deploy(await houseCredit.getAddress());
await tiggyVault.waitForDeployment();
console.log("TiggyVault deployed to:", await tiggyVault.getAddress());

// Optional: set cold wallet as authorized for sweeps
await tiggyVault.setColdWallet(COLD_WALLET);
console.log("Cold wallet set for accumulation:", COLD_WALLET);