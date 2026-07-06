// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./HouseCredit.sol";

/**
 * @title TiggyVault
 * @dev Treasury vault for TiggyVault ZK Casino on Polygon CDK.
 *      - Accumulates 25% of losses
 *      - Integrates with HouseCredit for auto-loan repayment
 *      - Supports seeding from bridge/QuickBooks and sweeping to cold wallet
 */
contract TiggyVault is Ownable, ReentrancyGuard {
    // ============ STATE VARIABLES ============
    HouseCredit public houseCredit;
    address public coldWallet;

    mapping(address => uint256) public balances;
    uint256 public totalTreasury;

    // ============ EVENTS ============
    event TreasurySeeded(address indexed from, uint256 amount, string source);
    event LossAllocated(address indexed user, uint256 toVault);
    event Withdrawn(address indexed to, uint256 amount);
    event SweptToColdWallet(uint256 amount);
    event ColdWalletUpdated(address indexed oldWallet, address indexed newWallet);

    // ============ CONSTRUCTOR ============
    constructor(address _houseCredit) Ownable(msg.sender) {
        require(_houseCredit != address(0), "Invalid HouseCredit address");
        houseCredit = HouseCredit(_houseCredit);
    }

    // ============ ADMIN FUNCTIONS ============
    function setColdWallet(address _coldWallet) external onlyOwner {
        require(_coldWallet != address(0), "Invalid cold wallet");
        address oldWallet = coldWallet;
        coldWallet = _coldWallet;
        emit ColdWalletUpdated(oldWallet, _coldWallet);
    }

    function setHouseCredit(address _houseCredit) external onlyOwner {
        require(_houseCredit != address(0), "Invalid HouseCredit");
        houseCredit = HouseCredit(_houseCredit);
    }

    // ============ TREASURY SEEDING ============
    /**
     * @dev Seed treasury from bridge, QuickBooks CSV import, or owner deposit.
     *      Called by settlement bridge or admin script.
     */
    function depositFromBridge(
        address user,
        uint256 amount,
        string calldata source
    ) external nonReentrant {
        require(amount > 0, "Amount must be > 0");

        balances[user] += amount;
        totalTreasury += amount;

        emit TreasurySeeded(msg.sender, amount, source);
    }

    /**
     * @dev Direct owner funding from cold wallet or external source.
     */
    function fundFromColdWallet(uint256 amount) external payable onlyOwner nonReentrant {
        require(msg.value == amount, "ETH mismatch");
        totalTreasury += amount;
        emit TreasurySeeded(msg.sender, amount, "ColdWallet");
    }

    // ============ CORE GAME LOGIC ============
    /**
     * @dev Allocate 25% of bet/loss to vault + auto-repay HouseCredit loan (40%).
     *      Called by game contracts after each bet result.
     */
    function allocateLoss(address user, uint256 betAmount) external nonReentrant {
        require(betAmount > 0, "Invalid bet amount");

        uint256 toVault = (betAmount * 25) / 100; // 25% to treasury
        totalTreasury += toVault;

        // Auto-repay 40% of loss toward any outstanding loan
        if (address(houseCredit) != address(0)) {
            try houseCredit.repayFromLoss(betAmount) {} catch {}
        }

        emit LossAllocated(user, toVault);
    }

    /**
     * @dev Withdraw from vault. Requires loan to be fully repaid (via HouseCredit).
     */
    function withdraw(address to, uint256 amount) external nonReentrant {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be > 0");

        (uint256 loan,, bool canWithdraw) = houseCredit.getLoanStatus(msg.sender);
        require(canWithdraw, "Loan not cleared - cannot withdraw");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        balances[msg.sender] -= amount;
        totalTreasury -= amount;

        payable(to).transfer(amount);
        emit Withdrawn(to, amount);
    }

    // ============ COLD WALLET SWEEP ============
    /**
     * @dev Sweep a specific amount from treasury to cold wallet.
     */
    function sweepToColdWallet(uint256 amount) external onlyOwner nonReentrant {
        require(coldWallet != address(0), "Cold wallet not set");
        require(amount > 0 && amount <= address(this).balance, "Invalid sweep amount");

        totalTreasury -= amount;
        payable(coldWallet).transfer(amount);

        emit SweptToColdWallet(amount);
    }

    /**
     * @dev Emergency/full sweep of contract balance to cold wallet.
     */
    function sweepAllToCold() external onlyOwner nonReentrant {
        require(coldWallet != address(0), "Cold wallet not set");
        uint256 amount = address(this).balance;
        require(amount > 0, "Nothing to sweep");

        totalTreasury = 0;
        payable(coldWallet).transfer(amount);

        emit SweptToColdWallet(amount);
    }

    // ============ VIEW FUNCTIONS ============
    function getTreasuryBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getUserBalance(address user) external view returns (uint256) {
        return balances[user];
    }

    // ============ RECEIVE ============
    receive() external payable {
        totalTreasury += msg.value;
    }
}
