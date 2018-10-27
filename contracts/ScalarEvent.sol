pragma solidity ^0.4.24;
import "./Event.sol";
import "./Proxy.sol";
import "@josojo/forkonomics-contracts/contracts/ForkonomicToken.sol";
import "@josojo/forkonomics-contracts/contracts/ForkonomicSystem.sol";
import "@realitio/realitio-contracts/truffle/contracts/Realitio.sol";


contract ScalarEventData {

    /*
     *  Constants
     */
    uint8 public constant SHORT = 0;
    uint8 public constant LONG = 1;
    uint24 public constant OUTCOME_RANGE = 1000000;

    /*
     *  Storage
     */
    int public lowerBound;
    int public upperBound;

    // user => tokenCount of Short outcomeTokens
    mapping( address => uint) outcomeTokensCountShort;
    // user => tokenCount of Long outcomeTokens
    mapping( address => uint) outcomeTokensCountLong;

}


contract ScalarEventProxy is Proxy, EventData, ScalarEventData {

    /// @dev Contract constructor validates and sets basic event properties

    /// @param _collateralBranch Tokens used as collateral in exchange for outcome tokens
    /// @param _realityCheck Oracle contract used to resolve the event
    /// @param _lowerBound Lower bound for event outcome
    /// @param _upperBound Lower bound for event outcome
    constructor(
        address proxied,
        ForkonomicToken _forkonomicToken,
        ForkonomicSystem _fSystem,
        Realitio _realityCheck,
        bytes32 _collateralBranch,
        string question_,
        uint32 openingTs_,
        uint32  minTimeout_,
        uint256 templateId_,
        address arbitrator,
        int _lowerBound,
        int _upperBound
    )
        Proxy(proxied)
        public
    {
        // Validate input
        require(address(_forkonomicToken) != 0 && address(_realityCheck) != 0, "please check the input for the constructor");
        require(_collateralBranch != bytes32(0), " please check the collateralBranch");

        forkonomicToken = _forkonomicToken;
        fSystem = _fSystem;
        collateralBranch = _collateralBranch;


        // create question in relaityCheck
        openingTs = openingTs_;
        minTimeout = minTimeout_; 
        content_hash = keccak256(abi.encodePacked(templateId_, openingTs_, question_));  

        realityCheck = _realityCheck;
        questionId = realityCheck.askQuestion(templateId_, question_, arbitrator, minTimeout, openingTs_, 0);

        // Create an outcome token for each outcome
        // Create LongTokens    
        OutcomeToken outcomeToken = new OutcomeToken("LONG", string(abi.encodePacked("Long Token for Event ", questionId)));
        outcomeTokens.push(outcomeToken);
        emit OutcomeTokenCreation(outcomeToken, 1);
        //create ShortTokens
        outcomeToken = new OutcomeToken("SHRT", string(abi.encodePacked("Short Token for Event ", questionId)));
        outcomeTokens.push(outcomeToken);
        emit OutcomeTokenCreation(outcomeToken, 2);
            
    
        // Validate bounds
        require(_upperBound > _lowerBound, " bounds are not set correctly");
        lowerBound = _lowerBound;
        upperBound = _upperBound;
    }
}


/// @title Scalar event contract - Scalar events resolve to a number within a range
/// @author Stefan George - <stefan@gnosis.pm>
contract ScalarEvent is Proxied, EventData, ScalarEventData {
    using Math for *;

    /*
     *  Public functions
     */

    bytes32 constant NULL_HASH = "";
    address constant NULL_ADDRESS = 0x0;


    function revokeOutcomeTokens()
        public
    {
        // only possible, if tokens were not yet revoked by this account
        // if this function has already been used, the tokens needs to be transfered to another account
        require(outcomeTokensCountShort[msg.sender] == 0 && outcomeTokensCountLong[msg.sender] == 0, "tokens have already been revoked");
        uint shortOutcomeTokenCount = outcomeTokens[SHORT].balanceOf(msg.sender);
        outcomeTokensCountShort[msg.sender] = shortOutcomeTokenCount;
        outcomeTokens[SHORT].revoke(msg.sender, shortOutcomeTokenCount);
        uint longOutcomeTokenCount = outcomeTokens[LONG].balanceOf(msg.sender);
        outcomeTokensCountLong[msg.sender] = longOutcomeTokenCount;
        outcomeTokens[LONG].revoke(msg.sender, longOutcomeTokenCount);
    } 

    /// @dev Exchanges sender's winning outcome tokens for collateral tokens
    /// @return Sender's winnings
    function redeemWinnings(bytes32 branchForWithdraw, address arbitrator)
        public
        returns (uint winnings)
    {

        uint shortOutcomeTokenCount = outcomeTokensCountShort[msg.sender];
        uint longOutcomeTokenCount = outcomeTokensCountLong[msg.sender];

        // tokens need to be revoked before winnings can be redeemed
        require(shortOutcomeTokenCount > 0 || longOutcomeTokenCount > 0, " first tokens must be revoked");

        //calculate the winnings
        int outcome = getOutcome(branchForWithdraw, arbitrator);

        // Outcome is lower than defined lower bound
        uint24 convertedWinningOutcome;
        if (outcome < lowerBound)
            convertedWinningOutcome = 0;
        // Outcome is higher than defined upper bound
        else if (outcome > upperBound)
            convertedWinningOutcome = OUTCOME_RANGE;
        // Map outcome to outcome range
        else
            convertedWinningOutcome = uint24(OUTCOME_RANGE * (outcome - lowerBound) / (upperBound - lowerBound));
        uint factorShort = OUTCOME_RANGE - convertedWinningOutcome;
        uint factorLong = OUTCOME_RANGE - factorShort;
        winnings = (shortOutcomeTokenCount.mul(factorShort).add(longOutcomeTokenCount.mul(factorLong))) / OUTCOME_RANGE;

        // Payout winnings to sender
        require(!ForkonomicToken(forkonomicToken).hasBoxWithdrawal(msg.sender, NULL_HASH, branchForWithdraw, collateralBranch), "there had already been a withdrawal (redeemWinnings)"); 
        require(ForkonomicToken(forkonomicToken).boxTransfer(msg.sender, winnings, branchForWithdraw, NULL_HASH, NULL_HASH), "transfer went wrong (redeemWinnings)");
        require(ForkonomicToken(forkonomicToken).recordBoxWithdrawal(msg.sender, NULL_HASH, winnings, branchForWithdraw), "withdrawal could not be recorded");
           
        emit WinningsRedemption(msg.sender, winnings, branchForWithdraw);
    }

    /// @dev Risky operation, deletes data and can safe gas in combination with other function calls
    /// @return free gas
    function clearData()
    public {
        delete outcomeTokensCountShort[msg.sender];
        delete outcomeTokensCountLong[msg.sender];
    }    

    /// @dev Calculates and returns event hash
    /// @return Event hash
    function getEventHash()
        public
        view
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(collateralBranch, questionId, lowerBound, upperBound));
    }


    /*
     *  Public functions
     */
    /// @dev Buys equal number of tokens of all outcomes, exchanging collateral tokens and sets of outcome tokens 1:1
    /// @param collateralTokenCount Number of collateral tokens
    function buyAllOutcomes(uint collateralTokenCount)
        public
    {
        // Transfer collateral tokens to events contract
        require(forkonomicToken.transferFrom(msg.sender, this, collateralTokenCount, collateralBranch), "transfer was not possible");
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

        require(fSystem.isBranchCreatedAfterTS(realityCheck.getFinalizeTS(questionId), branch), "branch is to old");

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

    