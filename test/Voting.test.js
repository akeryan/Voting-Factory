const { expect } = require("chai");
const { ethers } = require("hardhat");
// const { Contract, providers } = require("ethers");
// const provider = waffle.provider;

describe("Voting contract", function () {
	let Voting;
	let voting;
	let owner;
	let addr1;
	let addr2;
	let addr3;
	let addr4;
	let addr5;
	let addrs;
	let names;
	let addresses;
	let startDate;
	let timeCorrection = 0;

	// Helper functions ------------------------------------------------ {

	async function setupCandidates() {
		names = ["name1", "name2", "name3"];
		addresses = [addr1.address, addr2.address, addr3.address];
		startDate = Math.round(new Date().getTime() / 1000) + 604800; // + 1 week		
	}	
	
	// } helper functions--------------------------------------------------
	

	beforeEach(async function () {
		await ethers.provider.send("evm_increaseTime", [-timeCorrection]);		
		[owner, addr1, addr2, addr3, addr4, addr5, ...addrs] = await ethers.getSigners();
		Voting = await ethers.getContractFactory("VotingFactory", owner);
		voting = await Voting.deploy();
		await voting.deployed();
		timeCorrection = 0;
	});


	//=================================================================================


	describe ("Deployment", function () {
		it("Should set the right owner for Voting", async function () {
			expect(await voting.owner()).to.equal(owner.address);
		});
	});

	describe ("Adding New Voting", function () {		
		it ("Only owner can add Voting", async function() {
			await setupCandidates();
			await expect (voting.connect(addr4).newVoting(names, addresses, startDate)
				).to.be.revertedWith("Not an owner");
		});

		it ("Names and Addresses arrays must be of the same length", async function() {
			names = ["name1", "name2"];
			addresses = [addr1.address];
			startDate = Math.round(new Date().getTime() / 1000) + 100;
			await expect (voting.newVoting(names, addresses, startDate)
				).to.be.revertedWith("names and addresses array's length mismatch");
		});

		it ("Must be at least 2 candidates", async function() {
			names = ["name1"];
			addresses = [addr1.address];
			startDate = Math.round(new Date().getTime() / 1000) + 100;
			await expect (voting.newVoting(names, addresses, startDate)
				).to.be.revertedWith("Must be > 1 candidates");
		});

		it ("Start date must be greater than 'present'", async function() {
			names = ["name1", "name2"];
			addresses = [addr1.address, addr2.address];
			startDate = 10;
			await expect (voting.newVoting(names, addresses, startDate)
				).to.be.revertedWith("Wrong startDate");
		});	
		
		it ("Protection against zerro addresses", async function() {
			names = ["name1", "name2"];
			addresses = ["0x0000000000000000000000000000000000000000", addr2.address];
			startDate = Math.round(new Date().getTime() / 1000) + 100;
			await expect (voting.newVoting(names, addresses, startDate)
				).to.be.revertedWith("Addr is zerro address");
		});	

		it ("Address cannot be a contract address", async function() {
			names = ["name1", "name2"];
			addresses = [voting.address, addr2.address];
			startDate = Math.round(new Date().getTime() / 1000) + 100;
			await expect (voting.newVoting(names, addresses, startDate)
				).to.be.revertedWith("Addr is contract");
		});	

		it ("Two candidates with same address is not possible", async function() {
			names = ["name1", "name2"];
			addresses = [addr1.address, addr1.address];
			startDate = Math.round(new Date().getTime() / 1000) + 100;
			await expect (voting.newVoting(names, addresses, startDate)
				).to.be.revertedWith("Address already in use");
		});	

		it ("'Empty' name is not possible'", async function() {
			names = ["", "name2"];
			addresses = [addr1.address, addr2.address];
			startDate = Math.round(new Date().getTime() / 1000) + 100;
			await expect (voting.newVoting(names, addresses, startDate)
				).to.be.revertedWith("Invalid name");
		});	

		it("Retrieve information about candidate", async function(){
			await setupCandidates();
			let votingID = await voting.newVoting(names, addresses, startDate);
			const {0: name, 1: address, 2: numVotes} =  await voting.candidate(votingID.value, 1);
			expect(name).to.equal("name1");		
		})
	});

	describe ("Deleting Voting", function () {
		it ("Only owner can delete Voting", async function() {
			await setupCandidates();
			let votingID = await voting.newVoting(names, addresses, startDate);
			await expect (voting.connect(addr4).deleteVoting(votingID.value)
				).to.be.revertedWith("Not an owner");
		});	

		it ("Check whether Voting exist", async function() {
			await setupCandidates();
			let votingID = await voting.newVoting(names, addresses, startDate);
			await expect (voting.deleteVoting(5)
				).to.be.revertedWith("Voting doesn't exist");
		});	

		it ("Voting can be deleted only after it is closed", async function() {
			await setupCandidates();
			let votingID = await voting.newVoting(names, addresses, startDate);
			timeCorrection = 604800 + 100;
			await ethers.provider.send("evm_increaseTime", [timeCorrection]);
			voting.vote(votingID.value, 1);
			await expect (voting.deleteVoting(votingID.value)
				).to.be.revertedWith("Can delete only after the voting is closed");
		});	

		it ("Voting deleting takes place", async function(){
			await setupCandidates();
			let votingID = await voting.newVoting(names, addresses, startDate);
			timeCorrection = 604800 + 100;
			await ethers.provider.send("evm_increaseTime", [timeCorrection]);
			await voting.vote(votingID.value, 1, {value: ethers.utils.parseEther("0.01")});
			await ethers.provider.send("evm_increaseTime", [-timeCorrection]);
			timeCorrection = 604800 + 259200 + 100;
			await ethers.provider.send("evm_increaseTime", [timeCorrection]);
			await voting.closeVoting(votingID.value);
			await voting.deleteVoting(votingID.value);
			await expect (voting.deleteVoting(votingID.value)
				).to.be.revertedWith("Voting doesn't exist");
		})

		it ("Repositioning of the remaining votings is correct", async function() {
			await setupCandidates();
			let votingID1 = await voting.newVoting(names, addresses, startDate);			
			let votingID2 = await voting.newVoting(names, addresses, startDate);			
			timeCorrection = 604800 + 259200 + 100;
			await ethers.provider.send("evm_increaseTime", [timeCorrection]);
			await voting.closeVoting(votingID1.value);
			await voting.deleteVoting(votingID1.value);	
			expect (await voting.votingIndex(1)).to.be.equal(0);
		});

	});

	describe ("Voting act", function () {
		it ("Check whether Voting exist", async function() {
			await setupCandidates();
			let votingID = await voting.newVoting(names, addresses, startDate);
			await expect (voting.vote(5, 0)
				).to.be.revertedWith("Voting doesn't exist");
		});

		it ("Check whether Candidate exist", async function() {
			await setupCandidates();
			let votingID = await voting.newVoting(names, addresses, startDate);
			await expect (voting.vote(votingID.value, 5)
				).to.be.revertedWith("Wrong candidateID");
		});

		it ("Early voting not possible", async function() {
			await setupCandidates();
			let votingID = await voting.newVoting(names, addresses, startDate);
			await expect (voting.vote(votingID.value, 1)
				).to.be.revertedWith("Voting not started");
		});

		it ("Late voting not possible", async function() {
			await setupCandidates();
			let votingID = await voting.newVoting(names, addresses, startDate);
			timeCorrection = 604800 + 300000;
			await ethers.provider.send("evm_increaseTime", [timeCorrection]);
			await expect (voting.vote(votingID.value, 1)
				).to.be.revertedWith("Voting ended");
		});

		it ("Candidates are not allowed to vote", async function() {
			await setupCandidates();
			let votingID = await voting.newVoting(names, addresses, startDate);
			timeCorrection = 604800 + 100;
			await ethers.provider.send("evm_increaseTime", [timeCorrection]);
			await expect (voting.connect(addr1).vote(votingID.value, 1)
				).to.be.revertedWith("Candidates cannot vote");
		});

		it ("0.01 eth is required to vote", async function() {
			await setupCandidates();
			let votingID = await voting.newVoting(names, addresses, startDate);
			timeCorrection = 604800 + 100;
			await ethers.provider.send("evm_increaseTime", [timeCorrection]);
			await expect (voting.vote(votingID.value, 1, {value: ethers.utils.parseEther("0.001")})
				).to.be.revertedWith("Must be 0.01 ETH");
		});

		it ("Double voting is not possible", async function() {
			await setupCandidates();
			let votingID = await voting.newVoting(names, addresses, startDate);
			timeCorrection = 604800 + 100; // 1 week + little bit
			await ethers.provider.send("evm_increaseTime", [timeCorrection]);
			await voting.vote(votingID.value, 1, {value: ethers.utils.parseEther("0.01")});
			await expect (voting.vote(votingID.value, 2)
				).to.be.revertedWith("You've already voted");
		});
	});

	describe ("Closing a Voting", function () {
		it ("Check whether Voting exist", async function() {
			await setupCandidates();
			let votingID = await voting.newVoting(names, addresses, startDate);
			await expect (voting.closeVoting(5)
				).to.be.revertedWith("Voting doesn't exist");
		});

		it ("Can be closed only after the end date", async function() {
			await setupCandidates();
			let votingID = await voting.newVoting(names, addresses, startDate);
			await expect (voting.closeVoting(votingID.value)
				).to.be.revertedWith("Only after voting end date");
		});

		it ("Double closing is not possible", async function() {
			await setupCandidates();
			let votingID = await voting.newVoting(names, addresses, startDate);
			timeCorrection = 604800 + 100;
			await ethers.provider.send("evm_increaseTime", [timeCorrection]);
			await voting.vote(votingID.value, 1, {value: ethers.utils.parseEther("0.01")});
			await ethers.provider.send("evm_increaseTime", [-timeCorrection]);
			timeCorrection += 259200;
			await ethers.provider.send("evm_increaseTime", [timeCorrection]);
			await voting.closeVoting(votingID.value);
			await expect (voting.closeVoting(votingID.value)
				).to.be.revertedWith('Already finalized');
		});	
		
		it ("More than 1 winner (with same number of wotes)", async function(){
			await setupCandidates();
			let votingID = await voting.newVoting(names, addresses, startDate);
			timeCorrection = 604800 + 100;
			await ethers.provider.send("evm_increaseTime", [timeCorrection]);
			await voting.vote(votingID.value, 1, {value: ethers.utils.parseEther("0.01")});
			await voting.connect(addr4).vote(votingID.value, 2, {value: ethers.utils.parseEther("0.01")});
			await ethers.provider.send("evm_increaseTime", [-timeCorrection]);
			timeCorrection += 259200;
			await ethers.provider.send("evm_increaseTime", [timeCorrection]);
			await ethers.provider.send("evm_mine");
			let res = await voting.callStatic.closeVoting(votingID.value);
			if(res == 1 || res == 2)
				return true;
			else
				return false;				
		});

		it ("Correct winner is picked", async function() {
			await setupCandidates();
			let votingID = await voting.newVoting(names, addresses, startDate);
			timeCorrection = 604800 + 100;
			await ethers.provider.send("evm_increaseTime", [timeCorrection]);
			await voting.vote(votingID.value, 1, {value: ethers.utils.parseEther("0.01")});
			await voting.connect(addr4).vote(votingID.value, 2, {value: ethers.utils.parseEther("0.01")});
			await voting.connect(addr5).vote(votingID.value, 2, {value: ethers.utils.parseEther("0.01")});
			await ethers.provider.send("evm_increaseTime", [-timeCorrection]);
			timeCorrection = 604800 + 100 + 259200;
			await ethers.provider.send("evm_increaseTime", [timeCorrection]);
			await ethers.provider.send("evm_mine");
			let id = await voting.callStatic.closeVoting(votingID.value);
			expect(id).to.equal(2);				
		})
	});

	describe ("Withdrawing Commission", function () {
		it ("Only owner can withdraw commission", async function() {
			await setupCandidates();
			await expect (voting.connect(addr1).withdrawCommission()
				).to.be.revertedWith("Not an owner");
		});

		it ("Balance must be positive", async function() {
			await setupCandidates();
			startDate = Math.round(new Date().getTime() / 1000) + 604800;
			let votingID = await voting.newVoting(names, addresses, startDate);
			timeCorrection = 604800 + 100;
			await ethers.provider.send("evm_increaseTime", [timeCorrection]);
			await voting.vote(votingID.value, 1, {value: ethers.utils.parseEther("0.01")});
			await voting.withdrawCommission();
			await expect (voting.connect(owner).withdrawCommission()
				).to.be.revertedWith("No available balance");
		});
	});

	describe ("Testing view functions", function () {
		it ("Check that view functions work properly", async function() {
			await setupCandidates();
			let votingID = await voting.newVoting(names, addresses, startDate);
			timeCorrection = 604800 + 100;
			await ethers.provider.send("evm_increaseTime", [timeCorrection]);
			await voting.vote(votingID.value, 1, {value: ethers.utils.parseEther("0.01")});
			expect(await voting.numVotes(votingID.value, 1)).to.equal(1);
			expect(await voting.startDate(votingID.value)).to.gt(0);
			expect(await voting.endDate(votingID.value)).to.gt(0);
			expect(await voting.numVoters(votingID.value)).to.equal(1);
			expect(await voting.commissionBalance()).to.equal(ethers.utils.parseEther('0.001'));
			expect(await voting.totalFundsRecieved()).to.equal(ethers.utils.parseEther('0.01'));

			await voting.withdrawCommission();
			expect(await voting.totalCommissionReleased()).to.equal(ethers.utils.parseEther('0.001'));

		})	
	});
});
