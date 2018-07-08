var RealityCheck = artifacts.require("@josojo/realitycheck-contracts/contracts/RealityCheck.sol");
var ArbitratorData = artifacts.require("@josojo/realitytoken-contracts/contracts/ArbitratorData.sol");
var ArbitratorList = artifacts.require("@josojo/realitytoken-contracts/contracts/ArbitratorList.sol");
var RealityToken = artifacts.require("@josojo/realitytoken-contracts/contracts/RealityToken.sol");
var InitialDistribution= artifacts.require("@josojo/realitytoken-contracts/contracts/Distribution.sol");
var Math = artifacts.require("./Math")
var SclarEvent = artifacts.require("./ScalarEvent")
var OutcomeToken = artifacts.require("./OutcomeToken")
const feeForRealityToken = 100

module.exports = function(deployer, network, accounts) {
    deployer.deploy(RealityToken)
  	.then(()=> deployer.deploy(RealityCheck, RealityToken.address, feeForRealityToken))
  	.then(()=> deployer.deploy(Math))
  	.then(()=> deployer.link(Math, SclarEvent))
  	.then(()=> deployer.link(Math, OutcomeToken))

}
