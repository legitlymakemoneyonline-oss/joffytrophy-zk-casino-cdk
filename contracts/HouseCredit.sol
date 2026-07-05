// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract HouseCredit {
    address public owner;
    mapping(address => uint256) public creditLimit;
    mapping(address => uint256) public loanBalance;
    mapping(address => uint256) public stackBalance;

    event LoanTaken(address indexed user, uint256 amount);
    event LoanRepaid(address indexed user, uint256 amount);
    event LoanCleared(address indexed user);

    constructor() {
        owner = msg.sender;
    }

    function takeLoan(uint256 amount) external {
        require(loanBalance[msg.sender] == 0, "Existing loan");
        require(amount <= creditLimit[msg.sender], "Exceeds limit");
        loanBalance[msg.sender] = amount;
        stackBalance[msg.sender] += amount;
        emit LoanTaken(msg.sender, amount);
    }

    function repayFromLoss(uint256 betAmount) external {
        if (loanBalance[msg.sender] == 0) return;
        uint256 repayAmount = (betAmount * 40) / 100; // 40% of loss to loan
        if (repayAmount > loanBalance[msg.sender]) repayAmount = loanBalance[msg.sender];
        loanBalance[msg.sender] -= repayAmount;
        emit LoanRepaid(msg.sender, repayAmount);
        if (loanBalance[msg.sender] == 0) emit LoanCleared(msg.sender);
    }

    function getLoanStatus(address user) external view returns (uint256 loan, uint256 stack, bool canWithdraw) {
        return (loanBalance[user], stackBalance[user], loanBalance[user] == 0);
    }

    // Admin function to set credit limit (tie to tiers later)
    function setCreditLimit(address user, uint256 limit) external {
        require(msg.sender == owner, "Only owner");
        creditLimit[user] = limit;
    }
}