pragma solidity ^0.4.2;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "tokens/StandardToken.sol";
import "../contracts/Exchange.sol";
import "../contracts/Arithmetic.sol";

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

    function testOverflowResistantFraction() {
        // a * b / d = c
        uint a = 12378518568247617448219742381863718946738219467382195463143843218532531534784*8;
        uint b = 12378518568247617448219742381863718946738219467382195463143843218532531534784*7;
        uint c = 12378518568247617448219742381863718946738219467382195463143843218532531534784*8;
        uint d = 12378518568247617448219742381863718946738219467382195463143843218532531534784*7;

        (12378518568247617448219742381863718946738219467382195463143843218532531534784*8*12378518568247617448219742381863718946738219467382195463143843218532531534784*7/(12378518568247617448219742381863718946738219467382195463143843218532531534784*7)).equal(Arithmetic.overflowResistantFraction(a, b, d), "lolwut");
    }

}
