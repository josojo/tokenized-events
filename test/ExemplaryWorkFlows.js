/* eslint no-console:0, max-len:0, no-plusplus:0, no-mixed-operators:0, no-trailing-spaces:0 */


const ScalarEvent = artifacts.require('./ScalarEvent');
const ScalarEventProxy = artifacts.require('./ScalarEventProxy'); 
const OutcomeToken = artifacts.require('./OutcomeToken'); 

const { 
  eventWatcher,
  logger,
  timestamp,
  gasLogger,
  enableContractFlag,
  getParamFromTxEvent,
} = require('./utils')

const {
  setupTest,
  getContracts,
  genesis_branch,
  first_branch,
  wait,
  bn,
  arbitrationCost,
  initialFunding,
  feeForRealityToken,
} = require('./testingFunctions')

// Test VARS
let initialDistribution
let dataContract1
let realityToken
let realityCheck
let contracts
let branches 
let questionId
let eventDerivative;
let longTokens;
let shortTokens;
let stableTokens;
let YES = '0x0000000000000000000000000000000000000000000000000000000000000032'
YES = new String(YES).valueOf()
let NO = '0x0000000000000000000000000000000000000000000000000000000000000000'
NO = new String(NO).valueOf()

const historyHashes = []
const answers = []
const submiters = []
const bonds = []

const setupContracts = async () => {
  contracts = await getContracts();
  // destructure contracts into upper state
  ({
    RealityToken: realityToken,
    RealityCheck: realityCheck,
  } = contracts)
}

const startBal = {
  amountRLT: 50e18,
}
const betAmount = 1e5


const c1 = () => contract('Financial Products - Short position on an ERC20 Token', (accounts) => {
  const [master, arbitrator, RCasker, bonder50, bonder0, BranchProvider, MarketMaker, Consumer] = accounts

  before(async () => {
    // get contracts
    await setupContracts()
    // set up accounts and tokens[contracts]
    const first_branch = await setupTest(accounts, contracts, startBal)
    branches = [[genesis_branch], [first_branch]]
  })

  afterEach(gasLogger)

  it('step 1 - The realityCheck event is created', async () => {
    await realityToken.approve(realityCheck.address, betAmount, branches[1][0], { from: RCasker })
    assert.equal((await realityToken.allowance(RCasker, realityCheck.address, branches[1][0])).toNumber(), betAmount)
    const transaction = await realityCheck.askQuestion(0, 'What will be the price ERC20/RealityToken on 1.1.2019', 60 * 60 * 10, 0, 0, betAmount, branches[1][0], 0, { from: RCasker })
    questionId = getParamFromTxEvent(transaction, 'question_id', 'LogNewQuestion')
    console.log(`question asked with question_id${questionId}`)
  })

  it('step 2 - Tokenize the event and create the financial derivative', async () => {
    let scalarEventLogic = await ScalarEvent.new();
    let outcomeTokenLogic = await OutcomeToken.new();
    eventDerivativeProxy = await ScalarEventProxy.new(scalarEventLogic.address,
        realityToken.address,
        realityCheck.address,
        outcomeTokenLogic.address,
        branches[1][0],
        questionId,
        0,
        100)
    eventDerivative = ScalarEvent.at(eventDerivativeProxy.address)
    longTokens = OutcomeToken.at(await eventDerivative.outcomeTokens(0));
    shortTokens = OutcomeToken.at(await eventDerivative.outcomeTokens(1));
    //funding markets
    await realityToken.approve(eventDerivativeProxy.address, 30e8, branches[1][0], {from: MarketMaker})
    await eventDerivative.buyAllOutcomes(30e8, {from: MarketMaker});
    assert.equal(await longTokens.balanceOf(MarketMaker),30e8,"long tokens were not created")
    })

   it('step 3 - MarketMaker trades his OutcomeTokens ', async () => {
    await shortTokens.transfer(Consumer, 10e8, {from: MarketMaker})
    assert.equal((await shortTokens.balanceOf(Consumer)).toNumber(), 10e8)
    })

  it('step 4 - bonder50 provides the answer 50', async () => {
    await realityToken.approve(realityCheck.address, betAmount, branches[1][0], { from: bonder50 })
    assert.equal((await realityToken.allowance(bonder50, realityCheck.address, branches[1][0])).toNumber(), betAmount)
    const transaction = await realityCheck.submitAnswer(questionId, YES, betAmount, betAmount, { from: bonder50 })
    historyHashes.push(new String(getParamFromTxEvent(transaction, 'history_hash', 'LogNewAnswer')).valueOf())
    answers.push(YES)
    submiters.push(bonder50)
    bonds.push(betAmount)
  })

  it('step 5 - bonder0 provides the answer 0 doubling the bonding', async () => {
    await realityToken.approve(realityCheck.address, 2 * betAmount, branches[1][0], { from: bonder0 })
    assert.equal((await realityToken.allowance(bonder0, realityCheck.address, branches[1][0])).toNumber(), 2 * betAmount)
    const transaction = await realityCheck.submitAnswer(questionId, NO, 2 * betAmount, 2 * betAmount, { from: bonder0 })
    historyHashes.push(new String(getParamFromTxEvent(transaction, 'history_hash', 'LogNewAnswer')).valueOf())
    answers.push(NO)
    submiters.push(bonder0)
    bonds.push(2 * betAmount)
  })
  it('step 6 - bonder50 pays the RealityToken to arbitrate', async () => {
    const arbitratorList = artifacts.require('./ArbitratorList').at(await realityToken.getArbitratorList(branches[1][0]))
    const arbitratorData = artifacts.require('./RealityCheckArbitrator').at(await arbitratorList.arbitrators(0))
    await arbitratorData.notifyOfArbitrationRequest(questionId, bonder0, branches[1][0], { from: arbitrator })
  })
  it('step 7 - Arbitrator submits the answer Yes and new branch is submitted', async () => {
    const arbitratorList = artifacts.require('./ArbitratorList').at(await realityToken.getArbitratorList(branches[1][0]))
    // create new branch:
    await wait(86400)

    const transaction = await realityToken.createBranch(branches[1][0], genesis_branch, arbitratorList.address, master, 0)
    const second_branch = getParamFromTxEvent(transaction, 'hash', 'BranchCreated')
    console.log(`second branch created with hash${second_branch}`)
    branches.push([second_branch])

    const arbitratorData = artifacts.require('./RealityCheckArbitrator').at(await arbitratorList.arbitrators(0))
    await arbitratorData.addAnswer([questionId], [YES], [7], { from: arbitrator })

    // create new branch:
    await wait(86400)
    const transaction2 = await realityToken.createBranch(branches[2][0], genesis_branch, arbitratorList.address, master, 0)
    const third_branch = getParamFromTxEvent(transaction2, 'hash', 'BranchCreated')
    console.log(`second branch created with hash${third_branch}`)
    branches.push([third_branch])

  })
  it('step 8 - bonder0 makes himself a arbitrator, and submits the answer 0 in a new branch', async () => {
    const arbitratorData = await artifacts.require('./RealityCheckArbitrator').new(realityCheck.address, { from: bonder0 })
    const arbitratorList = await artifacts.require('./ArbitratorList').new([arbitratorData.address])
    
    await arbitratorData.addAnswer([questionId], [NO], [7], { from: bonder0 })

    const transaction = await realityToken.createBranch(branches[1][0], genesis_branch, arbitratorList.address, master, 0)
    const second_branch = getParamFromTxEvent(transaction, 'hash', 'BranchCreated')
    console.log(`second branch created with hash${second_branch}`)
    branches[2][1] = second_branch
  })
  it('step 9 - bonder50 withdraws the winnings on the yes branch', async () => {
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
    assert.equal((await realityToken.balanceOf(bonder50, branches[3][0])).toNumber(), initialFunding + betAmount + 2 * betAmount - feeForRealityToken)
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
    assert.equal((await realityToken.balanceOf(bonder50, branches[2][1])).toNumber(), initialFunding - betAmount)
  
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
})

enableContractFlag(c1)
