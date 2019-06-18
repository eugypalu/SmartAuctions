pragma solidity ^0.5.6;

import "./P2pToken.sol";

contract Vickrey is ERC721, ERC721TokenReceiver {
    
    using SafeMath for uint256;
    P2pToken mas = P2pToken(0xCFC03245Ca98b26455daB6F27c69DE6F10C1C3C4); //contratto che gestisce i token
    
    //durata delle fasi dello smart contract    
    struct phase{
        uint256 phase1Duration;
        uint256 phase2Duration;
        uint256 phase3Duration;
        uint256 phase1;
        uint256 phase2;
        uint256 phase3;
    }
    
    struct auctionPrice{
        uint256 depositBid;
        uint256 reservePrice;
    }
    
    address payable creator;
    address payable charityAddress;//address a cui vengono mandati ether in eccesso
    
    //migliori 2 offerte con relativi address
    struct bestBid{
        uint256 firstBid;
        address payable firstAddress;
        uint256 secondBid;
        address payable secondAddress;
    }
    
    uint256 tokenId;//id del token messo all'asta
    
    bestBid bBid;
    phase ph;
    auctionPrice ap;
    
    mapping (address => bytes32) userToBidCommitment;//mappa utenti con il loro hash
    mapping (address => uint256) addressToBid; //mappa utenti con la loro offerta
    
    /**
     * Controlla che l'operazione venga eseguita dal creator
     **/
    modifier onlyCreator(){
        require(msg.sender == creator);
        _;
    }
    
    /**
     * Controlla se un utente non ha ancora mandato la bidAccepte
     **/
    modifier notAlreadyBid(address _usr){
        require(userToBidCommitment[_usr] == 0);
        _;
    }
    
    /**
     * Controlla se un utente ha già mandato la bidAccepte
     **/
    modifier alreadyBid(address _usr){
        require(userToBidCommitment[_usr] != 0);
        _;
    }
    
    /**
     * Controlla che il deposito corrisponda al value impostato dall'utente
     **/
    modifier isDeposit(){
        require(msg.value == ap.depositBid);
        _;
    }
    
    /**
     * Controlla che l'operazione avvenga nella giusta fase
     **/
    modifier onlyOnFirstPhase(){
        require(ph.phase1 >= block.number);
        _;
    }
    
    /**
     * Controlla che l'operazione avvenga nella giusta fase
     **/
    modifier onlyOnSecondPhase(){
        require(ph.phase2 >= block.number && ph.phase1 < block.number);
        _;
    }
    
    /**
     * Controlla che l'operazione avvenga nella giusta fase
     **/
    modifier onlyOnThirdPhase(){
        require(ph.phase3 >= block.number && ph.phase2 < block.number);
        _;
    }
    
    /**
     * Controlla che nonce e value coincidano coon quelli dell'hash mandato precedentemente
     **/
    modifier openBid(uint256 _nonce, address _usr, uint256 _value){
        require(userToBidCommitment[_usr]== keccak256(abi.encodePacked(_nonce, _value)));
        _;
    }
    
    /**
     * Controlla che l'utente non abbia gia rivelato la sua offerta
     **/
    modifier notAlreadyRevealed(address _usr){
        require(addressToBid[_usr] == 0);
        _;
    }
    
    /**
     * Controlla che il token sia arrivato
     **/
    modifier tokenArrived(){
        require(balanceOf(address(this)) > 0);
        _;
    }
    
    /**
     * Controlla che l'asta non sia ancora iniziata
     **/
    modifier auctionClosed(){
        require(block.number > ph.phase3 && ph.phase1 > 0);
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
    modifier minDuration(uint _duration1, uint _duration2, uint _duration3){
        require(_duration1 > 0 && _duration2 > 0 && _duration3 > 0);
        _;
    }
    
    /**
     * Controlla che l'asta non sia già iniziata
     **/
    modifier notAlreadyStarted(){
        require(ph.phase1 == 0);
        _;
    }
    
    event bidAccepted(address user, uint256 price, uint256 block);
    event bidSent(address user, uint256 price, uint256 block);
    event vickreyCreated(address contractAddress, uint256 block);
    event auctionStart(uint256 block);
    event commitment(address user, uint block);
    event withd(address user, uint block);
    event bidRevealed(address user, uint block);
    
    constructor(uint256 _phase1, uint256 _phase2, uint256 _phase3, uint256 _depositBid, uint256 _reservePrice, address payable _charityAddress, uint256 _tokenId) minDuration(_phase1, _phase2, _phase3) minPrice(_reservePrice, _depositBid) public{
        creator = msg.sender;
        ph.phase1Duration = _phase1;
        ph.phase2Duration = _phase2;
        ph.phase3Duration = _phase3;
        ap.depositBid = _depositBid;
        ap.reservePrice = _reservePrice;
        charityAddress = _charityAddress;
        tokenId = _tokenId;
        emit vickreyCreated(msg.sender, block.number);
    }
    
    /**
     * Da inizio all’asta, quindi vengono impostati blocchi di inizio e fine di ogni fase.
     * Sono stati inseriti dei vincoli, infatti la funzione può essere invocata solo dal creator. 
     * Può essere invocata solo una volta, infatti viene controllato che il blocco di inizio non sia ancora settato. 
     * Infine l’asta non può partire finchè non viene inviato il token allo smart contract, questo vincolo è stato inserito per garantire lo scambio, 
     * infatti in questo modo il contratto avrà funzione di escrow, prenderà il token del venditore e riceverà il pagamento dall’offerente, nel momento in cui 
     * l’asta sarà conclusa effettuerà lo scambio.
     * inoltre l’utiliizzo del token permette all’utente che entrerà a far parte dell’asta come offerente di poter controllare cosa sta effettivamente comprando.
     **/
    function startAuction() onlyCreator tokenArrived notAlreadyStarted public{
        ph.phase1 = block.number.add(ph.phase1Duration);
        ph.phase2 = block.number.add(ph.phase1Duration).add(ph.phase2Duration);
        ph.phase3 = block.number.add(ph.phase1Duration).add(ph.phase2Duration).add(ph.phase3Duration);
        emit auctionStart(block.number);
    }
    
    /**
     * In questa fase gli utenti che partecipano all’asta devono inviare l’hash della propria offerta+nonce, 
     * pagando anche il deposito settato in precedenza dal creator.
     * L’hash non viene calcolato nello smart contract per evitare che vengano fatte transazioni con l’offerta “in chiaro”, 
     * altrimenti gli altri utenti saprebbero quali sono le offerte da superare.Viene controllato che l’utente non abbia già inviato un’offerta, 
     * che questa funzione venga chiamata solo nella sua fase e che il deposito che l’utente sta inviando coincida con quello impostato dall’utente.
     **/
    function bidCommitment(bytes32 _commitment) notAlreadyBid(msg.sender) onlyOnFirstPhase isDeposit payable external{
        userToBidCommitment[msg.sender] = _commitment;
        emit commitment(msg.sender, block.number);
    }
    
    /**
     * In questa fase l’utente può decidere di tirarsi indietro ed ottenere la metà del deposito versato inizialmente. 
     * Viene controllato che sia stato fatto il deposito precedentemente dall’utente e che questa funzione venga chiamata solo nella giusta fase.
     **/
    function withdrawal() alreadyBid(msg.sender) onlyOnSecondPhase external{
        transferTo(msg.sender, ap.depositBid.div(2));
        emit withd(msg.sender, block.number);
    }
    
    /**
     * In questa fase gli utenti rivelano la propria offerta. Viene chiamata questa funzione passando come parametro il nonce e pagando il value inserito 
     * nell’hash precedentemente. L’offerta viene accettata solo se l’hash del nonce + il value dell’offerta coincidono con l’hash mandato precedentemente. 
     * Viene inoltre controllato che l’offerta non sia già stata rivelata, in modo da non permettere di mandare più soldi del previsto al contratto, 
     * se l’utente ha mandato precedentemente l’hash e che la funzione venga chiamata solo nella giusta fase.Gli utenti che con le loro offerte non rientrano 
     * nei primi 2 “classificati” vengono immediatamente rimborsati dell’amount dell’offerta e del deposito iniziale.
     **/
    function revealBid(uint256 _nonce) onlyOnThirdPhase alreadyBid(msg.sender) openBid(_nonce, msg.sender, msg.value) notAlreadyRevealed(msg.sender) payable external{
        addressToBid[msg.sender] == msg.value; //l'utente viene aggiunto al mapping così da evitare che possa mandare di nuovo altri soldi
        if(msg.value > bBid.firstBid){
            if(bBid.secondAddress != address(0)){
                transferTo(bBid.secondAddress, bBid.secondBid.add(ap.depositBid));
            }
            //il primo diventa secondo
            bBid.secondBid = bBid.firstBid;
            bBid.secondAddress = bBid.firstAddress;
            //quello attuale diventa primo
            bBid.firstBid = msg.value;
            bBid.firstAddress = msg.sender;
        } else if(msg.value >= bBid.secondBid){
            //refound al 2° che diventa terzo
            //gli viene restituito bid + deposito iniziale
            if(bBid.secondAddress != address(0)){
                transferTo(bBid.secondAddress, bBid.secondBid.add(ap.depositBid));
            }
            //quello attuale diventa secondo
            bBid.secondBid = msg.value;
            bBid.secondAddress = msg.sender;
        }
        emit bidRevealed(msg.sender, block.number);
    }
    
    /**
     * Permette di finalizzare l'asta e pagare/fare refound gli utenti
     **/
    function finalize() auctionClosed public{
        if(bBid.firstBid == 0 && bBid.secondBid == 0){//nessuno partecipa all'asta
            safeTransferFrom(address(this), creator, tokenId);   
        }else if(bBid.secondBid == 0){//partecipa solo una persona
            if(bBid.firstBid < ap.reservePrice){ //solo una persona ma non raggiunge il reserve price
                transferTo(bBid.firstAddress, bBid.firstBid.add(ap.depositBid));
                safeTransferFrom(address(this), creator, tokenId);
            }else{ //reserve price raggiunto
                transferTo(creator, ap.reservePrice);
                safeTransferFrom(address(this), bBid.firstAddress, tokenId);
                transferTo(bBid.firstAddress, bBid.firstBid.sub(ap.reservePrice).add(ap.depositBid));
            }
        }else{
            if(bBid.firstBid < ap.reservePrice){//più persone ma reserve price non raggiunto
                transferTo(bBid.firstAddress, bBid.firstBid.add(ap.depositBid));
                transferTo(bBid.secondAddress, bBid.secondBid.add(ap.depositBid));
                safeTransferFrom(address(this), creator, tokenId);
            }else if(bBid.secondBid < ap.reservePrice){ //solo il primo supera il reserve price
                transferTo(creator, ap.reservePrice);
                safeTransferFrom(address(this), bBid.firstAddress, tokenId);
                transferTo(bBid.secondAddress, bBid.secondBid.add(ap.depositBid));
                transferTo(bBid.firstAddress, bBid.firstBid.sub(ap.reservePrice).add(ap.depositBid));
            }else{
                transferTo(creator, bBid.secondBid);
                safeTransferFrom(address(this), bBid.firstAddress, tokenId);
                transferTo(bBid.secondAddress, bBid.secondBid.add(ap.depositBid));
                transferTo(bBid.firstAddress, bBid.firstBid.sub(bBid.secondBid).add(ap.depositBid));
            }
        }
        uint256 balance = address(this).balance;
        if(balance > 0){
            transferTo(charityAddress, balance);
        }
        closeContract();
    }
    
    function getPhase() public view returns(uint256){
        if(ph.phase1 == 0){
            return 0;
        }else{
            if(block.number <= ph.phase1)
                return 1;
            else if(block.number <= ph.phase2)
                return 2;
            else if(block.number <= ph.phase3)
                return 3;
            else 
                return 4;
        }
    }
    
    function closeContract() internal{
        selfdestruct(address(0));
    }
    
    function transferTo(address payable _to, uint256 _val) private{
        _to.transfer(_val);
    }
    
    
    function stringToBytes(string memory _s) private pure returns (bytes32){
        bytes32 result;
        assembly {
            result := mload(add(_s, 32))
        }
        return result;
    }
    
    function getFirstBid() public view returns(uint){
        return bBid.firstBid;
    }
    
    function getSecondBid() public view returns(uint){
        return bBid.secondBid;
    }
    
    function getDeposit() public view returns(uint){
        return ap.depositBid;
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
        //tokenId è hardcoded in quanto all'utente interessa conoscere solo le info relative al token di questa asta
        return mas.tokenURI(tokenId);
    }
  
    function tokenDescription() public view returns (string memory){
        //tokenId è hardcoded in quanto all'utente interessa conoscere solo le info relative al token di questa asta
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
