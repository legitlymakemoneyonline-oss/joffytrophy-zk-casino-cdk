const hre = require("hardhat");

// Cold wallet address for treasury sweeps
const COLD_WALLET = "0x62Dd399bED5aB37A6E5720d7c1D7B1a3b9c9dE06";

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  console.log("=== TIGGYVAULT DEPLOYMENT TO POLYGON MAINNET ===");
  console.log("Deployer:", deployer.address);
  console.log("Cold Wallet:", COLD_WALLET);

  // Check deployer balance
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("Deployer POL balance:", hre.ethers.formatEther(balance), "POL");

  if (balance === 0n) {
    console.error("ERROR: Deployer wallet has 0 POL — cannot deploy!");
    process.exit(1);
  }

  // 1. Deploy HouseCredit first
  console.log("\n--- Deploying HouseCredit ---");
  const HouseCredit = await hre.ethers.getContractFactory("HouseCredit");
  const houseCredit = await HouseCredit.deploy();
  await houseCredit.waitForDeployment();
  const houseCreditAddr = await houseCredit.getAddress();
  console.log("✅ HouseCredit deployed to:", houseCreditAddr);

  // 2. Deploy TiggyVault with HouseCredit address
  console.log("\n--- Deploying TiggyVault ---");
  const TiggyVault = await hre.ethers.getContractFactory("TiggyVault");
  const tiggyVault = await TiggyVault.deploy(houseCreditAddr);
  await tiggyVault.waitForDeployment();
  const tiggyVaultAddr = await tiggyVault.getAddress();
  console.log("✅ TiggyVault deployed to:", tiggyVaultAddr);

  // 3. Set cold wallet on TiggyVault
  console.log("\n--- Setting Cold Wallet ---");
  const tx = await tiggyVault.setColdWallet(COLD_WALLET);
  await tx.wait();
  console.log("✅ Cold wallet set to:", COLD_WALLET);

  console.log("\n========================================");
  console.log("   DEPLOYMENT COMPLETE!");
  console.log("========================================");
  console.log("HouseCredit :", houseCreditAddr);
  console.log("TiggyVault  :", tiggyVaultAddr);
  console.log("Cold Wallet  :", COLD_WALLET);
  console.log("Deployer     :", deployer.address);
  console.log("Network      : Polygon Mainnet (137)");
  console.log("========================================");

  // Verify on PolygonScan
  console.log("\n--- Waiting 30s before verification ---");
  await new Promise(resolve => setTimeout(resolve, 30000));

  console.log("Verifying HouseCredit on PolygonScan...");
  try {
    await hre.run("verify:verify", {
      address: houseCreditAddr,
      constructorArguments: [],
    });
    console.log("✅ HouseCredit verified!");
  } catch (e) {
    console.log("⚠️ HouseCredit verification failed:", e.message);
  }

  console.log("Verifying TiggyVault on PolygonScan...");
  try {
    await hre.run("verify:verify", {
      address: tiggyVaultAddr,
      constructorArguments: [houseCreditAddr],
    });
    console.log("✅ TiggyVault verified!");
  } catch (e) {
    console.log("⚠️ TiggyVault verification failed:", e.message);
  }

  console.log("\n🎉 ALL DONE!");
}

main().catch((error) => {
  console.error("DEPLOYMENT ERROR:", error);
  process.exitCode = 1;
});
