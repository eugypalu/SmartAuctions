pragma solidity ^0.5.1;

contract StrategyInterface {
    function actualPrice(uint _reservePrice, uint _startPrice, uint _blockDuration, uint _startBlock, uint _endBlock) public returns(uint);
}