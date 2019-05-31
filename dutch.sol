pragma solidity ^0.5.1;

//solgraph
contract Ducth {
    
    address creator;
    uint reservePrice;
    uint startPrice;
    uint blockDuration;
    uint startBlock;
    uint endBlock;
    uint actPrice;
    
    modifier onlyCreator(){
        require(msg.sender == creator);
        _;
    }
    
    modifier inTime(){
        require(block.number <= endBlock);
        _;
    }
    
    constructor(uint _resPrice, uint _sPrice, uint _duration) public{
        require(_resPrice > uint(0));
        require(_sPrice > uint(0));
        require(_duration > uint(0));
        reservePrice = _resPrice;
        startPrice  = _sPrice;
        blockDuration = _duration;
        creator = msg.sender;
        startBlock = block.number;
        endBlock = block.number + (_duration -1);
        //TODO aggiungere opzione di decremento
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
    
    function getActualPrice() public view returns(uint){
        return actPrice;
    }
    
    //----------------------------------linearDecrease--------------------------
    //decresce dal prezzo di partenza fino al prezzo di riserva ad intervalli regolari fino all'ultimo blocco in cui l'offerta è ancora valida
    
    
    function priceDecrease() private returns(uint){
        return startPrice - reservePrice;
    }
    
    function linearDecrease() private returns(uint) {
        uint pDecrease = priceDecrease();
        return pDecrease/blockDuration;
    }
    
    function actualPriceLin() public returns(uint){
        uint pastBlock = block.number - startBlock;
        uint linDecr = linearDecrease();
        actPrice = startPrice - (pastBlock * linDecr);
        return actPrice;
        
    }
    //-------------------------------------------------------------------------
    
    //----------------------------------percDecrease--------------------------
    //calcolo in percentuale uanto è passato tra 2 blocchi e riduco il prezzo di quella percentuale
    
    function passedBlock() public returns(uint){
        return startBlock - block.number;
    }
    
    function percBlock() public returns(uint){
        uint pass = passedBlock();
        uint perc = pass * 100 / blockDuration;
        return 100 - perc;
    }
    
    function actualPricePerc() public returns(uint){
        uint perc = percBlock();
        return startPrice * perc / 100;
    }
    
    //-------------------------------------------------------------------------
    
    function bid() inTime public payable{
        //TODO vedere come rendere pagabile
        //TODO fare in modo che chi fa la bid sposti prma soldi su escrow e triangolare le cose
    }
    
    function closeContract() public{
        selfdestruct(address(0));
    }
    
}