pragma solidity ^0.5.1;

import "./StrategyInterface.sol";
import "./LinearDecrease.sol";
import "./MyArtSale.sol";
import "./PercDecrease.sol";

contract Dutch is StrategyInterface, ERC721, ERC721TokenReceiver{
    
    using SafeMath for uint256;

    address payable creator;
    
    uint reservePrice;
    uint startPrice;
    
    uint blockDuration;
    uint startBlock;
    uint endBlock;
    
    uint actPrice;
    
    uint soldPrice;
    address soldUser;
    
    uint tokenId;
    //instance of contract for the decrease of the price
    PercDecrease pDec;
    LinearDecrease lDec;
    //utilityToken ut;
    
    MyArtSale mas = MyArtSale(0xF76C52ea2a85D2d38020ceA80C918e8f7499C491);

    uint decreaseMethod; //0 for linearDecrease 1 for PercDecrease
    
    modifier onlyCreator(){
        require(msg.sender == creator);
        _;
    }
    
    modifier onlyExistentMethod(uint _methodName){
        require(_methodName >= 0 && _methodName <= 1);
        _;
    }
    
    modifier inTime(){
        require(block.number <= endBlock);
        _;
    }
    
    modifier isUpdatable(){
        require(startBlock == 0);
        _;
    }
    
    modifier onSale(){
        require(soldPrice == 0);
        _;
    }
    
    modifier tokenArrived(){
        require(balanceOf(address(this)) > 0);
        _;
    }
    
    modifier auctionClosed(){
        //TODO asta finita oppure token venduto
        require(block.number > endBlock || soldPrice > 0);
        _;
    }
    
    event bidAccepted(address user, uint price, uint block);
    event bidSent(address user, uint price, uint block);
    event dutchCreated(address contractAddress, uint block);
    event auctionStart(uint block);
    event auctionClose(uint block, address soldUser, uint soldPrice);
    event methodUpdate(uint block, uint prevMethod, uint actualMethod);
    
    constructor(uint _resPrice, uint _sPrice, uint _duration, uint _decreaseMethod, uint _tokenId) public{
        require(_resPrice > uint(0));
        require(_sPrice > uint(0));
        require(_duration > uint(0));
        reservePrice = _resPrice;
        startPrice  = _sPrice;
        blockDuration = _duration;
        creator = msg.sender;
        tokenId = _tokenId;
        //startBlock = block.number;
        //endBlock = block.number + (_duration -1);
        pDec = new PercDecrease();
        lDec = new LinearDecrease();
        //ut = new utilityToken();
        //mas = MyArtSale(0xf763CcD48BCe953E21CA15c934691000fFfcfc89);
        decreaseMethod = _decreaseMethod;
        emit dutchCreated(address(this), block.number);
    }
    
    function startAuction() tokenArrived public{
        startBlock = block.number;
        endBlock = block.number.add((blockDuration.sub(1)));
        emit auctionStart(block.number);
    }
    
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
    }
    
    function updateContractDecreasseMethod(uint _methodName) isUpdatable onlyCreator onlyExistentMethod(_methodName) public{
        //Aggiorna il metodo di decremento, possibile solo con quelli aggiunti nella map
        emit methodUpdate(block.number, decreaseMethod, _methodName);
        decreaseMethod = _methodName;
    }
    
    function getWinnerAddress() public view returns(address){
        return soldUser;
    }
    
    function getWinnerAmount() public view returns(uint){
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
        transferTo(creator, soldPrice);
        safeTransferFrom(address(this), soldUser, tokenId);
        emit auctionClose(block.number, soldUser, soldPrice);
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
    
    //TODO AGGIORNARE
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