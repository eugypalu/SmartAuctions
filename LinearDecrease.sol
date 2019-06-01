pragma solidity ^0.5.1;

import "./StrategyInterface.sol";

contract LinearDecrease is StrategyInterface{
    
    //----------------------------------linearDecrease--------------------------
    //decresce dal prezzo di partenza fino al prezzo di riserva ad intervalli regolari fino all'ultimo blocco in cui l'offerta è ancora valida
    function actualPrice(uint _reservePrice, uint _startPrice, uint _blockDuration, uint _startBlock, uint _endBlock) public returns(uint){
        uint pDecrease = priceDecrease(_startPrice, _reservePrice);
        uint pastBlock = block.number - _startBlock;
        uint linDecr = linearDecrease(pDecrease, _blockDuration);
        uint actPrice = _startPrice - (pastBlock * linDecr);
        return actPrice;
        
    }
    
    function priceDecrease(uint _startPrice, uint _reservePrice) private returns(uint){
        return _startPrice - _reservePrice;
    }
    
    function linearDecrease(uint _pDecrease, uint _blockDuration) private returns(uint) {
        return _pDecrease/_blockDuration;
    }
    //-------------------------------------------------------------------------
    
}