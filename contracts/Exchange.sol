pragma solidity ^0.4.8;


import "tokens/Token.sol";


contract Exchange {

    mapping (bytes32 => Exchange) exchanges;

    struct Exchange {
        address[2] tokens;
        uint[2] supplies;
    }

    function getExchanges(bytes32 exchangeIdentifier)
        returns (address[2] tokens, uint[2] supplies)
    {
        Exchange ex = exchanges[exchangeIdentifier];
        tokens = ex.tokens;
        supplies = ex.supplies;
    }

    function addExchange(address[2] tokens, uint[2] supplies)
        public
        returns (bytes32 exchangeIdentifier)
    {
        exchangeIdentifier = calcExchangeIdentifier(tokens);
        if (exchanges[exchangeIdentifier].tokens.length > 0)
            throw;
        if (   !Token(tokens[0]).transferFrom(msg.sender, this, supplies[0])
            || !Token(tokens[1]).transferFrom(msg.sender, this, supplies[1]))
            throw;
        exchanges[exchangeIdentifier] = Exchange({
            tokens: tokens,
            supplies: supplies
        });
    }

    function addFunding(bytes32 exchangeIdentifier, uint8 tokenIndex, uint amount)
        public
    {
        Exchange ex = exchanges[exchangeIdentifier];
        if (!Token(ex.tokens[tokenIndex]).transferFrom(msg.sender, this, amount))
            throw;
        ex.supplies[tokenIndex] += amount;
    }


    function buyTokens(bytes32 exchangeIdentifier, uint8 tokenIndex, uint amount)
        public
    {
        uint costs = calcCosts(exchangeIdentifier, tokenIndex, amount);
        Exchange ex = exchanges[exchangeIdentifier];
        uint8 paymentTokenIndex = 1 - tokenIndex;
        if (!Token(ex.tokens[paymentTokenIndex]).transferFrom(msg.sender, this, amount))
            throw;
        if (!Token(ex.tokens[tokenIndex]).transfer(msg.sender, amount))
            throw;
        ex.supplies[paymentTokenIndex] += costs;
        ex.supplies[tokenIndex] -= amount;
    }

    function calcCosts(bytes32 exchangeIdentifier, uint8 tokenIndex, uint amount)
        public
        returns (uint)
    {
        Exchange ex = exchanges[exchangeIdentifier];
        uint invariant = ex.supplies[0] * ex.supplies[1];
        if (ex.supplies[tokenIndex] <= amount)
            throw;
        uint minuend = invariant / (ex.supplies[tokenIndex] - amount);
        uint8 paymentTokenIndex = 1 - tokenIndex;
        uint subtrahend = ex.supplies[paymentTokenIndex];
        if (subtrahend >= minuend)
            throw;
        return minuend - subtrahend;
    }

    function calcExchangeIdentifier(address[2] tokens)
        public
        constant
        returns (bytes32)
    {
        return bytes32(tokens[0]) ^ bytes32(tokens[1]);
    }
}
