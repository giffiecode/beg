var beg;   
var userAccount;

function startApp() {
    var begAddress = "YOUR_CONTRACT_ADDRESS";  
    beg = new web3js.eth.Contract(begABI, begAddress);

    var accountInterval = setInterval(function() {
        if (web3.eth.accounts[0] !== userAccount) {
            userAccount = web3.eth.accounts[0];
            getIndex(userAccount).then(displayPlayerStatus);
        }
    }, 100);  

    beg.events.CommitBid()
        .on("data", function(event) {
            let data = event.returnValues;
            getPlayerStatus(getIndex(userAccount)).then(displayPlayerStatus);
        }).on("error", console.error);
}

function displayPlayerStatus(index) {
    $("#players").empty();
    getPlayerStatus(index).then(function(player) {
        $("#players").append(`<div class="player">
            <ul>
                <li>status: ${player.active}</li>
                <li>balance: ${player.balance}</li>
            </ul>
        </div>`);
    });   
}

function displayTimeLeft() {
    $("#time").empty();
    timeLeft().then(function(time) {
        $("#time").append(`<div class="time">
            <ul>
                <li>status: ${time}</li>
            </ul>
        </div>`);
    });   
}

function joinGame() {
    $("#txStatus").text("Joining game. This may take a while...");
    beg.methods.add_player()
        .send({ from: userAccount, value: web3js.utils.toWei("10", "wei") })
        .on("receipt", function(receipt) {
            $("#txStatus").text("Successfully joined " + userAccount + "!");
            getPlayerStatus(getIndex(userAccount)).then(displayPlayerStatus);
        })
        .on("error", function(error) {
            $("#txStatus").text(error);
        });
}

function bid() {
    let hash = $("#bidInput").val();
    $("#txStatus").text("Committing hash. This may take a while...");
    beg.methods.placeBid(hash)
        .send({ from: userAccount })
        .on("receipt", function(receipt) {
            $("#txStatus").text("Successfully placed bid!");
            getPlayerStatus(getIndex(userAccount)).then(displayPlayerStatus);
        })
        .on("error", function(error) {
            $("#txStatus").text(error);
        });
}

function reveal() {
    let bid = prompt("Enter your bid:");
    let salt = prompt("Enter your salt:");
    $("#txStatus").text("Revealing bid. This may take a while...");
    beg.methods.revealBid(bid, salt)
        .send({ from: userAccount })
        .on("receipt", function(receipt) {
            $("#txStatus").text("Successfully revealed " + bid + "!");
            getPlayerStatus(getIndex(userAccount)).then(displayPlayerStatus);
        })
        .on("error", function(error) {
            $("#txStatus").text(error);
        });
}

function eliminate() {
    $("#txStatus").text("Eliminating. This may take a while...");
    beg.methods.eliminate()
        .send({ from: userAccount })
        .on("receipt", function(receipt) {
            $("#txStatus").text("Eliminated!");
            getPlayerStatus(getIndex(userAccount)).then(displayPlayerStatus);
        })
        .on("error", function(error) {
            $("#txStatus").text(error);
        });
}

function getIndex(address) {
    return beg.methods.getIndex(address).call();
}

function timeLeft() {
    return beg.methods.timeLeft().call(); 
}

function getPlayerStatus(index) {
    return beg.methods.player_status(index).call(); 
}

function getPlayerAddresses(index) {
    return beg.methods.player_addresses(index).call();
}

window.addEventListener('load', function() {
    if (typeof web3 !== 'undefined') {
        web3js = new Web3(web3.currentProvider);
    } else {
        console.log("Please install Metamask to use this app.");
    }
    startApp();
});

$(document).ready(function() {
    $("#joinGameButton").click(joinGame);
    $("#bidButton").click(bid);
    $("#revealButton").click(reveal);
    $("#eliminateButton").click(eliminate);
});