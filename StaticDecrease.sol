pragma solidity ^0.5.1;

import "./StrategyInterface.sol";

contract StaticDecrease is StrategyInterface{
    
    //----------------------------------StaticDecrease--------------------------
    //Il prezzo non decresce, rimane costante nel tempo
    function actualPrice(uint _reservePrice, uint _startPrice, uint _blockDuration, uint _startBlock, uint _endBlock) public returns(uint){
        return _startPrice;        
    }

    //-------------------------------------------------------------------------
    
}