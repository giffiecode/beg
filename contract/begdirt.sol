// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0; 

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
        uint dirt;
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
        player_status.push(player(true, startingBalance, 0)); 

    }

    // Function to check the balance of the contract
    function getContractBalance() public view returns (uint) {
        return address(this).balance;
    } 

    // check the total number of players 
    function getTotalNumOfPlayer() public view returns (uint) {
        assert(players_addresses.length == player_status.length);
        return players_addresses.length;
    }
} 

contract Game is Player_C {
    uint256 public cycleEndTime; 
    uint256 public revealEndTime;
    uint256 public cycleDuration;
    mapping(address => uint256) public committedHashes; 
    mapping(address => uint256) public playerBids;
    address[] public loser;  
    uint256 public left;        // num of players left 
    uint256 public finalNumPlayer;  // parameter: num of people remaining to end the game. half of participants 
    uint256 public sumOfBalance; // total remaining balance of all remaining players when the game ends   


    // event - indexed? 
    event ContractBalance(uint balance);
    event EtherSent(address recipient, uint amount); 
    event CommitBid(address indexed player, uint hash); 
    event RevealBid(address indexed player, uint256 amount, uint256 salt);

    constructor(uint256 _fee, uint256 _balance, uint256 _duration) Player_C(_fee, _balance) {
        cycleDuration = _duration;
    }  


    // suppose to be internal 
    function startGame() public { 
        setCycleEndTime();  
        setRevealEndTime(); 
        openForJoin = false;
        setFinalNumPlayer(); 
        left = players_addresses.length;  
        for (uint i = 0; i < players_addresses.length; i++) { 
            playerBids[players_addresses[i]] = 0;
        }
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

    function setRevealEndTime() internal {
        revealEndTime = block.timestamp + cycleDuration + cycleDuration;  
    }

    function setFinalNumPlayer(uint256 _num) public onlyOwner {
        finalNumPlayer = _num; 
    } 

    modifier current() {
        require(block.timestamp <= cycleEndTime);
        _;
    }  

    modifier revealing() {
        require(block.timestamp > cycleEndTime); 
        require(block.timestamp <= revealEndTime); 
        _; 
    }

    function timeLeft() public view returns (uint) {
        require(openForJoin == false, "game hasn't started yet!"); 
        if (block.timestamp >= cycleEndTime) {
            return 0; 
        } else {
            return cycleEndTime - block.timestamp; 
        }
    }

    function revealTimeLeft() public view returns (uint) {
        require(openForJoin == false, "game hasn't started yet!");  
        require(block.timestamp > cycleEndTime);
        if (block.timestamp >= revealEndTime) {
            return 0;
        } else {
            return revealEndTime - block.timestamp; 
        }
    }


    // ethers.solidityPackedKeccak256(["uint256", "uint256"], [bid, salt]);  
    function placeBid(uint256 _hash) public current  {
        uint index = getIndex(msg.sender); 
        require(player_status[index].active = true);   
        require(committedHashes[msg.sender] == 0, "hashes already committed. can't re-commit"); 
        require(playerBids[msg.sender] == 0, "bids already submitted. can't rebid.");
        committedHashes[msg.sender] = _hash; 
        emit CommitBid(msg.sender, _hash); 
    } 

    function revealBid(uint256 _bid, uint256 _salt) public revealing {
        // if player fail to reveal, assume bid 0 
        // if player is eliminated, elimination check active status and ignore their 0 
        uint index = getIndex(msg.sender); 
        require(player_status[index].balance >= _bid);  
        require(playerBids[msg.sender] == 0, "bids already submitted. can't rebid.");    
        require(committedHashes[msg.sender] == uint256(keccak256(abi.encodePacked(_bid, _salt))),
            "Not Revealed: verification failed"); 
        playerBids[msg.sender] = _bid;  
        player_status[index].balance -= _bid; 
        emit RevealBid(msg.sender, _bid, _salt);  
    }
    
    // omittable 
    // for testing purpose only      
    function hash(uint256 _bid, uint256 _salt) public pure returns(uint256) {
        return uint256(keccak256(abi.encodePacked(_bid, _salt))); 
    } 

    function getIndex(address _address) view internal returns (uint) {
        for (uint i = 0; i < players_addresses.length; i++) {
            if (players_addresses[i] == _address) {
                return i;
            }
        }
        revert("wallet not in the participants list"); 
    }

    // storage memory calldata event ?? 
    function getIndexList(address[] memory _address) view internal returns (uint[] memory) { 
        // bool inclusion = false;  
        uint[] memory tempResult = new uint[](_address.length);
        uint count = 0;

        for (uint i = 0; i < _address.length; i++) {
            for (uint j = 0; j < players_addresses.length; j++) {
                if (players_addresses[j] == _address[i]) {
                    tempResult[count] = j;
                    count++;
                    break; // Optional: Break if each address in _address is unique
                }
            }
        }

        // Create a result array with the exact size of the number of matches found
        uint[] memory result = new uint[](count);
        for (uint k = 0; k < count; k++) {
            result[k] = tempResult[k];
        }
        return result;
    } 

    function getLowestBidder() internal {
        address lowestBidder = players_addresses[0];
        uint256 lowestBid = playerBids[lowestBidder]; 
        for (uint i = 0; i < players_addresses.length; i++) {
            if (player_status[i].active == true) {
                if (playerBids[players_addresses[i]] < lowestBid) {
                    lowestBid = playerBids[players_addresses[i]]; 
                    delete loser; 
                    loser.push(players_addresses[i]);  
                }
                else if (playerBids[players_addresses[i]] == lowestBid) {
                    loser.push(players_addresses[i]); 
                }
            }
        }
    }

    modifier cycleEnds() {
        require(block.timestamp > revealEndTime); 
        _;
    }


    function elimination() public cycleEnds { 
        getLowestBidder(); 
        uint[] memory index = getIndexList(loser); // = getIndex(loser);   
        for (uint i = 0; i < index.length; i++) {
            player_status[index[i]].active = false;  
            player_status[index[i]].balance = 0;
        }
        getActiveNum(); 
        if (left > finalNumPlayer) {
            reset();
        } else {
            finish(); 
        }
    }

    function getActiveNum() public { 
        uint activeNum; 
        for (uint i = 0; i < players_addresses.length; i++) {
            if (player_status[i].active == true) {
                activeNum += 1; 
            }
        left = activeNum; 
        }
    }

    // negligible 
    modifier cont() {
        getActiveNum(); 
        require(left > finalNumPlayer, "Game Ends"); 
        _; 
    }

    function reset() internal cont {
        delete loser; 
        for (uint i = 0; i < players_addresses.length; i++) { 
            delete playerBids[players_addresses[i]];
        }
        setCycleEndTime();   
        setRevealEndTime();  
    } 

    // negligible 
    modifier end() {
        getActiveNum(); 
        require(left <= finalNumPlayer, "Game Continue");
        _; 
    }

    function sendViaCall(address payable _to) public payable {
        // Call returns a boolean value indicating success or failure.
        // This is the current recommended method to use.
        (bool sent, ) = _to.call{value: msg.value}("");
        require(sent, "Failed to send Ether");
    }

    function finish() internal end {
        // split the pot based on balance pro rata  
        // is this referring to the parent contract? is fund in the parent contract?  
        uint totalContractBalance = getContractBalance();
        require(totalContractBalance > 0, "No balance to distribute"); 
        // emit ContractBalance(totalContractBalance); 
        // get total balance of remaining bids 
        totalBalance(); 
        // Distribute funds proportionally to each player
        for (uint i = 0; i < player_status.length; i++) {
            if (player_status[i].active == true) {
                if (player_status[i].balance > 0) {
                    uint share = (totalContractBalance * player_status[i].balance) / sumOfBalance; 
                    if (share > 0) {
                        this.sendViaCall{value: share}(payable(players_addresses[i])); 
                        emit EtherSent(players_addresses[i], share); 
                    }
                }
            }
        }        
    }

    function totalActivePlayer() view internal returns(uint) { 
        uint count;
        for (uint i = 1; i < player_status.length; i++) {
            if (player_status[i].active == true) {
                count += 1;
            }
        }
        return count;
    }

    // omitable 
    // Function to get all player bids
    function getAllBids() external view returns (address[] memory, uint256[] memory) {
        uint256 length = players_addresses.length;
        address[] memory addresses = new address[](length);
        uint256[] memory bids = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            addresses[i] = players_addresses[i];
            bids[i] = playerBids[addresses[i]];
        }
        return (addresses, bids);
    }
    
    // omitable 
    function getAllHashes() external view returns (address[] memory, uint256[] memory) {
        uint256 length = players_addresses.length;
        address[] memory addresses = new address[](length);
        uint256[] memory hashes = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            addresses[i] = players_addresses[i];
            hashes[i] = committedHashes[addresses[i]];
        }
        return (addresses, hashes);
    }

    function totalBalance() public {
        sumOfBalance = 0;
        for (uint i = 0; i < players_addresses.length; i++) {
            if (player_status[i].active) {
                sumOfBalance += player_status[i].balance;
            }
        }
    }
}
