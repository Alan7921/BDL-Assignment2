// SPDX-License-Identifier: MIT

/*** This contract is the Coursework2 for BDL course of UoE in 2021 fall.
 * It simulates a whole procedure of the so-called MatchingPennies game.
 *
 * The game has 4 stages, which are waitPlayers, makeDecision, verification and roundover respectively.
 * Two players are required to start the game, so the first stage is waiting for players.
 * In the waitPlayers stage, players are allowed to bet their money into contract,
 * if and only if players deposit enough money, could they join the game.
 * In the makeDecision stage, players need to send hash value to the contract respectively as their commitment.
 * In the verification stage, players need to provide the token and number they chose from 0/1 to culculate hash value as a proof
 * In the last stage, the contract would announce the result of winner in this round.
 * If both players do not cheat, and the two numbers are equal, the player2 wins, else player1 wins.
 * During the roundover stage, players are allowed to continute or withdraw their money and quit the game.
*
* @author Xin Liu UNN: s2176226
* @version 1.0
*/

pragma solidity >=0.7.0 <0.9.0;

contract MatchingPennies {

    // creat a struct to store the releated info of each player
    struct player{
        // address of player
        address playerAddress;
        // balance of player
        uint256 playerBalance;
        // commitment of player
        bytes32 commitment;
        // choice that player made from 0 or 1
        bytes1  choice;
        // whether the commitment matches with the committed value player sent
        bool isVerified;
        // whether the player has sent his/her commitment
        bool isCommitted;
        //whether the user has joined the game
        bool joined;
        // whether this address is included in mapping or not
        bool used;
        // whether the user has cheat or not
        bool violations;
        // 0 refers to player A, 1 refers to player B
        uint8 seatNo;
    }

    // creat two enum types to present that game is in which stage and whether there is someone who tried to cheat
    enum State { waitPlayers, makeDecision, verification, announcement,roundover }
    // the cheating status, single A, single B, or both cheating
    enum ViolationState {bothCheat,aCheat,bCheat,noCheat}

    //Game status Control
    State public gameState = State.waitPlayers;
    ViolationState public cheatState = ViolationState.noCheat;

    // use a mapping to store the details of each player
    mapping (address => player)players;
    // use numberOfCurrentPlayers and seats to show the current number of players and which seat they chose : 0 refers playerA, 1 refers playerB
    // use numberOfCommitments,numberOfVerified and numberOfViolations to make sure enough players have concuct action in each stage
    uint8 numberOfCurrentPlayers = 0;
    uint8 numberOfCommitments = 0;
    uint8 numberOfVerified = 0;
    uint8 numberOfViolations =0;
    //arraies to store address, seats and cheat condiction of players
    address [2] playersAddr;
    bool [2] seats;
    bool [2] cheatCondition;
    // a balance for the conract, it would get ethers when players cheat
    uint contractBalance = 0;

    // hand fee
    uint constant public HAND_FEE = 0.1 ether;
    uint constant public JETTON = 1.0 ether;
    uint constant public ANNOUNCEMENT_FEE = 0.05 ether;

   /***
   * This method provides a function for players to join the game.
   * @param seatNumber either 0 or 1, which is the seat users want to choose to join the game.
   * @return Nothing.
   */
    function join(uint8 seatNumber) public payable {
        require (gameState == State.waitPlayers,"Game is ongoing, please wait for next round.");
        require ( msg.value >= (JETTON + HAND_FEE),"If you want to join the game, the least jetton required is 1.1 ether.");
        require (numberOfCurrentPlayers <2,"There are already two players, please wait for next round.");
        require (!seats[seatNumber%2],"Sorry, this seat has been occupied." );
        require (!players[msg.sender].joined,"Please do not repeat to join!");
        seatNumber%=2;

        players[msg.sender].playerAddress = msg.sender;
        players[msg.sender].playerBalance += msg.value - HAND_FEE;
        contractBalance += HAND_FEE;
        players[msg.sender].joined = true;
        players[msg.sender].used = true;
        players[msg.sender].seatNo = seatNumber;
        playersAddr[seatNumber] = msg.sender;
        seats[seatNumber] = true;
        numberOfCurrentPlayers++;

        if(numberOfCurrentPlayers==2){
            gameState = State.makeDecision;
        }
    }
  /***
  * This method provides a function for players to refill their money.
  * @return Nothing.
  */
    function refill() public payable {
        require(players[msg.sender].used,
        "You do not have access to refill money in the current accounts.");
        players[msg.sender].playerBalance += (msg.value-HAND_FEE);
        contractBalance += HAND_FEE;
    }

  /***
  * This method provides a function for players to send their commitment.
  * @param commitment, must be a 32-bytes hexadecimal inputs which is cuculated by nonce+0/1,
  * an example is "0x87c2d362de99f75a4f2755cdaaad2d11bf6cc65dc71356593c445535ff28f43d".
  * Please keep the original nonce and number committed for hash value.
  * You would be requested to provide this value to proof your commitment at next stage.
  * @return Nothing.
  */
    function sendCommitment(bytes32 commitment) public {
        require(gameState == State.makeDecision,"You are not allowed to send your commitment other than the second stage.");
        require(players[msg.sender].joined,"You do not have access to send commitment in the current game.");
        require(!players[msg.sender].isCommitted,"You have sent your commitment, please do not send it twice and wait for other player.");

        players[msg.sender].commitment = commitment;
        players[msg.sender].isCommitted = true;
        numberOfCommitments++;

        if(numberOfCommitments ==2 ){
            gameState = State.verification;
        }
    }
  /***
  * This method is used to verify the committed value from players.
  * Any player who could not provides a corresponding value which could be used to get an exactly same hash as they sent at last stage,
  * would be punished with a fine, and they would lose the game.
  * Besides, especially for playerA, if he sent a hash culculated from nounce+ number other than 0 or 1, would also be regarded
  * as cheating behavior.
  * @param origin, a string that used to generate hash value at last stage,
  * an example:"9f74e042264bedfd27e031467271541dbb991696d1428527b6d9a0e5cc793f58big1".
  * @return Nothing.
  */
    function verify(string calldata origin) public {
        require(gameState == State.verification, "The game is not in the verification stage now.");
        require(players[msg.sender].joined,"You do not have access to send the committed value in the current game");
        bytes32  temp = keccak256(abi.encodePacked(origin));
        players[msg.sender].choice = getChoice(origin);

        if(temp == players[msg.sender].commitment){
            players[msg.sender].isVerified = true;
            numberOfVerified ++;
        }else{
            players[msg.sender].violations =true;
            numberOfViolations ++;
            cheatCondition[players[msg.sender].seatNo] = true;
        }

        if(players[msg.sender].choice != 0x31 && players[msg.sender].choice != 0x30){
            if(players[msg.sender].isVerified){
                players[msg.sender].isVerified = false;
                numberOfVerified --;
            }
            if(!players[msg.sender].violations){
                players[msg.sender].violations = true;
                numberOfViolations ++;
            }
            cheatCondition[players[msg.sender].seatNo] = true;
        }

         // must resist the cheating of A, e.g. A use 3 as its last number?
        if((numberOfViolations + numberOfVerified) == 2){
            gameState = State.announcement;
        }
    }
  /***
  * This method is used to export the result of game in this round.
  * @return result, a string that indicates the winner, and whether there is a cheater or both sides cheated in this round.
  */
    function announcement() public returns(string memory result) {
        require(gameState == State.announcement,
        "The game of this round has not arrived its final stage.");
        gameState = State.roundover;
        players[msg.sender].playerBalance += ANNOUNCEMENT_FEE;
        contractBalance -= ANNOUNCEMENT_FEE;
        detection();
        if(cheatState== ViolationState.noCheat){
          return checkWin();
        }else if (cheatState== ViolationState.aCheat){
            Bwin();
            contractBalance +=  players[playersAddr[0]].playerBalance;
            players[playersAddr[0]].playerBalance = 0;
            return "B wins the game because PlayerA cheated in this round, and has been fined with all his/her money in contract.";
        }else if (cheatState== ViolationState.bCheat){
            Awin();
            contractBalance +=  players[playersAddr[1]].playerBalance;
            players[playersAddr[1]].playerBalance = 0;
            return "A wins the game because PlayerB cheated in this round, and has been fined with all his/her money in contract.";
        }else if(cheatState == ViolationState.bothCheat){
            Nowinner();
            return "Both two sides choose to cheat in this round, all their money are fined.";
        }
    }
  /***
  * This method is used to get the number from the original string players sent.
  * @param fullToken, a string that users used to generate hash.
  * @return a bytes1 sized value would be returned to represent the number players chose.
  */
    function getChoice(string calldata fullToken) public pure returns(bytes1){

        bytes memory b= bytes(fullToken);
        bytes1 b1 = b[b.length-1];
        return b1;
    }

  /***
  * This method provide users a function to join the next round of game.
  * @return Nothing.
  */
    function nextRound() public {
        require(gameState == State.roundover||gameState == State.waitPlayers,
        "The game has not arrived its final stage now, if you want to continute a next round, please wait till then");
        require(msg.sender == playersAddr[0]||msg.sender == playersAddr[1],
        "You are not in the game, please wait for space.");

        require(players[msg.sender].playerBalance >= JETTON,
        "Your jetton is not enough, please refill it or you can choose to quit the game.");

        players[msg.sender].joined = true;
        numberOfCurrentPlayers++;

        gameState = State.waitPlayers;
        if(numberOfCurrentPlayers == 2){
            gameState = State.makeDecision;
        }
    }
  /***
  * This method allows players to withdraw their money from contract at either waitPlayers stage or roundover stage.
  * Money would be sent to the account of msg.sender.
  * And at the meantime, withdrawing money means quit from the game.
  * @return Nothing.
  */
    function withdraw() public {
        require(gameState == State.roundover|| gameState == State.waitPlayers,
        "You can only withdraw your money during the roundover stage or waitPlayers stage");
        require(msg.sender == playersAddr[0]||msg.sender == playersAddr[1],
        "You do not have access to withdraw money from the accounts.");
        require(players[msg.sender].playerBalance >0,"You do not have any balance!");
        uint256 amount = players[msg.sender].playerBalance;
        players[msg.sender].playerBalance = 0;
        uint8 _seatNumber = players[msg.sender].seatNo;
        delete playersAddr[_seatNumber];
        delete players[msg.sender];
        seats[_seatNumber] = false;

        payable(msg.sender).transfer(amount);
    }
  /***
  * An internal function used for detecting that whether some players cheat in the game
  * @return Nothing.
  */
    function detection() internal {

        if(cheatCondition[0] && !cheatCondition[1]){
            cheatState = ViolationState.aCheat;
        }else if (cheatCondition[1] && !cheatCondition[0]){
            cheatState = ViolationState.bCheat;
        }else if (!cheatCondition[0] && !cheatCondition[1]){
            cheatState = ViolationState.noCheat;
        }else if (cheatCondition[0] && cheatCondition[1]){
            cheatState = ViolationState.bothCheat;
        }
    }
  /***
  * An internal function used to check the winner
  * @return a string indicating the identity of the winner in this round.
  */
    function checkWin() internal returns (string memory){
        if(players[playersAddr[0]].choice == players[playersAddr[1]].choice){
            return Bwin();
        }else{
            return Awin();
        }
    }
  /***
  * An internal function used if playerB win the game.
  * @return a string indicating the identity of the winner in this round.
  */
    function Bwin() internal returns (string memory) {
        players[playersAddr[0]].playerBalance -= JETTON;
        players[playersAddr[1]].playerBalance += JETTON;
        dataReset();
        return "Player_B wins the game!";
    }
  /***
  * An internal function used if playerA win the game.
  * @return a string indicating the identity of the winner in this round.
  */
    function Awin() internal returns (string memory) {
        players[playersAddr[1]].playerBalance -= JETTON;
        players[playersAddr[0]].playerBalance += JETTON;
        dataReset();
        return "Player_A wins the game!";
    }
  /***
  * An internal function used if both the two sides cheated in this round.
  * @return a string indicating that no one win the game, they both be fined.
  */
    function Nowinner() internal returns (string memory){
        contractBalance += players[playersAddr[0]].playerBalance;
        contractBalance += players[playersAddr[1]].playerBalance;

        players[playersAddr[0]].playerBalance = 0;
        players[playersAddr[1]].playerBalance = 0;

        dataReset();
        return "No one wins the game!";
    }
  /***
  * An internal function used to reset the status of players and game at the end of each round.
  * @return Nothing.
  */
    function dataReset()internal{

        players[playersAddr[0]].commitment = "0x00";
        players[playersAddr[0]].choice = 0x00;
        players[playersAddr[0]].isVerified = false;
        players[playersAddr[0]].isCommitted =false;
        players[playersAddr[0]].joined =false;
        players[playersAddr[0]].violations = false;

        players[playersAddr[1]].commitment = "0x00";
        players[playersAddr[1]].choice = 0x00;
        players[playersAddr[1]].isVerified = false;
        players[playersAddr[1]].isCommitted =false;
        players[playersAddr[1]].joined =false;
        players[playersAddr[1]].violations = false;

        numberOfCurrentPlayers=0;
        numberOfCommitments = 0;
        numberOfVerified = 0;
        numberOfViolations =0;

        cheatCondition[0] = false;
        cheatState = ViolationState.noCheat;
    }
}
