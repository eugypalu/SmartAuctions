pragma solidity ^0.5.1;

import "./StrategyInterface.sol";
import "./LinearDecrease.sol";
import "./P2pToken.sol";
import "./PercDecrease.sol";
import "./StaticDecrease.sol";

contract Dutch is StrategyInterface, ERC721, ERC721TokenReceiver{
    
    using SafeMath for uint256;

    address payable creator;
    
    uint reservePrice; //Reserve price
    uint startPrice; //initial auction price
    
    uint blockDuration; //duration of the auction expressed in blocks
    uint startBlock; //starting block of the auction
    uint endBlock; //ending block of the auction
    
    uint actPrice; //actual price
    
    uint soldPrice; //user who won the auction
    address soldUser;
    
    uint tokenId; //tokenid of the auction
    
    //contract for the decrease of the price
    PercDecrease pDec;
    LinearDecrease lDec;
    StaticDecrease sDec;

    //contract that manages the token
    P2pToken mas = P2pToken(0xf8CA4fE2B0cA1Ef0537b5C1176c85B516a2446E4);

    uint decreaseMethod; //0 for linearDecrease 1 for PercDecrease 2 for staticdecrease
    
    /**
     * Controlla se la funzione viene chiamata dal creator
     **/ 
    modifier onlyCreator(){
        require(msg.sender == creator);
        _;
    }
    
    /**
     * Controlla se il metodo scelto è tra quelli esistenti
     **/
    modifier onlyExistentMethod(uint _methodName){
        require(_methodName >= 0 && _methodName <= 2);
        _;
    }
    
    /**
     * Controlla se la funzione viene chiamata nell'intervallo di tempo definito dall'utente
     **/
    modifier inTime(){
        require(block.number <= endBlock);
        _;
    }
    
    /**
     * Il creator può modificare il decreaseMethod solo se l'asta non è ancora iniziata 
     **/
    modifier isUpdatable(){
        require(startBlock == 0);
        _;
    }
    
    /**
     * Controlla che l'asta non sia terminata, quindi che il token non sia stato venduto
     **/
    modifier onSale(){
        require(soldPrice == 0);
        _;
    }
    
    /**
     * Controlla che il token sia stato ricevuto
     **/
    modifier tokenArrived(){
        require(balanceOf(address(this)) > 0);
        _;
    }
    
    /**
     * controlla che l'asta sia conclusa
     **/
    modifier auctionClosed(){
        require(block.number > endBlock || soldPrice > 0);
        _;
    }
    
    /**
     * controlla che i prezzi siano maggiori di 0
     **/
    modifier minPrice(uint _resPrice, uint _sPrice){
        require(_resPrice > 0 && _sPrice > 0);
        _;
    }
    
    /**
     * controlla che la durata espressa in blocchi sia magiore di 0
     **/
    modifier minDuration(uint _duration){
        require(_duration > 0);
        _;
    }
    
    /**
     * Controlla che l'asta non sia già iniziata
     **/
    modifier notAlreadyStarted(){
        require(startBlock == 0);
        _;
    }
    
    //Event
    event bidAccepted(address user, uint price, uint block); 
    event bidSent(address user, uint price, uint block); 
    event dutchCreated(address contractAddress, uint block); 
    event auctionStart(uint block);
    event auctionClose(uint block, address soldUser, uint soldPrice);
    event methodUpdate(uint block, uint prevMethod, uint actualMethod);
    
    constructor(uint _resPrice, uint _sPrice, uint _duration, uint _decreaseMethod, uint _tokenId) minPrice(_resPrice, _sPrice) minDuration(_duration) public{
        reservePrice = _resPrice;
        startPrice  = _sPrice;
        blockDuration = _duration;
        creator = msg.sender;
        tokenId = _tokenId;
        pDec = new PercDecrease(); //decrescita percentuale
        lDec = new LinearDecrease(); //decrescita LinearDecrease
        sDec = new StaticDecrease();
        decreaseMethod = _decreaseMethod; //viene settato il metodo con cui decrementa il prezzo
        emit dutchCreated(address(this), block.number); //contratto creato
    }
    
    /**
     * l'asta può effettivamente partire solo quando il token viene ricevuto
     **/
    function startAuction() onlyCreator tokenArrived notAlreadyStarted public{
        startBlock = block.number; //setta il blocco di inizio dell'asta
        endBlock = block.number.add((blockDuration.sub(1))); //blocco in cui l'asta termina ricavato sommando all'inizio la durata
        emit auctionStart(block.number);
    }
    
    /**
     * restituisce il blocco in cui l'asta inizia
     **/
    function getStart() public view returns(uint){
        return startBlock;
    }
    
    function getStop() public view returns(uint){
        return endBlock;
    }
    
    function getreservePrice() onlyCreator public view returns(uint){
        //questa non puà essere pubblica sennò la gente aspetterebbe il minimo
        return reservePrice;
    }
    
    function getStartPrice() public view returns(uint){
        return startPrice;
    }
    
    function getCreator() onlyCreator public view returns(address){
        return creator;
    }
    
    function getActualPrice() onlyCreator public view returns(uint){
        return actPrice;
    }
    
    //??? TODO NON VA BENE CHE QUESTO SIA PUBBLICO????
    function actualPrice(uint _reservePrice, uint _startPrice, uint _blockDuration, uint _startBlock, uint _endBlock) onlyCreator public returns(uint){
        //TODO Vorrei un qualcosa di dinamico, questo non mi piace
        //TODO non mi piace nemmeno che non posso aggiungere metodi di decrease in corsa
        if (decreaseMethod == 0)
            actPrice = lDec.actualPrice(_reservePrice, _startPrice, _blockDuration, _startBlock, _endBlock);
        else if (decreaseMethod == 1)
            actPrice = pDec.actualPrice(_reservePrice, _startPrice, _blockDuration, _startBlock, _endBlock);
        else if (decreaseMethod == 2)
            actPrice = sDec.actualPrice(_reservePrice, _startPrice, _blockDuration, _startBlock, _endBlock);
    }
    
    function updateContractDecreasseMethod(uint _methodName) isUpdatable onlyCreator onlyExistentMethod(_methodName) public{
        //Aggiorna il metodo di decremento, possibile solo con quelli aggiunti nella map
        emit methodUpdate(block.number, decreaseMethod, _methodName);
        decreaseMethod = _methodName;
    }
    
    function getWinnerAddress() onlyCreator public view returns(address){
        return soldUser;
    }
    
    function getWinnerAmount() onlyCreator public view returns(uint){
        return soldPrice;
    }
    
    /*
    Può essere implementata in 2 modi:
    -1) il prezzo variabile è visibile a tutti e quindi basta fare un bid al prezzo attuale
    -2) è visibile solo il prezzo iniziale, a questo punto viene fatta la bid con il prezzo che si è disposti
    a pagare, se è superiore o uguale a quello attuale l'offerta è buona, altrimenti no
    */
    function bid() inTime onSale public payable{
        actualPrice(reservePrice, startPrice, blockDuration, startBlock, endBlock);
        emit bidSent(msg.sender, msg.value, block.number);
        require(actPrice <= msg.value && msg.value > 0);
        soldUser = msg.sender;
        soldPrice = msg.value;
        emit bidAccepted(msg.sender, msg.value, block.number);
    }
    
    function payOut() auctionClosed public{
        if(soldPrice == 0){
            safeTransferFrom(address(this), creator, tokenId);
        }else{
            transferTo(creator, soldPrice);
            safeTransferFrom(address(this), soldUser, tokenId);
            emit auctionClose(block.number, soldUser, soldPrice);
        }
    }
    
    function transferTo(address payable _to, uint _val) private{
        _to.transfer(_val);
    }
    
    function stringToBytes(string memory _s) private pure returns (bytes32){
        bytes32 result;
        assembly {
            result := mload(add(_s, 32))
        }
        return result;
    }
    
    //TODO AGGIORNARE auctionClosed non va bene
    //function closeContract() auctionClosed public{
    function closeContract() public{
        selfdestruct(address(0));
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
        //tokenId è hardcoded in quanto all'utente interessa conoscere solo le info relative al token in questa asta
        return mas.tokenURI(tokenId);
    }
  
    function tokenDescription() public view returns (string memory){
        //tokenId è hardcoded in quanto all'utente interessa conoscere solo le info relative al token in questa asta
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