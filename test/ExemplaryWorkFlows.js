/* eslint no-console:0, max-len:0, no-plusplus:0, no-mixed-operators:0, no-trailing-spaces:0 */


const ScalarEvent = artifacts.require('./ScalarEvent');
const ScalarEventProxy = artifacts.require('./ScalarEventProxy'); 
const OutcomeToken = artifacts.require('./OutcomeToken'); 
const ForkonomicToken = artifacts.require("ForkonomicToken")
const ForkonomicSystem = artifacts.require("ForkonomicSystem")
const Realitio = artifacts.require("Realitio")


const { 
  getContracts,
  bn,
  createNewBranch,
} = require('./testingFunctions.js')

const {
  assertRejects,
  timestamp,
  increaseTime,
  increaseTimeTo,
  padAddressToBytes32,
} = require("./utilities.js")
const { wait } = require('@digix/tempo')(web3)

// Vars from the deployment script:
const question ="How many points will the DOW JONES - divided by the RealityToken price - notate on the 1.1.2019  00:00:00?";
const openingTs = 18462972000; // date -d '1/1/2019 00:00:00' +"%s"
const timeout = 60*60*24  // one day
const templateId = 1 //asking for an uint
const minBound = 1000
const maxBound = 100000


// Test VARS
let initialDistribution
let contracts
let branches 
let questionId
let eventDerivative;
let longTokens;
let shortTokens;
let stableTokens;

// predefine variables
let TwentyThoustand = '0x0000000000000000000000000000000000000000000000000000000000004E20'// 20k in hex is 4E20
let TenThoustand = '0x0000000000000000000000000000000000000000000000000000000000010000'// 10k in hex is 2710
let YES = '0x0000000000000000000000000000000000000000000000000000000000000032'
YES = new String(YES).valueOf()
let NO = '0x0000000000000000000000000000000000000000000000000000000000000000'
NO = new String(NO).valueOf()

const historyHashes = []
const answers = []
const submiters = []
const bonds = []
let branch = []
let currentBranch
let newBranchHash


const startBal = {
  amountRLT: 50e18,
}
const betAmount = 1e5
let fSystem
let fToken
let realityCheck
let scalarEventProxy

contract('Financial Products - Short position on an ERC20 Token', (accounts) => {
  const [master, arbitrator, MarketMaker, RCasker, bonder20k, bonder0, BranchProvider, Consumer] = accounts

  before(async () => {
    // get contracts
    fSystem = await ForkonomicSystem.deployed();
    fToken = await ForkonomicToken.deployed();
    realityCheck = await Realitio.deployed();
    scalarEventProxy = await ScalarEventProxy.deployed();
    eventDerivative = await ScalarEvent.at(ScalarEventProxy.address)
    branch.push(await fSystem.genesisBranchHash())
  })


  it('step 1 - The realityCheck event is created', async () => {
    questionId = await  eventDerivative.questionId()
  })

  it('step 2 - Tokenize the event and create the financial derivative', async () => {
    const currentBranch = await fSystem.genesisBranchHash.call()
    longTokens = await OutcomeToken.at(await eventDerivative.outcomeTokens(0));
    shortTokens = await OutcomeToken.at(await eventDerivative.outcomeTokens(1));
     //funding markets
     console.log(await longTokens.eventContract.call())
     console.log(eventDerivative.address)
    await fToken.approve(eventDerivative.address, 30e4, currentBranch, {from: MarketMaker})
    await eventDerivative.buyAllOutcomes(30e4, {from: MarketMaker});
    assert.equal((await longTokens.balanceOf(MarketMaker)).toNumber(),30e4,"long tokens were not created")
  })

  it('step 3 - MarketMaker trades his OutcomeTokens ', async () => {
    await shortTokens.transfer(Consumer, 10e4, {from: MarketMaker})
    assert.equal((await shortTokens.balanceOf(Consumer)).toNumber(), 10e4)
  })


  it('step 4 - bonder20k provides the answer 20k', async () => {
    const openingTs = (await eventDerivative.openingTs.call()).toNumber()
    await increaseTimeTo(openingTs +1)
    await realityCheck.submitAnswer(questionId, TwentyThoustand, 50000000000,  { from: bonder20k, value: 5000})
    const timeout = (await realityCheck.getFinalizeTS(questionId)).toNumber()
    await increaseTimeTo(timeout+1)
  })

  it('Creating new branches', async () => {

    fSystem = await ForkonomicSystem.deployed();
    const keyForArbitrators = await fSystem.createArbitratorWhitelist.call([arbitrator])
    await fSystem.createArbitratorWhitelist([arbitrator])
    const genesis_branch = await fSystem.genesisBranchHash.call();
    var currentBranch = genesis_branch
    const nrOfBranches = (await timestamp() - await fSystem.genesisWindowTimestamp.call())/(await fSystem.WINDOWTIMESPAN.call()).toNumber()
    for (var i = 1; i < nrOfBranches; i++) {
      newBranchHash =  await fSystem.createBranch.call(currentBranch, keyForArbitrators)
      await fSystem.createBranch(currentBranch, keyForArbitrators)
      currentBranch = newBranchHash
    }
    const waitingTime = (await fSystem.WINDOWTIMESPAN()).toNumber()+1
    await increaseTime(waitingTime)
    newBranchHash =  await fSystem.createBranch.call(currentBranch, keyForArbitrators)
    await fSystem.createBranch(currentBranch, keyForArbitrators)

  })

  it('step 5 - Consumer gets winnings from dow jones bet', async () => {
    assert.equal((await shortTokens.balanceOf(Consumer)).toNumber(), 10e4)
    assert.equal((await fToken.balanceOf.call(Consumer, newBranchHash)).toNumber(), 0)
    await eventDerivative.revokeOutcomeTokens({from: Consumer})
    console.log(await eventDerivative.getOutcome(newBranchHash, arbitrator, {from: Consumer}))

    await eventDerivative.redeemWinnings(newBranchHash, arbitrator, {from: Consumer})
    assert.equal((await shortTokens.balanceOf(Consumer)).toNumber(), 0)
    assert.equal((await fToken.balanceOf.call(Consumer, newBranchHash)).toNumber(), Math.ceil(10e4*(20000-minBound)/(maxBound-minBound))-1)

  })


/*
 
  it('step 8 - bonder0 makes himself a arbitrator, and submits the answer 0 in a new branch', async () => {
    const arbitratorData = await artifacts.require('./RealitioArbitrator').new(realityCheck.address, { from: bonder0 })
    const arbitratorList = await artifacts.require('./ArbitratorList').new([arbitratorData.address])
    
    await arbitratorData.addAnswer([questionId], [NO], [7], { from: bonder0 })

    const transaction = await realityToken.createBranch(branches[1][0], genesis_branch, arbitratorList.address, master, 0)
    const second_branch = getParamFromTxEvent(transaction, 'hash', 'BranchCreated')
    console.log(`second branch created with hash${second_branch}`)
    branches[2][1] = second_branch
  })
  it('step 9 - bonder20k withdraws the winnings on the yes branch', async () => {
    submiters.reverse()
    bonds.reverse()
    answers.reverse()

    await realityCheck.claimWinnings(
      branches[3][0],
      NO,
      questionId, 
      [historyHashes[0], NO],
      submiters,
      bonds,
      answers,
    )
    assert.equal((await realityToken.balanceOf(bonder20k, branches[3][0])).toNumber(), initialFunding + betAmount + 2 * betAmount - feeForRealityToken)
    assert.equal((await realityToken.balanceOf(bonder0, branches[3][0])).toNumber(), initialFunding - 2 * betAmount )
  })
  it('step 10 - bonder0 withdraws the winnings on the no branch', async () => {
    const previousBal = (await realityToken.balanceOf(bonder0, branches[2][1]))
    await realityCheck.claimWinnings(
      branches[2][1],
      NO,
      questionId, 
      [historyHashes[0], NO],
      submiters,
      bonds,
      answers,
    ) 
    assert.equal((await realityToken.balanceOf(bonder0, branches[2][1])).toNumber(), initialFunding + betAmount + betAmount - feeForRealityToken)
    assert.equal((await realityToken.balanceOf(bonder20k, branches[2][1])).toNumber(), initialFunding - betAmount)
  
  })

    it('step 11 - Consume uses the derivative product only on the "right 50" branch', async () => {
      await eventDerivative.revokeOutcomeTokens({from: Consumer})
      assert.equal((await eventDerivative.getOutcome(branches[3][0], {from: Consumer})).toNumber(), 50)
      await eventDerivative.redeemWinnings(branches[3][0], {from: Consumer})
      assert.equal((await realityToken.balanceOf(Consumer, branches[3][0])).toNumber(),5e8)
  })

    it('step 12 - Consume does not get any tokens on the manipulated branch', async () => {
      assert.equal((await eventDerivative.getOutcome(branches[2][1], {from: Consumer})).toNumber(),0)
      await eventDerivative.redeemWinnings(branches[2][1], {from: Consumer})
      assert.equal((await realityToken.balanceOf(Consumer, branches[2][1])).toNumber(),0)
  })
*/})

