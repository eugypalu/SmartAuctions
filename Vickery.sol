pragma solidity ^0.5.1;

contract Vickery {
    
    uint phase1Duration;
    uint phase2Duration;
    uint phase3Duration;
    uint depositBid;
    
    modifier notAlreadyBid(address _usr){
        require(userToBidCommitment[_usr] == 0);
        _;
    }
    
    modifier onlyOnFirstPhase(){
        require(phase1Duration >= block.number);
        _;
    }
    
    modifier onlyOnSecondPhase(){
        require(phase2Duration >= block.number);
        _;
    }
    
    modifier onlyOnThirdPhase(){
        require(phase3Duration >= block.number);
        _;
    }
    
    mapping (address => bytes32) userToBidCommitment;
    
    constructor(uint _phase1, uint _phase2, uint _phase3, uint _depositBid) public{
        phase1Duration = _phase1;
        phase2Duration = _phase2;
        phase3Duration = _phase3;
        depositBid = _depositBid;
    }
    
    
    function bidCommitment(uint _nonce, uint _price) notAlreadyBid(msg.sender) onlyOnFirstPhase payable external{
        userToBidCommitment[msg.sender] = keccak256(abi.encodePacked(_nonce, _price));
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
