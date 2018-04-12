pragma solidity ^0.4.21;

contract Token { function transfer(address, uint) public payable { } }

/*
 * ICO Contract
 *
 * Collects ether from participants when started
 * Can be started and stopped by timer, also can be started by previous ico oversale (Same contract)
 * Can be stopped by oversale and trigger next ico
 * Can be paused by Coordinators
 * Can return money if min cap is not reached
 * Sends tokens instantly after receiving incoming payment
 *
 * Designed to transfer collected funds to Distributor account (custom Multisignature wallet also can be used)
 * 
 * Lifecycle: deploy, add participants, set params, lock, take participance until end by time or hardcap, check results
 */


contract Ico {
	Token public tokenReward;
		   
	uint public minCap;
	uint public hardCap;
	
	uint public amountRaised;
	uint public tokenPrice;
	
	uint public startTime; 
	uint public endTime;
	uint public minPurchase; 
	uint public tokenCount; 
	uint public tokenSold;	 	
	bool public isLocked;
	bool public isPaused;
	
	address public owner;
	
	// Holds balances of participants
	mapping (address => uint) public participants;

	uint public participantsCount;
		
	bool public hardCapReached;
	bool public minCapReached;
	bool public finished;
	
	event HardCapReached();
	event MinCapReached();
	event OwnerChanged(address newOwner);
	event Paused();
	event Resumed();
	event Lock();
	event Participance(address participant, uint value, uint tokens);	
	event SoldOut();	
	
	modifier Unlocked() { 
		require(!isLocked); 
		_;
	}
	modifier Locked() { 
		require(isLocked); 
		_;
	}
	modifier Pause() { 
		require(isPaused);
		_;
	}
	modifier Unpause() { 
		require(!isPaused);
		_;
	}
	modifier Open() { 
		require(isOpen());
		_;
	}
	modifier Closed() { 
		require(!isOpen());
		_;
	}
	modifier onlyOwner() {
		require(msg.sender == owner);
		_;
	}

	function isOpen() private view returns(bool){ 
		return (block.timestamp >= startTime) 
				&& (block.timestamp <=endTime)
				&& !finished; 
	}	
		
	// Primary constructor. Ico params mostly passed by setParams()
	function Ico(address _tokenReward) public {
		owner=msg.sender;					
		tokenReward = Token(_tokenReward);					
	}
	
	// Specifies ICO params
	function setParams(
		uint _tokenPrice,
		uint _minCap,
		uint _hardCap,		
		uint _tokenCount,
		uint _startTime,
		uint _endTime,
		uint _minPurchase		
	) public Unlocked onlyOwner returns(bool){
		tokenPrice=_tokenPrice;	
		minCap=_minCap;
		hardCap=_hardCap;		
		tokenCount=_tokenCount;
		startTime=_startTime; 
		endTime=_endTime;
		minPurchase=_minPurchase;		
		return true; 		
	}
	
	function changeOwner(address newOwner) Unlocked onlyOwner public {
		require(newOwner != address(0));
		emit OwnerChanged(newOwner);
    	owner = newOwner;
	}
	
	// Locks. Before Lock you can change ICO params and Coordinaltor list, but can't take participance.
	// With lock ICO can go
	function lock() public Unlocked onlyOwner {
		isLocked=true;
		emit Lock();
	}	
	
	// Coordinator can pause or resume opened ICO. First they need to agree with pause or resume
	// When minimal count of coordinators are agree, any of them can call pause or resume
	// In pause mode participance is locked
	function pause() public Open Unpause onlyOwner {		
		isPaused=true;
		emit Paused();
	}
	
	function resume() public Pause Open onlyOwner {				
		isPaused=false;
		emit Resumed();
	}
	
	function estimateTokens(uint _amount) private view returns (uint) {
		return _amount / tokenPrice;
	}
	
	// To take participance wallets just send money to this contract when ICO is opened
	function () public payable Locked Unpause Open{
		if (participance (msg.sender, msg.value))
			owner.transfer(msg.value);
	}
	
	// If we go into oversale and there is linked next ico, contract passes the rest of money to it,
	// forcing it to start before its start time and sell some tokens to current participant
	// which initiated oversale there
	function participance (address sender, uint value) public returns(bool) {
		uint amount = value;

		require(value >= minPurchase);

		if (amount > hardCap - amountRaised) 	
			amount = hardCap - amountRaised;	
		
		if (participants[sender] == 0)
			participantsCount++;

		uint tokenQty = estimateTokens(amount);
		
		participants[sender] += tokenQty;

		amountRaised += amount;
	
		emit Participance(sender,amount,tokenQty);

		tokenSold += tokenQty;

		checkIfCapsReached();	

		return true;	
	}
	
	function finishRound() private{
		finished=true;
		emit SoldOut();
	}
	
	function checkIfCapsReached() private {
		if ((amountRaised >= hardCap) && !hardCapReached) {
			hardCapReached=true;
			emit HardCapReached();
			finishRound();
		}
		else if ((amountRaised>=minCap) && !minCapReached) {
			minCapReached = true;
			emit MinCapReached();
		}
	}

	// NB: Bad idea and bad implementation of mappings iterating.
	// TODO: Implement returning funds to participants with pull method
	// 		 Have to check if sender is participant, then send him funds

    // Returns money to participants
	// function cancelIco () private {
	// 	for (uint i=0;i<participantAccountCount;i++)
	// 		if (participantAccountSpent[participantAccountIndex[i]]>0){
	// 			participantAccountIndex[i].transfer(participantAccountSpent[participantAccountIndex[i]]);
	// 			participantAccountSpent[participantAccountIndex[i]]=0;
	// 		}
	// }
	
	// function transferTokens () private {
	// 	for (uint i=0;i<participantAccountCount;i++)
	// 		if (participantAccountTokens[participantAccountIndex[i]]>0){
	// 			tokenReward.transfer(participantAccountIndex[i], participantAccountTokens[participantAccountIndex[i]]);
	// 			participantAccountTokens[participantAccountIndex[i]]=0;
	// 		}
	// }
	
	function checkPeriod() private {
		if ((block.timestamp > endTime) && !finished ) {
			finished=true;
		}
	}
	
	// Anyone can call contract to check results when ICO is closed
	// value param is a value to pass to distributor. There's nothing wrong if anoyone will pass money
	function checkResults() Closed public {	
		checkPeriod();
	}	
}