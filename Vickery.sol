pragma solidity ^0.5.1;

contract Vickery {
    
    address payable creator;
    
    uint phase1Duration;
    uint phase2Duration;
    uint phase3Duration;
    
    uint depositBid;
    uint reservePrice;
    
    address payable charityAddress;
    
    struct bestBid{
        uint firstBid;
        address firstAddress;
        uint secondBid;
        //address secondAddress;
    }
    
    bestBid bBid;
    
    address payable [] bidder;
    
    mapping (address => bytes32) userToBidCommitment;
    //mapping (address => uint) addressToDepositBid; //potrebbe non servire
    mapping (address => uint) addressToBid;
    
    modifier onlyCreator(){
        require(msg.sender == creator);
        _;
    }
    
    modifier notAlreadyBid(address _usr){
        require(userToBidCommitment[_usr] == 0);
        _;
    }
    
    modifier alreadyBid(address _usr){
        require(userToBidCommitment[_usr] != 0);
        _;
    }
    
    modifier isDeposit(){
        require(msg.value == depositBid);
        _;
    }
    
    modifier onlyOnFirstPhase(){
        require(phase1Duration >= block.number);
        _;
    }
    
    modifier onlyOnSecondPhase(){
        require(phase2Duration >= block.number);
        _;
    }
    
    modifier onlyOnThirdPhase(){
        require(phase3Duration >= block.number);
        _;
    }
    
    modifier openBid(uint _nonce, address _usr, uint _value){
        require(userToBidCommitment[_usr]== keccak256(abi.encodePacked(_nonce, _value)));
        _;
    }
    
    modifier notAlreadyRevealed(address _usr){
        require(addressToBid[_usr] == 0);
        _;
    }
    
    modifier auctionClosed(){
        require(block.number > phase3Duration);
        _;
    }
    
    constructor(uint _phase1, uint _phase2, uint _phase3, uint _depositBid, uint _reservePrice, address payable _charityAddress) public{
        creator = msg.sender;
        phase1Duration = block.number + _phase1;
        phase2Duration = block.number + _phase1 + _phase2;
        phase3Duration = block.number + _phase1 + _phase2 + _phase3;
        depositBid = _depositBid;
        reservePrice = _reservePrice;
        charityAddress = _charityAddress;
    }
    
    
    function bidCommitment(uint _nonce, uint _price) notAlreadyBid(msg.sender) onlyOnFirstPhase isDeposit payable external{
        userToBidCommitment[msg.sender] = keccak256(abi.encodePacked(_nonce, _price));
        //addressToDepositBid[msg.sender] = msg.value;
    }
    
    function withdrawal() alreadyBid(msg.sender) onlyOnSecondPhase external{
        //TODO mandare la metà del bid iniziale
        uint v = depositBid/2;
        transferTo(msg.sender, v);
        //userToBidCommitment[msg.sender] = 0;
    }
    
    function revealBid(uint _nonce) onlyOnThirdPhase alreadyBid(msg.sender) openBid(_nonce, msg.sender, msg.value) notAlreadyRevealed(msg.sender) payable external{
        addressToBid[msg.sender] == msg.value;
        bidder.push(msg.sender);
        if(msg.value > bBid.firstBid){
            bBid.firstBid = msg.value;
            bBid.firstAddress = msg.sender;
        } else if(msg.value > bBid.secondBid){
            bBid.secondBid = msg.value;
            //bBid.secondAddress = msg.sender;
        }
    }
    
    function finalize() onlyCreator auctionClosed public{
        for(uint i = 0; i < bidder.length; i++){
            address payable usr = bidder[i];
            if(usr == bBid.firstAddress){
                //TODO mando bBid.secondBid
                transferTo(creator, bBid.secondBid);
                //TODO manda ad address la sua bid+deposito - second bid
                uint refound = bBid.firstBid + depositBid - bBid.secondBid;
                transferTo(usr, refound);
            }
            else{
                //TODO restituisci addressToBid[bid] + deposito
                uint bid = addressToBid[usr];
                uint refound = bid + depositBid;
                transferTo(usr, refound);
            }
        }
        uint balance = address(this).balance;
        if(balance > 0){
            transferTo(charityAddress, balance);
        }
    }
    
    function transferTo(address payable _to, uint _val) private{
        _to.transfer(_val);
    }
    
    function closeContract() onlyCreator public{
        selfdestruct(address(0));
    }
    
    function stringToBytes(string memory _s) private pure returns (bytes32){
        bytes32 result;
        assembly {
            result := mload(add(_s, 32))
        }
        return result;
    }
}
