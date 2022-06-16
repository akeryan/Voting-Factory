// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract VotingFactory is Ownable {

    struct Candidate {
		string	name; // candidate name
		address	addr; // wallet address
        uint numVotes; // number of votes received
	}

    struct Voting {
        uint index; // index of voting ID in _votingIDs
        uint winnerID; // ID of the winner
        uint numCandidates; // total number of candidates
        mapping(uint => Candidate) candidates; //candidateID => Candidate
        mapping (address => uint) isCandidate; //candidateAddr => candidateID
        address[] voters; // list of all the voters
		mapping (address => uint) isVoter; // voterAddr => candidateID             
        uint startDate;
        uint payableBalance; // funds payable to the winner  
        bool isFinalized;        	            			    
    }

    uint private _votingCounter; // to get subsequent voting ID;
    uint[] private _votingIDs; // list of voting campaign ID's
    mapping(uint => Voting) public _votings; // votingID => Voting

    uint private _totalReceivedFunds; // total funds received from all campaigns
    uint private _releasedCommission; // total commission retrieved by the owner    


    modifier votingExists(uint votingID) {
        require(_votings[votingID].startDate > 0, "Voting doesn't exist");
        _;
    }

    // use only after modifier "votingExists"
    modifier candidateExists(uint votingID, uint candidateID) {
        require(
			candidateID > 0 && candidateID <= _votings[votingID].numCandidates,
            "Wrong candidateID"
        );
        _;
    }

	//constructor () { }

    function newVoting(
        string[] calldata names, 
        address[] calldata addresses, 
        uint startDate_
    ) 
        external
        onlyOwner 
        returns (uint votingID) 
    {
        require(names.length > 1, "Must be > 1 candidates");
        require(names.length == addresses.length, 
            "names and addresses array's length mismatch"
        );
        require(startDate_ > block.timestamp, "Wrong startDate");
		require(startDate_ < block.timestamp + 15778463,
			"Cannot schedule beyond 6 months period");

        votingID = _votingCounter++;
        Voting storage v = _votings[votingID];
        v.index = _votingIDs.length;
        _votingIDs.push() = votingID;

        v.startDate = startDate_;
        
        for(uint i = 0; i < names.length; i++)
            _addCandidate(v, names[i], addresses[i]);
    }

	function deleteVoting(uint votingID) 
        external 
        onlyOwner
        votingExists(votingID) 
    {
		require(_votings[votingID].winnerID != 0, 
			"Can delete only after the voting is closed"
		);
        Voting storage v = _votings[votingID];

        for(uint i; i < v.voters.length; i++) {
            delete v.isVoter[v.voters[i]];
        }

        for(uint i = 1; i <= v.numCandidates; i++) {
            delete v.isCandidate[v.candidates[i].addr];
            delete v.candidates[i];            
        }

        uint index_ = _votings[votingID].index;

        if(index_ != _votingIDs.length - 1) {
            _votingIDs[index_] = _votingIDs[_votingIDs.length - 1];
            _votings[_votingIDs[index_]].index = index_;
        }

        _votingIDs.pop();
        delete _votings[votingID];
    }

    function vote(uint votingID, uint candidateID) 
        external 
        payable 
        votingExists(votingID) 
        candidateExists(votingID, candidateID)        
    {
        require(block.timestamp >= _votings[votingID].startDate, 
            "Voting not started"
        );
        require(block.timestamp <= _votings[votingID].startDate + 3 days,
            "Voting ended"
        );
        Voting storage v = _votings[votingID];
        require(v.isCandidate[msg.sender] == 0, "Candidates cannot vote");
        require(v.isVoter[msg.sender] == 0, "You've already voted");        
        require(msg.value == 1 * 10**16, "Must be 0.01 ETH");
        

        _totalReceivedFunds = _totalReceivedFunds + msg.value;
        v.payableBalance = v.payableBalance + (9 * 10**15);
        v.isVoter[msg.sender] = candidateID;
        v.voters.push(msg.sender);
        v.candidates[candidateID].numVotes++;
    }

    function closeVoting(uint votingID) 
        external
        votingExists(votingID) 
    {
        Voting storage v = _votings[votingID];
        require(v.isFinalized == false, "Already finalized");
        require(block.timestamp > _votings[votingID].startDate + 3 days,
            "Only after voting end date"
        );

		if(v.voters.length != 0) {
			v.winnerID = _winner(votingID);
			payable(v.candidates[v.winnerID].addr).transfer(v.payableBalance);
		} 
        v.isFinalized = true;       
    }

    function withdrawCommission() external onlyOwner {
        uint balance = _commissionBalance();
        require(balance > 0, "No available balance");
        _releasedCommission = _releasedCommission + balance;
        payable(owner()).transfer(balance);        
    } 

    function totalFundsRecieved() 
        external 
        view 
        onlyOwner
        returns (uint) 
    {
        return _totalReceivedFunds;
    }

    function totalCommissionReleased()
        external 
        view 
        onlyOwner
        returns (uint) 
    {
        return _releasedCommission;
    }

    function isCandidate(uint votingId, address addr) 
        external 
        view 
        votingExists(votingId)
        returns (uint) 
    {
        return _votings[votingId].isCandidate[addr];
    }

    function hasVoted(uint votingID, address addr) 
        external 
        view 
        votingExists(votingID)
        returns (bool out) 
    {
        if(_votings[votingID].isVoter[addr] > 0)
            out = true;
    }

    function numVotes(uint votingID, uint candidateID) 
        external 
        view
        votingExists(votingID) 
        candidateExists(votingID, candidateID)
        returns (uint) 
    {
        return _votings[votingID].candidates[candidateID].numVotes;
    }

    function startDate(uint votingID) 
    external 
    view
    votingExists(votingID) 
    returns (uint) 
    {
        return _votings[votingID].startDate;
    }

    function endDate(uint votingID) 
    external 
    view 
    votingExists(votingID) 
    returns (uint) 
    {
        return _votings[votingID].startDate + 3 days;
    }  

    function commissionBalance() external view onlyOwner returns(uint) {
        return _commissionBalance();
    }

    function numCandidates(uint votingID) 
        external 
        view 
        votingExists(votingID) 
        returns (uint) 
    {
        return _votings[votingID].numCandidates;
    }

    function numVoters(uint votingID) 
    external 
    view 
    votingExists(votingID) 
    returns (uint) 
    {
        return _votings[votingID].voters.length;
    } 

    function candidate(uint votingID, uint candidateID) 
        external 
        view 
        votingExists(votingID)
        candidateExists(votingID, candidateID)
        returns (string memory, address, uint) 
    {
        return (
            _votings[votingID].candidates[candidateID].name,
            _votings[votingID].candidates[candidateID].addr,
			_votings[votingID].candidates[candidateID].numVotes
        );
    }

	function winnerInfo(uint votingID) 
        external 
        view 
        votingExists(votingID) 
        returns (Candidate memory) 
    {
        Voting storage v = _votings[votingID];
        require(v.isFinalized == true, "Must be finalized first");
        require(v.winnerID > 0, "Not identified yet");
		
        return v.candidates[v.winnerID];
    }

    function rewardAmount(uint votingID) external view returns (uint) {
        return _votings[votingID].payableBalance;
    }

    function _addCandidate(Voting storage v, string memory name_, address addr_) 
		private 
	{
        require(addr_ != address(0), "Addr is zerro address");
        require(addr_.code.length == 0, "Addr is contract");
        require(v.isCandidate[addr_] == 0, 
            "Address already in use"
        );
        require(bytes(name_).length > 0, "Invalid name"); 

        uint n = ++v.numCandidates; // candidate id's start from 1

        v.candidates[n].name = name_;
        v.candidates[n].addr = addr_;
        v.isCandidate[addr_] = n;
    }

    function _commissionBalance() private view returns (uint) {
        uint payableFunds;

        for(uint i; i < _votingIDs.length; i++) {
            payableFunds = payableFunds + _votings[i].payableBalance;
        }

        return (_totalReceivedFunds - payableFunds - _releasedCommission);
    }

    function _winner(uint votingID) 
        private
        view
        returns (uint) 
    {
        Voting storage v = _votings[votingID];

        uint[] memory tempWinners = new uint[](v.numCandidates);
        uint winningCount = v.candidates[1].numVotes;
        uint numWinners = 1;  

        for(uint i = 2; i <= v.numCandidates; i++)
            if(v.candidates[i].numVotes > winningCount) {
                winningCount = v.candidates[i].numVotes;
                tempWinners[0] = i;
            }               

        for(uint i = tempWinners[0] + 1; i <= v.numCandidates; i++)
            if(v.candidates[i].numVotes == winningCount)
                tempWinners[numWinners++] = i;

        if(numWinners > 1)
            return tempWinners[_randNumber(numWinners)];
        else
            return tempWinners[0];
    }

    // returns a random number in range [0; maxValue)
    function _randNumber(uint maxValue) private view returns (uint) {
        return (
            uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp))) 
            % maxValue
        );
    }

    function contractBalance() external view returns (uint) {
        return address(this).balance;
    }
}