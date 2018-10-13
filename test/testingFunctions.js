/*
  eslint prefer-const: 0,
  max-len: 0,
  object-curly-newline: 1,
  no-param-reassign: 0,
  no-console: 0,
  no-mixed-operators: 0,
  no-floating-decimal: 0,
  no-underscore-dangle:0,
  no-return-assign:0,
*/
const bn = require('bignumber.js')
const { wait } = require('@digix/tempo')(web3)
const {
  gasLogWrapper,
  log,
  timestamp,
  varLogger,
  getParamFromTxEvent,
} = require('./utils')

// I know, it's gross
// add wei converter
/* eslint no-extend-native: 0 */

Number.prototype.toWei = function toWei() {
  return bn(this, 10).times(10 ** 18).toNumber()
}
Number.prototype.toEth = function toEth() {
  return bn(this, 10).div(10 ** 18).toNumber()
}

let genesis_branch = '0xfca5e1a248b8fee34db137da5e38b41f95d11feb5a8fa192a150d8d5d8de1c59'
genesis_branch = new String(genesis_branch).valueOf()


const contractNames = [
  'Realitio',
  'ForkonomicToken',
  'ForkonomicSystem',
  'OutcomeToken',
  'StandardMarket',
  'LMSRMarketMaker',
]

/**
 * getContracts - async loads contracts and instances
 *
 * @returns { Mapping(contractName => deployedContract) }
 */
const getContracts = async () => {
  const depContracts = contractNames.map(c => artifacts.require(c)).map(cc => cc.deployed())
  const contractInstances = await Promise.all(depContracts)

  const deployedContracts = contractNames.reduce((acc, name, i) => {
    acc[name] = contractInstances[i]
    return acc
  }, {});

  return deployedContracts
}

const createNewBranch = async (parentHash, arbitratorIdentifier) => {
  // create new branch:
  await wait(await ForkonoimcSystem.WINDOWTIMESPAN())

  const transaction = await ForkonomicSystem.createBranch(parentHash, arbitratorIdentifier)
  new_branch = getParamFromTxEvent(transaction, 'branchHash', 'BranchCreated')
  console.log("new branch created with the hash"+ new_branch)
  return new_branch
}

module.exports = {
  getContracts,
  bn,
  createNewBranch,
}
