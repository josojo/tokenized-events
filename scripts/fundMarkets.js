
/**
 * node scritps/approveTokenForDutchX.js
 * to add a new TradingPair ETH:Token to the DutchExchange
 * @flags:
 * --network                    if not specified, testrpc will be used. Otherwise rinkeby
 */

const Web3 = require('web3')
fs = require('fs')
const argv = require('minimist')(process.argv.slice(2), { string: 'a', string: ['network']})

const privKey = '0x133be114715e5fe528a1b8adf36792160601a2d63ab59d1fd454275b31328791' //process.env.PrivateKEY // raw private key
const HDWalletProvider = require('truffle-hdwallet-provider-privkey')

let web3, provider
if (argv.network) {
  if (argv.network == 'rinkeby') { provider = new HDWalletProvider(privKey, 'https://rinkeby.infura.io/') } else if (argv.network == 'kovan') {
    provider = new HDWalletProvider(privKey, 'https://kovan.infura.io/')
  } else if (argv.network == 'mainnet') {
    provider = new HDWalletProvider(privKey, 'https://mainnet.infura.io/')
  }
  web3 = new Web3(provider.engine)
} else {
  web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'))
}

const TruffleContract = require('truffle-contract')

// retrieve truffle-contracts
const StandardMarketJSON = JSON.parse(fs.readFileSync('./build/contracts/StandardMarket.json'))
const StandardMarket =  TruffleContract(StandardMarketJSON)
const ForkonomicSystemJSON = JSON.parse(fs.readFileSync('./build/contracts/ForkonomicSystem.json'))
const ForkonomicSystem = TruffleContract(ForkonomicSystemJSON)
const ForkonomicTokenJSON = JSON.parse(fs.readFileSync('./build/contracts/ForkonomicToken.json'))
const ForkonomicToken = TruffleContract(ForkonomicTokenJSON)
StandardMarket.setProvider(web3.currentProvider)
ForkonomicSystem.setProvider(web3.currentProvider)
ForkonomicToken.setProvider(web3.currentProvider)

ForkonomicSystem.currentProvider.sendAsync = function () {
    return ForkonomicSystem.currentProvider.send.apply(ForkonomicSystem.currentProvider, arguments);
};

ForkonomicToken.currentProvider.sendAsync = function () {
    return ForkonomicToken.currentProvider.send.apply(ForkonomicToken.currentProvider, arguments);
};

StandardMarket.currentProvider.sendAsync = function () {
    return StandardMarket.currentProvider.send.apply(StandardMarket.currentProvider, arguments);
};

module.exports = (async () => {
    web3.eth.defaultAccount = '0xd912aecb07e9f4e1ea8e6b4779e7fb6aa1c3e4d8'
    console.log(web3.eth.defaultAccount)
    const fSystem = await ForkonomicSystem.deployed()
    const fToken = await ForkonomicToken.deployed()
    const sMarket = await StandardMarket.deployed()
    const branch = await fSystem.genesisBranchHash.call()

    console.log(branch)
    console.log(sMarket.address)
    await fToken.approve(sMarket.address, 2100000000, branch, {from: web3.eth.defaultAccount})
    console.log("Approval done")
    console.log(await fToken.allowance(web3.eth.defaultAccount, sMarket.address, branch))
    await sMarket.fund(210000000, {from: web3.eth.defaultAccount, gas: 6000000})
    console.log(await sMarket.funding())
  process.exit(0)
})()