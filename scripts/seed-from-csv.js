const fs = require('fs');
const csv = require('csv-parser');
const { ethers } = require('ethers');

// Update with your deployed vault address
const VAULT_ADDRESS = '0x2c787E4f5448A95f4F9B63cfb30cCEC5Ba31D43A';
const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
const signer = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

const vaultAbi = [
  'function depositFromBridge(address user, uint256 amount, string source) external'
];
const vault = new ethers.Contract(VAULT_ADDRESS, vaultAbi, signer);

async function seedFromCSV(filePath) {
  const results = [];
  fs.createReadStream(filePath)
    .pipe(csv())
    .on('data', (data) => results.push(data))
    .on('end', async () => {
      for (const row of results) {
        if (row.Debits && parseFloat(row.Debits) > 0) {
          const amount = ethers.parseUnits(row.Debits, 18);
          const tx = await vault.depositFromBridge(
            '0x0000000000000000000000000000000000000000', // treasury user or operator
            amount,
            row.Description || 'QuickBooks import'
          );
          console.log(`Seeded ${row.Debits} from ${row.AccountName}`);
          await tx.wait();
        }
      }
      console.log('✅ All treasury data seeded into vault');
    });
}

// Usage: node scripts/seed-from-csv.js ./quickbooks_journal_import_BALANCED.csv
seedFromCSV(process.argv[2]);