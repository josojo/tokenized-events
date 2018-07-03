pragma solidity ^0.4.24;
import "./Event.sol";
import "./Proxy.sol";

import "@josojo/realitytoken-contracts/contracts/RealityToken.sol";
import "@josojo/realitycheck-contracts/contracts/RealityCheck.sol";

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

    mapping( address => bytes32[]) branchesUsedForWithdraw;
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
        RealityToken _realityToken,
        RealityCheck _realityCheck,
        address outcomeTokenMasterCopy,
        bytes32 _collateralBranch,
        bytes32 _questionId,
        int _lowerBound,
        int _upperBound
    )
        Proxy(proxied)
        public
    {
        // Validate input
        require(address(_realityToken) != 0 && address(_realityCheck) != 0);
        require(_collateralBranch != bytes32(0));

        realityToken = _realityToken;
        collateralBranch = _collateralBranch;
        questionId = _questionId;
        realityCheck = _realityCheck;
        // Create an outcome token for each outcome
        for (uint8 i = 0; i < 2; i++) {
            OutcomeToken outcomeToken = OutcomeToken(new OutcomeTokenProxy(outcomeTokenMasterCopy));
            outcomeTokens.push(outcomeToken);
            emit OutcomeTokenCreation(outcomeToken, i);
        }
    
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
    function redeemWinnings(bytes32 branchForWithdraw)
        public
        returns (uint winnings)
    {
       require(eligibleBranchForWithdraw(branchForWithdraw, collateralBranch, msg.sender));
        branchesUsedForWithdraw[msg.sender].push(branchForWithdraw);
        int outcome = getOutcome(branchForWithdraw);
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
        uint shortOutcomeTokenCount = outcomeTokensCountShort[msg.sender];
        uint longOutcomeTokenCount = outcomeTokensCountLong[msg.sender];
        winnings = shortOutcomeTokenCount.mul(factorShort).add(longOutcomeTokenCount.mul(factorLong)) / OUTCOME_RANGE;
        // Revoke all outcome tokens


        // Payout winnings to sender
        require(realityToken.transfer(msg.sender, winnings, branchForWithdraw));
        emit WinningsRedemption(msg.sender, winnings, branchForWithdraw);
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

    // @dev: this function checks whether a branch is eligigble for a withdraw. 
    // if there is a closer parentbranch that the branchFromPreviousWithdraw we throw as well
    function eligibleBranchForWithdraw(bytes32 branchForWithdraw, bytes32 depositBranch, address _for)
    public view returns(bool)
    {
        
        // check that tokens were not yet withdrawn in inbetween branches
        for(uint i=0;i < branchesUsedForWithdraw[_for].length;i++) {
            if(realityToken.isBranchInBetweenBranches(branchesUsedForWithdraw[_for][i], depositBranch, branchForWithdraw))
                return false;   
            }
        
        // check that tokens will be withdrawn on a child branch of branch of question
        bytes32 branchParent = branchForWithdraw;
        while(branchParent != depositBranch){
            branchParent = realityToken.getParentBranch(branchParent);
            if(branchParent == bytes32(0))
                return false;
        }
        return true;
    }

}

    