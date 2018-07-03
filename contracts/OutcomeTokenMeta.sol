
pragma solidity ^0.4.15;
import "@gnosis.pm/util-contracts/contracts/OutcomeToken.sol";

/// @title Outcome token contract - Issuing and revoking outcome tokens
/// @author Stefan George - <stefan@gnosis.pm>
contract OutcomeTokenMeta is OutcomeToken {
    using Math for *;


    string public name;
    string public symbol;
    uint8  public decimals = 18;

    /*
     *  Public functions
     */

    function OutcomeTokenMeta(string _name, string _symbol, address _eventcontract)
        public
    {
        name = _name;
        symbol = _symbol;
        eventContract = _eventcontract;
    }

}
