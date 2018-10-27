pragma solidity ^0.4.24;
import "@gnosis.pm/pm-contracts/contracts/Tokens/Token.sol";
import "./OutcomeToken.sol";
import "./Proxy.sol";
import "@josojo/forkonomics-contracts/contracts/ForkonomicToken.sol";
import "@realitio/realitio-contracts/truffle/contracts/Realitio.sol";


contract EventData {

    /*
     *  Events
     */
    event OutcomeTokenCreation(OutcomeToken outcomeToken, uint8 index);
    event OutcomeTokenSetIssuance(address indexed buyer, uint collateralTokenCount);
    event OutcomeTokenSetRevocation(address indexed seller, uint outcomeTokenCount);
    event WinningsRedemption(address indexed receiver, uint winnings, bytes32 branch);
    event LogB(bytes32 a);
    /*
     *  Storage
     */
    OutcomeToken[] public outcomeTokens;


    ForkonomicToken public forkonomicToken;
    ForkonomicSystem public fSystem;
    bytes32 public collateralBranch;
    bytes32 public questionId;
    bytes32 public content_hash;
    uint256 public minBond = 500;
    uint32 public minTimeout = 60*60*24;
    uint32 public openingTs;
    Realitio realityCheck;
    bytes32 public outcome;

}

/// @title Event contract - Provide basic functionality required by different event types
contract Event is Proxied, EventData {

    /*
     *  Public functions
     */
    /// @dev Buys equal number of tokens of all outcomes, exchanging collateral tokens and sets of outcome tokens 1:1
    /// @param collateralTokenCount Number of collateral tokens
    function buyAllOutcomes(uint collateralTokenCount)
        public
    {
        // Transfer collateral tokens to events contract
        //require(forkonomicToken.transferFrom(msg.sender, this, collateralTokenCount, collateralBranch), "transfer was not possible");
        // Issue new outcome tokens to sender
        for (uint8 i = 0; i < outcomeTokens.length; i++)
            outcomeTokens[i].issue(msg.sender, collateralTokenCount);
        emit OutcomeTokenSetIssuance(msg.sender, collateralTokenCount);
    }

    /// @dev Sells equal number of tokens of all outcomes, exchanging collateral tokens and sets of outcome tokens 1:1
    /// @param outcomeTokenCount Number of outcome tokens
    function sellAllOutcomes(uint outcomeTokenCount)
        public
    {  
          // Revoke sender's outcome tokens of all outcomes
        for (uint8 i = 0; i < outcomeTokens.length; i++)
            outcomeTokens[i].revoke(msg.sender, outcomeTokenCount);
        // Transfer collateral tokens to sender
        require(forkonomicToken.transfer(msg.sender, outcomeTokenCount, collateralBranch), "transfer failed");
        emit OutcomeTokenSetRevocation(msg.sender, outcomeTokenCount);
    }

 
    /// @dev gets winning event outcome
    /// @param branch is the branch on which a user wants to know the result
    function getOutcome(bytes32 branch, address arbitrator)
        public
        view
        returns (int outcome)
    {

        // check that original branch is a father of executionbranch:
        require(fSystem.isFatherOfBranch(collateralBranch, branch), " not a fahter branch");

         // ensure that arbitrator is white-listed
        require(fSystem.isArbitratorWhitelisted(arbitrator, branch), "arbitrator not white-listed");

        require(fSystem.branchTimestamp(branch) > realityCheck.getFinalizeTS(questionId) - fSystem.WINDOWTIMESPAN(), "branch is to old");
        outcome = int(realityCheck.getFinalAnswerIfMatches(questionId, content_hash, arbitrator, minTimeout, minBond));
    }

    /// @dev Returns outcome count
    /// @return Outcome count
    function getOutcomeCount()
        public
        view
        returns (uint8)
    {
        return uint8(outcomeTokens.length);
    }

    /// @dev Returns outcome tokens array
    /// @return Outcome tokens
    function getOutcomeTokens()
        public
        view
        returns (OutcomeToken[])
    {
        return outcomeTokens;
    }

    /// @dev Returns the amount of outcome tokens held by owner
    /// @return Outcome token distribution
    function getOutcomeTokenDistribution(address owner)
        public
        view
        returns (uint[] outcomeTokenDistribution)
    {
        outcomeTokenDistribution = new uint[](outcomeTokens.length);
        for (uint8 i = 0; i < outcomeTokenDistribution.length; i++)
            outcomeTokenDistribution[i] = outcomeTokens[i].balanceOf(owner);
    }

}
