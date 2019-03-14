var HDWalletProvider = require("truffle-hdwallet-provider");
var mnemonic = "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat";
module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*",
      gas: 4500000,
      gasPrice: 10000000000
    }
  },
  solc: {
    optimizer: {
      enabled: true
    }
  },
  mocha: {
    bail: true
  }
};