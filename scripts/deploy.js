const { ethers } = require("hardhat");
//require("dotenv").config({ path: ".env" });

async function main() {

	const [deployer] = await ethers.getSigners();

	console.log("Deploying contracts with the account:", deployer.address);

	console.log("Account balance in ethers:", (
		ethers.utils.formatEther(await deployer.getBalance())));

  	const VotingFactory = await ethers.getContractFactory("VotingFactory"); // Getting the Contract
  	const votingFactory = await VotingFactory.deploy(); //deploying the contract

  	await votingFactory.deployed(); // waiting for the contract to be deployed

  	console.log("VotingFactory deployed to:", votingFactory.address); 
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
}); // Calling the function to deploy the contract 
