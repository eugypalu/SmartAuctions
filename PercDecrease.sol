pragma solidity ^0.5.1;

import "./StrategyInterface.sol";

contract PercDecrease is StrategyInterface{
    
   //----------------------------------percDecrease--------------------------
    //calcolo in percentuale uanto è passato tra 2 blocchi e riduco il prezzo di quella percentuale
    
    function actualPrice(uint _reservePrice, uint _startPrice, uint _blockDuration, uint _startBlock, uint _endBlock) public returns(uint){
        uint pass = passedBlock(_startBlock);
        uint perc = percBlock(pass, _blockDuration);
        uint res = _startPrice - (_startPrice * perc / 100);
        return res;
    }
    
    function passedBlock(uint _startBlock) private returns(uint){
        return block.number - _startBlock;
    }
    
    function percBlock(uint _pass, uint _blockDuration) private returns(uint){
        uint perc = _pass * 100 / _blockDuration;
        return perc;
    }
    
    //-------------------------------------------------------------------------
    
}