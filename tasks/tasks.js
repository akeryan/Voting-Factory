//---------------------TASKS------------------------------

//const { task } = require("hardhat/config");

task("newVoting", "Creates new Voting campaign")
	.addParam("address", "address of the VotingFactory contract")
	.addParam("names", "An array with candidates' names")
	.addParam("addresses", "An array with candidates' addresses")
	.addParam("date", "Starting date of the voting")
	.setAction(async (taskArgs) => {		
		const factory = await ethers.getContractAt("VotingFactory", taskArgs.address);
		let votingID = await factory.newVoting(taskArgs.names, taskArgs.addresses, taskArgs.date);
		console.log("voting ID: ", votingID.value);
});


task("deleteVoting", "Delete absolete voting to free up storage")
	.addParam("address", "address of the VotingFactory contract")
	.addParam("id", "voting ID")
	.setAction(async (taskArgs) => {		
		const factory = await ethers.getContractAt("VotingFactory", taskArgs.address);
		await factory.deleteVoting(taskArgs.id);
		console.log("voting with forllowing ID has been deleted: ", taskArgs.id);
});


task("vote", "Vote for a candidate")
	.addParam("address", "address of the VotingFactory contract")
	.addParam("vid", "voting ID")
	.addParam("cid", "candidate ID")
	.setAction(async (taskArgs) => {		
		const factory = await ethers.getContractAt("VotingFactory", taskArgs.address);
		await factory.vote(taskArgs.vid, taskArgs.cid);
});


task("close", "Close voting")
	.addParam("address", "address of the VotingFactory contract")
	.addParam("vid", "voting ID")
	.setAction(async (taskArgs) => {		
		const factory = await ethers.getContractAt("VotingFactory", taskArgs.address);
		await factory.closeVoting(taskArgs.vid);
});


task("withdraw", "Withdraw commission")
	.addParam("address", "address of the VotingFactory contract")
	.setAction(async (taskArgs) => {		
		const factory = await ethers.getContractAt("VotingFactory", taskArgs.address);
		await factory.withdrawCommission();
});
