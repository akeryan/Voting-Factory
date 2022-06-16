// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract VotingFactory {

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
        uint startDate; // specifies when campaign opens for voting
        uint payableBalance; // funds payable to the winner  
        bool isFinalized; // turns true when voting is closed       	            			    
    }

	address public owner;

    uint private _votingCounter; // to get subsequent voting ID;
    uint[] public votingIDs; // list of voting campaign ID's
    mapping(uint => Voting) public votings; // votingID => Voting

    uint private _totalReceivedFunds; // total funds received from all campaigns
    uint private _releasedCommission; // total commission retrieved by the owner    


    modifier onlyOwner {
		require(msg.sender == owner, "Not an owner");
		_;
	}
	
	modifier votingExists(uint votingID) {
        require(votings[votingID].startDate > 0, "Voting doesn't exist");
        _;
    }

    // use only after modifier "votingExists"
    modifier candidateExists(uint votingID, uint candidateID) {
        require(
			candidateID > 0 && candidateID <= votings[votingID].numCandidates,
            "Wrong candidateID"
        );
        _;
    }

	constructor () {
		owner = msg.sender; 
	}

    function newVoting(
        string[] calldata names, 
        address[] calldata addresses, 
        uint startDate_
    ) 
        external
        onlyOwner 
        returns (uint votingID_) 
    {
        require(names.length > 1, "Must be > 1 candidates");
        require(names.length == addresses.length, 
            "names and addresses array's length mismatch"
        );
        require(startDate_ > block.timestamp, "Wrong startDate");
		require(startDate_ < block.timestamp + 15778463,
			"Cannot schedule beyond 6 months period");

        votingID_ = _votingCounter++;
        Voting storage v = votings[votingID_];
        v.index = votingIDs.length;
        votingIDs.push() = votingID_;

        v.startDate = startDate_;
        
        for(uint i = 0; i < names.length; i++)
            _addCandidate(v, names[i], addresses[i]);
    }

	function deleteVoting(uint votingID) 
        external 
        onlyOwner
        votingExists(votingID) 
    {
		require(votings[votingID].isFinalized == true, 
			"Can delete only after the voting is closed"
		);
        Voting storage v = votings[votingID];

        for(uint i = 0; i < v.voters.length; i++) {
            delete v.isVoter[v.voters[i]];
        }

        for(uint i = 1; i <= v.numCandidates; i++) {
            delete v.isCandidate[v.candidates[i].addr];
            delete v.candidates[i];            
        }

        uint index_ = votings[votingID].index;

        if(index_ != votingIDs.length - 1) {
            votingIDs[index_] = votingIDs[votingIDs.length - 1];
            votings[votingIDs[index_]].index = index_;
        }

        votingIDs.pop();
        delete votings[votingID];
    }

    function vote(uint votingID, uint candidateID) 
        external 
        payable 
        votingExists(votingID) 
        candidateExists(votingID, candidateID)        
    {
        require(block.timestamp >= votings[votingID].startDate, 
            "Voting not started"
        );
        require(block.timestamp <= votings[votingID].startDate + 3 days,
            "Voting ended"
        );
        Voting storage v = votings[votingID];
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
		returns (uint)
    {
        Voting storage v = votings[votingID];
        require(v.isFinalized == false, "Already finalized");
        require(block.timestamp > votings[votingID].startDate + 3 days,
            "Only after voting end date"
        );

		if(v.voters.length != 0) {
			v.winnerID = _winner(votingID);
			payable(v.candidates[v.winnerID].addr).transfer(v.payableBalance);
		} 
        v.isFinalized = true;    
		return v.winnerID;   
    }

    function withdrawCommission() external onlyOwner {
        uint balance = _commissionBalance();
        require(balance > 0, "No available balance");
        _releasedCommission = _releasedCommission + balance;
        payable(owner).transfer(balance);        
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

    function numVotes(uint votingID, uint candidateID) 
        external 
        view
        votingExists(votingID) 
        candidateExists(votingID, candidateID)
        returns (uint) 
    {
        return votings[votingID].candidates[candidateID].numVotes;
    }

    function startDate(uint votingID) 
    public 
    view
    votingExists(votingID) 
    returns (uint) 
    {
        return votings[votingID].startDate;
    }

    function endDate(uint votingID) 
    external 
    view 
    votingExists(votingID) 
    returns (uint) 
    {
        return startDate(votingID) + 3 days;
    }  

    function commissionBalance() external view onlyOwner returns(uint) {
        return _commissionBalance();
    }

    function numVoters(uint votingID) 
    external 
    view 
    votingExists(votingID) 
    returns (uint) 
    {
        return votings[votingID].voters.length;
    } 

    function candidate(uint votingID, uint candidateID) 
        external 
        view 
        votingExists(votingID)
        candidateExists(votingID, candidateID)
        returns (string memory, address, uint) 
    {
        return (
            votings[votingID].candidates[candidateID].name,
            votings[votingID].candidates[candidateID].addr,
			votings[votingID].candidates[candidateID].numVotes
        );
    }

	function votingIndex(uint votingID) 
		public 
		view
		onlyOwner
		votingExists(votingID) 
		returns (uint) 
	{
		return votings[votingID].index;
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

        for(uint i; i < votingIDs.length; i++) {
            payableFunds = payableFunds + votings[i].payableBalance;
        }

        return (_totalReceivedFunds - payableFunds - _releasedCommission);
    }

    function _winner(uint votingID) 
        private
        view
        returns (uint) 
    {
        Voting storage v = votings[votingID];

        uint[] memory tempWinners = new uint[](v.numCandidates);
        uint winningCount = v.candidates[1].numVotes;
		tempWinners[0] = 1;
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
        
		return tempWinners[0];
    }

    // returns a random number in range [0; maxValue)
    function _randNumber(uint maxValue) private view returns (uint) {
        return (
            uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp))) 
            % maxValue
        );
    }
}
