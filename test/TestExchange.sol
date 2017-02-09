pragma solidity ^0.4.2;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/Exchange.sol";

contract TestExchange {

    function testSomething() {
        uint expected = 1;
        Assert.equal(1, expected, "What?");
    }

  /*function testInitialBalanceUsingDeployedContract() {
    Exchange meta = Exchange(DeployedAddresses.Exchange());

    uint expected = 10000;

    Assert.equal(meta.getBalance(tx.origin), expected, "Owner should have 10000 Exchange initially");
  }

  function testInitialBalanceWithNewExchange() {
    Exchange meta = new Exchange();

    uint expected = 10000;

    Assert.equal(meta.getBalance(tx.origin), expected, "Owner should have 10000 Exchange initially");
  }*/

}
