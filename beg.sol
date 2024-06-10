// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0; 

// todo: finish game, final push, last   

contract Player_C { 
    constructor(uint256 _fee, uint256 _balance) {
        owner = msg.sender;
        registrationFee = _fee;
        startingBalance = _balance; 
    }

    // full participant addresses list 
    address[] public players_addresses; 

    // player struct 
    struct player {
        bool active;
        uint balance;
    }

    // full lists of player 
    player[] public player_status; 
    

    // only owner can update registrationFee and startingBalance 
    address public owner; 
    uint256 public registrationFee;  
    uint256 public startingBalance;

    modifier onlyOwner() {
        require(msg.sender == owner); 
        _;
    }

    function setOwner(address _owner) public onlyOwner {
        owner = _owner;
    }

    function setRegistrationFee(uint256 _fee) public onlyOwner {
        registrationFee = _fee;
    }

    function setStartingBalance(uint256 _balance) public onlyOwner {
        startingBalance = _balance;
    }

    // caller's address isn't in the players' list    
    modifier newPlayer(address _address) {
        bool found = false;
        for (uint i = 0; i < players_addresses.length; i++) {
            if (players_addresses[i] == _address) { 
                found = true;
                break;
            }
        }
        require(!found, "Address is already in the players list"); 
        _;
        }
    
    // caller has sent sufficient ether 
    modifier costs (uint amount) {
        require(msg.value >= amount, "Insufficient Ether sent");
        _;
        // Refund any excess Ether sent
        if (msg.value > amount) {
            payable(msg.sender).transfer(msg.value - amount);
        }
    }
    
    function add_player() external payable newPlayer(msg.sender) costs(registrationFee) {
        // add new player's wallet address to the list of addresses 
        players_addresses.push(msg.sender);
        // add new player's status to the list of players 
        player_status.push(player(true, startingBalance)); 

    }
} 


contract Game is Player_C {
    uint256 public cycleEndTime;
    uint256 public cycleDuration;
    mapping(address => uint256) public playerBids;
    address public loser;  
    uint256 public finalNumPlayer; 


    // pass arg to base constructor 
    constructor(uint256 _fee, uint256 _balance, uint256 _duration) Player_C(_fee, _balance) {
        cycleDuration = _duration;
        setCycleEndTime(); 
    } 

    function setCycleDuration(uint256 _duration) public onlyOwner {
        cycleDuration = _duration; 
    } 

    function setCycleEndTime() internal {
        cycleEndTime = block.timestamp + cycleDuration; 
    }

    function setFinalNumPlayer(uint256 _num) public onlyOwner {
        finalNumPlayer = _num; 
    } 

    modifier current() {
        block.timestamp <= cycleEndTime;
        _;
    } 

    function placeBid(uint256 _bid) public current {
        uint index = getIndex(msg.sender); 
        require(player_status[index].balance >= _bid); 
        require(player_status[index].active = true); 
        playerBids[msg.sender] = _bid;
        player_status[index].balance -= _bid; 
    }

    function getIndex(address _address) view internal returns (uint256) { 
        bool inclusion = false; 
        for (uint256 i = 0; i < players_addresses.length; i++) {
            if (players_addresses[i] == _address) {
                inclusion = true;
                return i;
            }
        }
        require(inclusion == true, "the caller's address is not in the participants' list");
    } 

    function getLowestBidder() internal {
        address lowestBidder = players_addresses[0];
        uint256 lowestBid = playerBids[lowestBidder];  
        for (uint i = 1; i < players_addresses.length; i++) {
            if (playerBids[players_addresses[i]] < lowestBid) {
                lowestBidder = players_addresses[i];
                lowestBid = playerBids[players_addresses[i]];
            }
        }
        loser = lowestBidder; 
        elimination(loser);
        reset(); 
    }

    function elimination(address _address) public {
        uint index = getIndex(_address); 
        player_status[index].active = false;  
        player_status[index].balance = 0;
    }

    // todo: length of active players > final num 
    modifier cont() {
        p
    }
 
    function reset() internal cont {
        loser = address(0); 
        for (uint i = 0; i < players_addresses.length; i++) { 
            delete playerBids[players_addresses[i]];
        }  
    }
}
