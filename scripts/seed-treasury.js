const hre = require("hardhat");

async function main() {
  const [signer] = await hre.ethers.getSigners();

  const TIGGYVAULT_ADDRESS = "0xYOUR_TIGGYVAULT_ADDRESS"; // <-- UPDATE AFTER DEPLOY
  const COLD_WALLET = "0xYOUR_COLD_WALLET_ADDRESS";        // <-- UPDATE AFTER DEPLOY

  const TiggyVault = await hre.ethers.getContractAt("TiggyVault", TIGGYVAULT_ADDRESS);

  console.log("Connected to TiggyVault at:", TIGGYVAULT_ADDRESS);
  console.log("Signer:", signer.address);

  // Example: Seed 25 MATIC from QuickBooks-style import or bridge
  const seedAmount = hre.ethers.parseEther("25.0");

  console.log(`Seeding ${hre.ethers.formatEther(seedAmount)} MATIC to treasury...`);
  await TiggyVault.depositFromBridge(
    signer.address,
    seedAmount,
    "QuickBooks Journal Import - June 2026"
  );

  console.log("Treasury seeded successfully!");
}

main().catch(console.error);
