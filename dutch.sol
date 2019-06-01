pragma solidity ^0.5.1;

import "./StrategyInterface.sol";

contract Ducth is StrategyInterface{
    
    address creator;
    uint reservePrice;
    uint startPrice;
    uint blockDuration;
    uint startBlock;
    uint endBlock;
    uint actPrice;
    
    bytes32 decreaseMethodName;
    
    mapping (bytes32 => address) decreaseMethod;
    
    modifier onlyCreator(){
        require(msg.sender == creator);
        _;
    }
    
    modifier inTime(){
        require(block.number <= endBlock);
        _;
    }
    
    constructor(uint _resPrice, uint _sPrice, uint _duration, string memory _decreaseMethodName) public{
        require(_resPrice > uint(0));
        require(_sPrice > uint(0));
        require(_duration > uint(0));
        reservePrice = _resPrice;
        startPrice  = _sPrice;
        blockDuration = _duration;
        creator = msg.sender;
        startBlock = block.number;
        endBlock = block.number + (_duration -1);
        
        bytes32 methodName = stringToBytes(_decreaseMethodName);
        decreaseMethodName = methodName;
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

    
    function bid() inTime public payable{
        //TODO vedere come rendere pagabile
        //TODO fare in modo che chi fa la bid sposti prma soldi su escrow e triangolare le cose
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