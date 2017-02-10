pragma solidity ^0.4.2;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "tokens/StandardToken.sol";
import "../contracts/Exchange.sol";

contract TestExchange {
    using Assert for *;

    function testExchangePairIdentifiersSymmetric() {
        address toka = address(new StandardToken());
        address tokb = address(new StandardToken());
        Exchange exchange = Exchange(DeployedAddresses.Exchange());
        exchange.calcExchangeIdentifier([toka, tokb])
            .equal(exchange.calcExchangeIdentifier([tokb, toka]),
            "Exchange ID not symmetric on tokens");
    }

}
