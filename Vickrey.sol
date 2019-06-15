pragma solidity ^0.5.1;

import "./MyArtSale.sol";

contract Vickrey is ERC721, ERC721TokenReceiver {
    
    using SafeMath for uint256;
    MyArtSale mas = MyArtSale(0xF76C52ea2a85D2d38020ceA80C918e8f7499C491);
    
    struct phase{
        uint256 phase1Duration;
        uint256 phase2Duration;
        uint256 phase3Duration;
        uint256 phase1;
        uint256 phase2;
        uint256 phase3;
    }
    
    struct auctionPrice{
        uint256 depositBid;
        uint256 reservePrice;
    }
    
    address payable creator;
    address payable charityAddress;
    
    struct bestBid{
        uint256 firstBid;
        address payable firstAddress;
        uint256 secondBid;
        address payable secondAddress;
    }
    
    uint256 tokenId;
    
    bestBid bBid;
    phase ph;
    auctionPrice ap;
    
    //utilityToken ut;
    
    //address payable [] bidder;
    
    mapping (address => bytes32) userToBidCommitment;
    mapping (address => uint256) addressToBid;
    
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
        require(msg.value == ap.depositBid);
        _;
    }
    
    modifier onlyOnFirstPhase(){
        require(ph.phase1 >= block.number);
        _;
    }
    
    modifier onlyOnSecondPhase(){
        require(ph.phase2 >= block.number);
        _;
    }
    
    modifier onlyOnThirdPhase(){
        require(ph.phase3 >= block.number);
        _;
    }
    
    modifier openBid(uint256 _nonce, address _usr, uint256 _value){
        require(userToBidCommitment[_usr]== keccak256(abi.encodePacked(_nonce, _value)));
        _;
    }
    
    modifier notAlreadyRevealed(address _usr){
        require(addressToBid[_usr] == 0);
        _;
    }
    
    modifier tokenArrived(){
        require(balanceOf(address(this)) > 0);
        _;
    }
    
    modifier auctionClosed(){
        require(block.number > ph.phase3);
        _;
    }
    
    /**
     * Controlla che l'asta non sia già iniziata
     **/
    modifier notAlreadyStarted(){
        require(ph.phase1 == 0);
        _;
    }
    
    event bidAccepted(address user, uint256 price, uint256 block);
    event bidSent(address user, uint256 price, uint256 block);
    event dutchCreated(address contractAddress, uint256 block);
    event auctionStart(uint256 block);
    
    constructor(uint256 _phase1, uint256 _phase2, uint256 _phase3, uint256 _depositBid, uint256 _reservePrice, address payable _charityAddress, uint256 _tokenId) public{
        creator = msg.sender;
        ph.phase1Duration = _phase1;
        ph.phase2Duration = _phase2;
        ph.phase3Duration = _phase3;
        ap.depositBid = _depositBid;
        ap.reservePrice = _reservePrice;
        charityAddress = _charityAddress;        
        //ut = new utilityToken();
        tokenId = _tokenId;
    }
    
    function startAuction() tokenArrived notAlreadyStarted public{
        ph.phase1 = block.number.add(ph.phase1Duration);
        ph.phase2 = block.number.add(ph.phase1Duration).add(ph.phase2Duration);
        ph.phase3 = block.number.add(ph.phase1Duration).add(ph.phase2Duration).add(ph.phase3Duration);
        emit auctionStart(block.number);
    }
    
    //function bidCommitment(uint _nonce, uint _price) notAlreadyBid(msg.sender) onlyOnFirstPhase isDeposit payable external{
    function bidCommitment(bytes32 _commitment) notAlreadyBid(msg.sender) onlyOnFirstPhase isDeposit payable external{
        //userToBidCommitment[msg.sender] = keccak256(abi.encodePacked(_nonce, _price));
        userToBidCommitment[msg.sender] = _commitment;
        //addressToDepositBid[msg.sender] = msg.value;
    }
    
    function getCommitment() public view returns(bytes32){
        return userToBidCommitment[msg.sender];
    }
    
    function getHashCommitment(uint256 _nonce, uint256 _value) public returns(bytes32){
        return keccak256(abi.encodePacked(_nonce, _value));
    }
    
    function withdrawal() alreadyBid(msg.sender) onlyOnSecondPhase external{
        //TODO mandare la metà del bid iniziale
        //uint v = ap.depositBid.div(2);
        transferTo(msg.sender, ap.depositBid.div(2));
        //userToBidCommitment[msg.sender] = 0;
    }
    
    function revealBid(uint256 _nonce) onlyOnThirdPhase alreadyBid(msg.sender) openBid(_nonce, msg.sender, msg.value) notAlreadyRevealed(msg.sender) payable external{
        addressToBid[msg.sender] == msg.value;
        //bidder.push(msg.sender);
        if(msg.value > bBid.firstBid){
            //refound al 2° che diventa terzo
            //uint refound = bBid.secondBid.add(ap.depositBid);
            transferTo(bBid.secondAddress, bBid.secondBid.add(ap.depositBid));
            //il primo diventa secondo
            bBid.secondBid = bBid.firstBid;
            bBid.secondAddress = bBid.firstAddress;
            //quello che ho appena guardato diventa primo
            bBid.firstBid = msg.value;
            bBid.firstAddress = msg.sender;
        } else if(msg.value >= bBid.secondBid){
            //refound al 2° che diventa terzo
            //gli viene restituito bid + deposito iniziale
            //uint refound = bBid.secondBid.add(ap.depositBid);
            transferTo(bBid.secondAddress, bBid.secondBid.add(ap.depositBid));
            //quello che ho appena guardato diventa secondo
            bBid.secondBid = msg.value;
            bBid.secondAddress = msg.sender;
        }
    }
    
    function finalize() onlyCreator auctionClosed public{
        //se nessuna delle puntate fatte supera il prezzo di riserva faccio refound a tutti
        if(bBid.firstBid < ap.reservePrice){
            //refound primo
            transferTo(bBid.firstAddress, bBid.firstBid.add(ap.depositBid));
            //refound secondo
            transferTo(bBid.secondAddress, bBid.secondBid.add(ap.depositBid));
            //refound creator del token
            safeTransferFrom(address(this), creator, tokenId);
        }else{ 
            if(bBid.secondBid < ap.reservePrice)
                bBid.secondBid = ap.reservePrice;//Se la seconda offerta è minore del prezzo di riserva la setto a prezzo di riserva
                
            //mando al creator l'ammontare della seconda offerta più alta
            transferTo(creator, bBid.secondBid);
            
            //refound all'utente che si è aggiudicato l'asta il deposito iniziale + la sua offerta - la seconda offerta più alta dell'asta (quella pagata per la vincita)
            //uint refoundFirst = bBid.firstBid.add(ap.depositBid).sub(bBid.secondBid);
            transferTo(bBid.firstAddress, bBid.firstBid.add(ap.depositBid).sub(bBid.secondBid));
            //trasferisco al vincitore il token
            safeTransferFrom(address(this), bBid.firstAddress, tokenId);
                
            //refound del secondo utente
            //uint refoundSecond = bBid.secondBid.add(ap.depositBid);
            transferTo(bBid.secondAddress, bBid.secondBid.add(ap.depositBid));
            
            /*for(uint i = 0; i < bidder.length; i++){
                address payable usr = bidder[i];
                if(usr == bBid.firstAddress){
                    //TODO mando bBid.secondBid
                    transferTo(creator, bBid.secondBid);
                    //TODO manda ad address la sua bid+deposito - second bid
                    uint refound = bBid.firstBid.add(ap.depositBid).sub(bBid.secondBid);
                    transferTo(usr, refound);
                    transfer(address(this), bBid.firstAddress, tokenId);
                }else{
                    //TODO restituisci addressToBid[bid] + deposito
                    //forse da togliere
                    uint bid = addressToBid[usr];
                    uint refound = bid.add(ap.depositBid);
                    transferTo(usr, refound);
                }
            }*/
        }
        uint256 balance = address(this).balance;
        if(balance > 0){
            transferTo(charityAddress, balance);
        }
    }
    
    function getPhase() public view returns(uint256){
        if(ph.phase1 == 0){
            return 0;
        }else{
            if(block.number < ph.phase1)
                return 1;
            else if(block.number < ph.phase2)
                return 2;
            else if(block.number < ph.phase3)
                return 3;
            else 
                return 4;
        }
    }
    
    function closeContract() onlyCreator public{
        selfdestruct(address(0));
    }
    
    function transferTo(address payable _to, uint256 _val) private{
        _to.transfer(_val);
    }
    
    
    function stringToBytes(string memory _s) private pure returns (bytes32){
        bytes32 result;
        assembly {
            result := mload(add(_s, 32))
        }
        return result;
    }
    
    function safeTransferFrom(address _from,address _to,uint256 _tokenId,bytes memory _data) public{
        mas.safeTransferFrom(_from, _to, _tokenId, _data);
    }
    
    function safeTransferFrom(address _from,address _to,uint256 _tokenId)public{
        mas.safeTransferFrom(_from, _to, _tokenId);
    }
    
    function transferFrom(address _from,address _to,uint256 _tokenId)public{
        mas.transferFrom(_from, _to, _tokenId);
    }
    
    function approve(address _approved,uint256 _tokenId)public{
        mas.approve(_approved, _tokenId);
    }
    
    function setApprovalForAll(address _operator,bool _approved)public{
        mas.setApprovalForAll(_operator, _approved);
    }
    
    function balanceOf(address _owner)public view returns (uint256){
        return mas.balanceOf(_owner);
    }
    
    function ownerOf(uint256 _tokenId)public view returns (address){
        return mas.ownerOf(_tokenId);
    }
    
    function getApproved(uint256 _tokenId)public view returns (address){
        return mas.getApproved(_tokenId);
    }
    
    function isApprovedForAll(address _owner,address _operator)public view returns (bool){
        mas.isApprovedForAll(_owner, _operator);
    }
    
    function tokenURI() public view returns (string memory){
        //tokenId è hardcoded in quanto all'utente interessa conoscere solo le info relative al token di questa asta
        return mas.tokenURI(tokenId);
    }
  
    function tokenDescription() public view returns (string memory){
        //tokenId è hardcoded in quanto all'utente interessa conoscere solo le info relative al token di questa asta
        return mas.tokenDescription(tokenId);
    }
    
    function onERC721Received(
    address, 
    address, 
    uint256, 
    bytes calldata
    )external returns(bytes4) {
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }
}
