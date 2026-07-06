const hre = require("hardhat");

async function main() {
  const [deployer, coldWallet] = await hre.ethers.getSigners();

  console.log("Deploying contracts with account:", deployer.address);
  console.log("Cold wallet will be set to:", coldWallet.address);

  // 1. Deploy HouseCredit first
  const HouseCredit = await hre.ethers.getContractFactory("HouseCredit");
  const houseCredit = await HouseCredit.deploy();
  await houseCredit.waitForDeployment();
  const houseCreditAddr = await houseCredit.getAddress();
  console.log("HouseCredit deployed to:", houseCreditAddr);

  // 2. Deploy TiggyVault with HouseCredit address
  const TiggyVault = await hre.ethers.getContractFactory("TiggyVault");
  const tiggyVault = await TiggyVault.deploy(houseCreditAddr);
  await tiggyVault.waitForDeployment();
  const tiggyVaultAddr = await tiggyVault.getAddress();
  console.log("TiggyVault deployed to:", tiggyVaultAddr);

  // 3. Set cold wallet on TiggyVault
  await tiggyVault.setColdWallet(coldWallet.address);
  console.log("Cold wallet set on TiggyVault");

  console.log("\n=== DEPLOYMENT COMPLETE ===");
  console.log("HouseCredit:", houseCreditAddr);
  console.log("TiggyVault :", tiggyVaultAddr);
  console.log("Cold Wallet:", coldWallet.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
