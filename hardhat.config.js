require("@nomiclabs/hardhat-waffle");
require('solidity-coverage')
require("dotenv").config();
require("./tasks/tasks.js");

/**
 * @type import('hardhat/config').HardhatUserConfig
 */

privateKey = process.env.ACCOUNT;
rinkebyNetwork = process.env.RINKEBY_NETWORK;


module.exports = { 
	defaultNetwork: "hardhat",
	networks: {
		hardhat: {
		},
		rinkeby: {
			url: rinkebyNetwork,
			accounts: [ privateKey ]
		}
	},
	solidity: {
		version: "0.8.4",
	},
	paths: {
		root: './',
		sources: './contracts',
		tests: './tests',
		cashe: './cache',
		artifacts: './artifacts',
		tasks: './tasks'
	},
	mocha: {
		timeout: 40000 
	}
};
