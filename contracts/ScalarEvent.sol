pragma solidity ^0.4.24;
import "./Event.sol";
import "./Proxy.sol";
import "@josojo/forkonomics-contracts/contracts/ForkonomicToken.sol";
import "@realitio/realitio-contracts/truffle/contracts/RealityCheck.sol";


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
        RealityCheck _realityCheck,
        address outcomeTokenMasterCopy,
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
        require(address(_forkonomicToken) != 0 && address(_realityCheck) != 0);
        require(_collateralBranch != bytes32(0));

        forkonomicToken = _forkonomicToken;
        collateralBranch = _collateralBranch;


        // create question in relaityCheck
        openingTs = openingTs_;
        minTimeout = minTimeout_; 
        content_hash = keccak256(templateId_, openingTs_, question_);  

        realityCheck = _realityCheck;
        questionId = realityCheck.askQuestion(templateId_, question_, arbitrator, minTimeout, openingTs_, 0);

        // Create an outcome token for each outcome
        // Create LongTokens    
        OutcomeToken outcomeToken = OutcomeToken(new OutcomeTokenProxy(outcomeTokenMasterCopy, "LONG", string(abi.encodePacked("Long Token for Event ", questionId))));
        outcomeTokens.push(outcomeToken);
        emit OutcomeTokenCreation(outcomeToken, 1);
        //create ShortTokens
        outcomeToken = OutcomeToken(new OutcomeTokenProxy(outcomeTokenMasterCopy, "SHRT", string(abi.encodePacked("Short Token for Event ", questionId))));
        outcomeTokens.push(outcomeToken);
        emit OutcomeTokenCreation(outcomeToken, 2);
            
    
        // Validate bounds
        require(_upperBound > _lowerBound);
        lowerBound = _lowerBound;
        upperBound = _upperBound;
    }
}


/// @title Scalar event contract - Scalar events resolve to a number within a range
/// @author Stefan George - <stefan@gnosis.pm>
contract ScalarEvent is Proxied, Event, ScalarEventData {
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
        require(outcomeTokensCountShort[msg.sender] == 0 && outcomeTokensCountLong[msg.sender] == 0);
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
        //require(shortOutcomeTokenCount > 0 || longOutcomeTokenCount > 0);

        //calculate the winnings
        int outcome = getOutcome(branchForWithdraw, arbitrator);
        // Outcome is lower than defined lower bound
        uint convertedWinningOutcome = 0;
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
        winnings = shortOutcomeTokenCount.mul(factorShort).add(longOutcomeTokenCount.mul(factorLong)) / OUTCOME_RANGE;

        // Payout winnings to sender
        //require(!ForkonomicToken(forkonomicToken).hasBoxWithdrawal(msg.sender, NULL_HASH, branchForWithdraw, collateralBranch)); 
        //require(ForkonomicToken(forkonomicToken).boxTransfer(msg.sender, winnings, branchForWithdraw, NULL_HASH, NULL_HASH));
        //require(ForkonomicToken(forkonomicToken).recordBoxWithdrawal(NULL_HASH, winnings, branchForWithdraw));
           
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

}

    