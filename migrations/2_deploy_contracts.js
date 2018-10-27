var ForkonomicSystem = artifacts.require("./ForkonomicSystem.sol");
var Realitio = artifacts.require("./Realitio.sol");

var ForkonomicToken = artifacts.require("./ForkonomicToken.sol")
var Distribution= artifacts.require("./Distribution.sol");
var ForkonomicETTF = artifacts.require("./ForkonomicETTF.sol")
var Math = artifacts.require("./Math")
var ScalarEvent = artifacts.require("./ScalarEvent")
var ScalarEventProxy = artifacts.require("ScalarEventProxy")
var OutcomeToken = artifacts.require("./OutcomeToken")
var LMSRMarketMaker = artifacts.require("LMSRMarketMaker")
var StandardMarket = artifacts.require("StandardMarket")

const feeForRealityToken = 100
const question ="How many points will the DOW JONES - divided by the RealityToken price - notate on the 1.1.2019  00:00:00?";
const openingTs = 18462972000; // date -d '1/1/2019 00:00:00' +"%s"
const timeout = 60*60*24  // one day
const templateId = 1 //asking for an uint
const minBound = 1000
const maxBound = 100000

module.exports = function(deployer, network, accounts) {
    deployer.deploy(ForkonomicSystem)
    .then(()=> deployer.deploy(Distribution))
    .then(()=> deployer.deploy(Realitio))
    .then(()=> deployer.deploy(ForkonomicToken, ForkonomicSystem.address, [accounts[0], accounts[1], accounts[2], Distribution.address]))
    .then(()=> deployer.deploy(ForkonomicETTF, Realitio.address, ForkonomicSystem.address, []))
  	.then(()=> deployer.deploy(Math))
  	.then(()=> deployer.link(Math, ScalarEvent))
  	.then(()=> deployer.link(Math, OutcomeToken))
  	.then(()=> deployer.link(Math, LMSRMarketMaker))
  	.then(()=> deployer.link(Math, StandardMarket))
    .then(()=> deployer.link(Math, ScalarEventProxy))

  	//.then(()=> deployer.deploy(OutcomeToken))
  	.then(()=> deployer.deploy(ScalarEvent))
  	.then(()=> ForkonomicSystem.deployed())
  	.then((fSystem)=> fSystem.genesisBranchHash())
  	.then((branch)=> deployer.deploy(ScalarEventProxy, ScalarEvent.address, ForkonomicToken.address, ForkonomicSystem.address, Realitio.address, branch,
		question,
		openingTs,
        timeout, 
        templateId,
        accounts[1], // arbitrator
        minBound, // min-bound
        maxBound))  // max-bound
  	.then(() => deployer.deploy(LMSRMarketMaker))
  	.then(() => deployer.deploy(StandardMarket, accounts[0], ScalarEventProxy.address, LMSRMarketMaker.address, 0))

}

