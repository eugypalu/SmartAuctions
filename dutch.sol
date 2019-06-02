pragma solidity ^0.5.1;

import "./StrategyInterface.sol";
import "./LinearDecrease.sol";
import "./PercDecrease.sol";

contract Ducth is StrategyInterface{
    
    //TODO Decidere dove aggiungere gli event, sicuramente su bid
    
    address creator;
    
    uint reservePrice;
    uint startPrice;
    uint blockDuration;
    uint startBlock;
    uint endBlock;
    uint actPrice;
    
    uint soldPrice;
    address soldUser;
    
    //instance of contract for the decrease of the price
    PercDecrease pDec;
    LinearDecrease lDec;

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
    
    modifier onSale(){
        require(soldPrice == 0);
        _;
    }
    
    constructor(uint _resPrice, uint _sPrice, uint _duration, uint _decreaseMethod) public{
        require(_resPrice > uint(0));
        require(_sPrice > uint(0));
        require(_duration > uint(0));
        reservePrice = _resPrice;
        startPrice  = _sPrice;
        blockDuration = _duration;
        creator = msg.sender;
        startBlock = block.number;
        endBlock = block.number + (_duration -1);
        pDec = new PercDecrease();
        lDec = new LinearDecrease();
        decreaseMethod = _decreaseMethod;
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
    function actualPrice(uint _reservePrice, uint _startPrice, uint _blockDuration, uint _startBlock, uint _endBlock) public returns(uint){
        //TODO Vorrei un qualcosa di dinamico, questo non mi piace
        //TODO non mi piace nemmeno che non posso aggiungere metodi di decrease in corsa
        if (decreaseMethod == 0)
            actPrice = lDec.actualPrice(_reservePrice, _startPrice, _blockDuration, _startBlock, _endBlock);
        else if (decreaseMethod == 1)
            actPrice = pDec.actualPrice(_reservePrice, _startPrice, _blockDuration, _startBlock, _endBlock);
    }
    
    function updateContractDecreasseMethod(uint _methodName) onlyCreator onlyExistentMethod(_methodName) public{
        //TODO Aggiorna il metodo di decremento, possibile solo con quelli aggiunti nella map
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
        require(actPrice <= msg.value && msg.value > 0);
        soldUser = msg.sender;
        soldPrice = msg.value;
    }
    
    function closeContract() public{
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

/*
    function addDecreaseMethod(string memory _methodName, address _methodAddress) onlyCreator public {
        bytes32 methodName = stringToBytes(_methodName);
        decreaseMethod[methodName] = _methodAddress;
    }
    
    function getMethodAddress(string memory _methodName) onlyCreator public view returns(address){
        bytes32 methodName = stringToBytes(_methodName);
        return decreaseMethod[methodName];
    }

    function updateContractDecreasseMethod(string memory _methodName) onlyCreator public{
        //TODO Aggiorna il metodo di decremento, possibile solo con quelli aggiunti nella map
    }
*/    