// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0; 

// todo: 

// commit reveal for privacy 

//to be tested:
// after starting can't join;  
// test bidding and countdown; 
// can't rebid once bidded 


// done 
// check time left  
// fix countdown done error saying not in the participants list  

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

    // a contract receiving ether, msg.data must be empty  
    receive() external payable {}
    

    // only owner can update registrationFee and startingBalance 
    address public owner; 
    uint256 public registrationFee;  
    uint256 public startingBalance; 
    bool public openForJoin = true; 

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
        require(openForJoin, "game started. can't join now." );
        // add new player's wallet address to the list of addresses 
        players_addresses.push(msg.sender);
        // add new player's status to the list of players 
        player_status.push(player(true, startingBalance)); 

    }

    // Function to check the balance of the contract
    function getContractBalance() public view returns (uint) {
        return address(this).balance;
    }

} 


contract Game is Player_C {
    uint256 public cycleEndTime;
    uint256 public cycleDuration;
    mapping(address => uint256) public playerBids;
    address public loser;  
    uint256 public left;        // num of players left 
    uint256 public finalNumPlayer;  // parameter: num of people remaining to end the game. half of participants 
    uint256 public sumOfBalance; // total remaining balance of all remaining players when the game ends 

    // pass arg to base constructor 
    constructor(uint256 _fee, uint256 _balance, uint256 _duration) Player_C(_fee, _balance) {
        cycleDuration = _duration;
        setCycleEndTime(); 
        openForJoin = false; 
    } 

    function setFinalNumPlayer() internal {
        finalNumPlayer = uint(players_addresses.length / 2);
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

    function timeLeft() public view returns (uint) {
        return cycleEndTime - block.timestamp; 
    }


    function placeBid(uint256 _bid) public current  {
        uint index = getIndex(msg.sender); 
        require(player_status[index].balance >= _bid); 
        require(player_status[index].active = true);  
        require(playerBids[msg.sender] == 0, "bids already submitted. can't rebid.");
        playerBids[msg.sender] = _bid;
        player_status[index].balance -= _bid; 
    }

    // error: not in participants list when it is 
    function getIndex(address _address) view internal returns (uint) { 
        bool inclusion = false; 
        for (uint i = 0; i < players_addresses.length; i++) {
            if (players_addresses[i] == _address) {
                inclusion = true;
                return i;
            }
        }
        revert("The caller's address is not in the participants' list");
    } 

    function getLowestBidder() internal {
        address lowestBidder = players_addresses[0];
        uint256 lowestBid = playerBids[lowestBidder]; 
        for (uint i = 1; i < players_addresses.length; i++) {
            if (player_status[i].active == true) {
                if (playerBids[players_addresses[i]] < lowestBid) {
                    lowestBidder = players_addresses[i];
                    lowestBid = playerBids[players_addresses[i]];
                }
            }
        }
        loser = lowestBidder; 
    }

    modifier cycleEnds() {
        block.timestamp > cycleEndTime;
        _;
    }

    function elimination() public { 
        getLowestBidder(); 
        uint index = getIndex(loser);  
        player_status[index].active = false;  
        player_status[index].balance = 0;
        reset(); 
        finish();
    }

    function getActiveNum() internal { 
        uint activeNum; 
        for (uint i = 1; i < players_addresses.length; i++) {
            if (player_status[i].active == true) {
                activeNum += 1; 
            }
        left = activeNum; 
        }
    }

    modifier cont() {
        getActiveNum(); 
        require(left > finalNumPlayer, "Game Ends"); 
        _; 
    }

    function reset() internal cont {
        loser = address(0); 
        for (uint i = 0; i < players_addresses.length; i++) { 
            delete playerBids[players_addresses[i]];
        }
        setCycleEndTime(); 
    } 

    modifier end() {
        getActiveNum(); 
        require(left <= finalNumPlayer, "Game Ends");
        _; 
    }

    function finish() internal end {
        // split the pot based on balance pro rata  
        // is this referring to the parent contract? is fund in the parent contract?  
        uint totalContractBalance = getContractBalance();
        require(totalContractBalance > 0, "No balance to distribute");
        // get total balance of remaining bids 
        totalBalance(); 
        // Distribute funds proportionally to each player
        for (uint i = 0; i < player_status.length; i++) {
            if (player_status[i].active == true) {
                if (player_status[i].balance > 0) {
                    uint share = (totalContractBalance * player_status[i].balance) / sumOfBalance; 
                    if (share > 0) {
                        (bool sent, ) = payable(players_addresses[i]).call{value: share}("");
                        require(sent, "Failed to send Ether"); 
                    }
                }
            }
        }        
    }

    function totalBalance() internal {
        for (uint i = 1; i < players_addresses.length; i++) {
            sumOfBalance += player_status[i].balance;
        }
    }

}
