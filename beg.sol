// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;

contract Game {
    address[] public players;
    mapping(address => uint256) public playerBids;
    uint256 public cycleEndTime;
    uint256 public cycleDuration = 3 hours;
    address public winner;

    constructor() {
        // Initialize the game
        // For simplicity, assume players are added externally after contract deployment
        cycleEndTime = block.timestamp + cycleDuration;
    }

    function submitBid(uint256 bid) public {
        require(block.timestamp < cycleEndTime, "Bidding period has ended");
        require(playerBids[msg.sender] == 0, "You have already submitted a bid");

        playerBids[msg.sender] = bid;
        players.push(msg.sender);
    }

    function endCycle() public {
        require(block.timestamp >= cycleEndTime, "Cycle is still ongoing");

        address lowestBidder = players[0];
        uint256 lowestBid = playerBids[lowestBidder];
        for (uint256 i = 1; i < players.length; i++) {
            address currentPlayer = players[i];
            if (playerBids[currentPlayer] < lowestBid) {
                lowestBid = playerBids[currentPlayer];
                lowestBidder = currentPlayer;
            }
        }

        // Eliminate the lowest bidder
        // You can implement your own logic for what happens to the eliminated player's resources
        winner = lowestBidder;
    }

    function getCurrentCycleEndTime() public view returns (uint256) {
        return cycleEndTime;
    }
}