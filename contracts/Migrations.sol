pragma solidity ^0.4.2;
import '@josojo/forkonomics-contracts/contracts/Distribution.sol';
import '@josojo/forkonomics-contracts/contracts/ForkonomicETTF.sol';
import '@gnosis.pm/pm-contracts/contracts/Markets/StandardMarket.sol';
import '@gnosis.pm/pm-contracts/contracts/MarketMakers/LMSRMarketMaker.sol';

contract Migrations {
  address public owner;
  uint public last_completed_migration;

  modifier restricted() {
    if (msg.sender == owner) _;
  }

  function Migrations() {
    owner = msg.sender;
  }

  function setCompleted(uint completed) restricted {
    last_completed_migration = completed;
  }

  function upgrade(address new_address) restricted {
    Migrations upgraded = Migrations(new_address);
    upgraded.setCompleted(last_completed_migration);
  }
}
