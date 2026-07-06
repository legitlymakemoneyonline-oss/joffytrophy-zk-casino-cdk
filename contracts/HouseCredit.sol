// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title HouseCredit
 * @dev Credit system for TiggyVault ZK Casino.
 *      - Tiered credit limits
 *      - Losses auto-repay 40% of outstanding loans
 *      - Withdrawals locked until loan is fully repaid
 */
contract HouseCredit is Ownable, ReentrancyGuard {
    // ============ STATE VARIABLES ============
    mapping(address => uint256) public creditLimit;
    mapping(address => uint256) public loanBalance;
    mapping(address => uint256) public stackBalance; // Player's current play balance

    // ============ EVENTS ============
    event LoanTaken(address indexed user, uint256 amount);
    event LoanRepaid(address indexed user, uint256 amount);
    event LoanCleared(address indexed user);
    event CreditLimitUpdated(address indexed user, uint256 newLimit);

    // ============ CONSTRUCTOR ============
    constructor() Ownable(msg.sender) {}

    // ============ ADMIN: CREDIT TIERS ============
    function setCreditLimit(address user, uint256 limit) external onlyOwner {
        creditLimit[user] = limit;
        emit CreditLimitUpdated(user, limit);
    }

    function batchSetCreditLimits(
        address[] calldata users,
        uint256[] calldata limits
    ) external onlyOwner {
        require(users.length == limits.length, "Array length mismatch");
        for (uint256 i = 0; i < users.length; i++) {
            creditLimit[users[i]] = limits[i];
            emit CreditLimitUpdated(users[i], limits[i]);
        }
    }

    // ============ PLAYER LOAN FUNCTIONS ============
    /**
     * @dev Take a loan up to credit limit. Only one active loan allowed.
     */
    function takeLoan(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be > 0");
        require(loanBalance[msg.sender] == 0, "Existing loan must be repaid first");
        require(amount <= creditLimit[msg.sender], "Exceeds credit limit");

        loanBalance[msg.sender] = amount;
        stackBalance[msg.sender] += amount;

        emit LoanTaken(msg.sender, amount);
    }

    /**
     * @dev Auto-called by TiggyVault when player loses a bet.
     *      Repays 40% of bet amount toward outstanding loan.
     */
    function repayFromLoss(uint256 betAmount) external nonReentrant {
        if (loanBalance[msg.sender] == 0) return;

        uint256 repayAmount = (betAmount * 40) / 100; // 40% of loss goes to loan repayment

        if (repayAmount > loanBalance[msg.sender]) {
            repayAmount = loanBalance[msg.sender];
        }

        loanBalance[msg.sender] -= repayAmount;

        emit LoanRepaid(msg.sender, repayAmount);

        if (loanBalance[msg.sender] == 0) {
            emit LoanCleared(msg.sender);
        }
    }

    /**
     * @dev Manual repayment (player can top up).
     */
    function manualRepay(uint256 amount) external payable nonReentrant {
        require(loanBalance[msg.sender] > 0, "No active loan");
        require(msg.value >= amount, "Insufficient payment");

        uint256 repayAmount = amount;
        if (repayAmount > loanBalance[msg.sender]) {
            repayAmount = loanBalance[msg.sender];
        }

        loanBalance[msg.sender] -= repayAmount;

        // Refund excess
        if (msg.value > repayAmount) {
            payable(msg.sender).transfer(msg.value - repayAmount);
        }

        emit LoanRepaid(msg.sender, repayAmount);

        if (loanBalance[msg.sender] == 0) {
            emit LoanCleared(msg.sender);
        }
    }

    // ============ VIEW FUNCTIONS ============
    function getLoanStatus(address user)
        external
        view
        returns (
            uint256 loan,
            uint256 stack,
            bool canWithdraw
        )
    {
        loan = loanBalance[user];
        stack = stackBalance[user];
        canWithdraw = (loan == 0);
    }

    function getCreditLimit(address user) external view returns (uint256) {
        return creditLimit[user];
    }

    function getOutstandingLoan(address user) external view returns (uint256) {
        return loanBalance[user];
    }
}
