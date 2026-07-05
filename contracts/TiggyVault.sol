// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IHouseCredit {
    function repayFromLoss(uint256 betAmount) external;
    function getLoanStatus(address user) external view returns (uint256, uint256, bool);
}

contract TiggyVault {
    address public owner;
    mapping(address => uint256) public balances;
    uint256 public totalTreasury;
    IHouseCredit public houseCredit;

    event Deposited(address indexed from, uint256 amount, string source);
    event Withdrawn(address indexed to, uint256 amount);
    event LossAllocated(address indexed user, uint256 amountToVault);

    constructor(address _houseCredit) {
        owner = msg.sender;
        houseCredit = IHouseCredit(_houseCredit);
    }

    // Called by settlement bridge with real treasury data
    function depositFromBridge(address user, uint256 amount, string memory source) external {
        require(msg.sender == owner || msg.sender == address(this), "Only bridge/owner");
        balances[user] += amount;
        totalTreasury += amount;
        emit Deposited(user, amount, source);
    }

    function allocateLoss(address user, uint256 betAmount) external {
        uint256 toVault = (betAmount * 25) / 100; // 25% to vault
        // In real flow, this would come from game contract
        totalTreasury += toVault;
        houseCredit.repayFromLoss(betAmount); // auto-repay loan
        emit LossAllocated(user, toVault);
    }

    function withdraw(address to, uint256 amount) external {
        (uint256 loan,, bool canWithdraw) = houseCredit.getLoanStatus(msg.sender);
        require(canWithdraw, "Loan not cleared");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        payable(to).transfer(amount);
        emit Withdrawn(to, amount);
    }

    // Admin: fund from cold wallet or bridge
    function fundFromColdWallet(uint256 amount) external payable {
        require(msg.sender == owner, "Only owner");
        totalTreasury += amount;
    }

    receive() external payable {
        totalTreasury += msg.value;
    }
}