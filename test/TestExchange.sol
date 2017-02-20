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

    function mul256By256(uint a, uint b)
        constant
        returns (uint ab32, uint ab1, uint ab0)
    {
        uint ahi = a >> 128;
        uint alo = a & 2**128-1;
        uint bhi = b >> 128;
        uint blo = b & 2**128-1;
        ab0 = alo * blo;
        ab1 = ahi * blo + alo * bhi;
        ab32 = ahi * bhi + (ab1 >> 128);
        ab1 = (ab1 & 2**128-1) + (ab0 >> 128);
        ab0 &= 2**128-1;
    }

    // I adapted this from Fast Division of Large Integers by Karl Hasselström
    // Algorithm 3.4: Divide-and-conquer division (3 by 2)
    // Karl got it from Burnikel and Ziegler and the GMP lib implementation
    function div256_128By128_128(uint a21, uint a0, uint b, uint b1, uint b0)
        constant
        returns (uint q, uint r)
    {
        if(a21 >> 128 < b1) {
            q = a21 / b1;
            r = a21 % b1;
        } else {
            q = 2**128-1;
            r = a21 - (b1 << 128) + b1;
        }

        uint rsub = q * b0;

        if(r >= 2**128) {
            r = (r << 128) + a0 - rsub;
        } else {
            r = (r << 128) + a0;
            if(rsub > r) {
                q--;
                rsub -= b;
            }
            if(rsub > r) {
                q--;
                rsub -= b;
            }
            r -= rsub;
        }
    }

    function overflowResistantFraction(uint a, uint b, uint divisor)
        returns (uint)
    {
        uint ab32_q1; uint ab1_r1; uint ab0;
        if(b <= 1 || b != 0 && a * b / b == a) {
            return a * b / divisor;
        } else {
            (ab32_q1, ab1_r1, ab0) = mul256By256(a, b);
            (a, b) = (divisor >> 128, divisor & 2**128-1);
            (ab32_q1, ab1_r1) = div256_128By128_128(ab32_q1, ab1_r1, divisor, a, b);
            (a, b) = div256_128By128_128(ab1_r1, ab0, divisor, a, b);
            return (ab32_q1 << 128) + a;
        }
    }

    function testOverflowResistantFraction() {
        // a * b / d = c
        uint a = 12378518568247617448219742381863718946738219467382195463143843218532531534784*8;
        uint b = 12378518568247617448219742381863718946738219467382195463143843218532531534784*7;
        uint c = 12378518568247617448219742381863718946738219467382195463143843218532531534784*8;
        uint d = 12378518568247617448219742381863718946738219467382195463143843218532531534784*7;

        (c).equal(overflowResistantFraction(a, b, d), "lolwut");
    }

}
