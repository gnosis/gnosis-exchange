pragma solidity ^0.4.8;

// Use audited ERC20 interface
import "tokens/Token.sol";

/// @title Currency exchange backed by holdings with price analysis functions
contract Exchange {
    // A mapping from exchange identifiers to their corresponding Exchange struct instances
    mapping (bytes32 => Exchange) exchanges;

    // Exchange structure
    struct Exchange {
        address[2] tokens; // token pair in exchange
        uint[2] supplies;  // amount held by exchange of each token type
    }

    /// @param exchangeIdentifier The ID of the exchange
    /// @return tokens The addresses of the tokens handled by the requested exchange
    /// @return supplies How much of each of the currencies the exchange holds for providing liquidity
    function getExchange(bytes32 exchangeIdentifier)
        returns (address[2] tokens, uint[2] supplies)
    {
        Exchange ex = exchanges[exchangeIdentifier];
        tokens = ex.tokens;
        supplies = ex.supplies;
    }

    /// @notice Send amount `supplies[i]` of token `tokens[i]` to this contract to create exchange for token pair
    /// @param tokens The token pair to be handled by the exchange
    /// @param supplies Amount of each currency to fund exchange with
    /// @return exchangeIdentifier The identifier for newly created exchange.
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

    /// @notice Send `amount` of token `tokens[tokenIndex]` to this contract to fund exchange
    /// @param exchangeIdentifier The ID of the exchange
    /// @param tokenIndex `0` or `1` to refer to either first or second entry in the token pair associated with exchange as determined by `getExchange`
    /// @param amount Amount of currency to send to this contract
    function addFunding(bytes32 exchangeIdentifier, uint8 tokenIndex, uint amount)
        public
    {
        Exchange ex = exchanges[exchangeIdentifier];
        if (!Token(ex.tokens[tokenIndex]).transferFrom(msg.sender, this, amount))
            throw;
        ex.supplies[tokenIndex] += amount;
    }

    /// @notice Send `calcCosts(exchangeIdentifier, tokenIndex, amount)` of `tokens[1-tokenIndex]` to buy `amount` of `tokens[tokenIndex]` from exchange.
    /// @param exchangeIdentifier The ID of the exchange
    /// @param tokenIndex Index of the token to be bought from the exchange
    /// @param amount Amount of `tokens[tokenIndex]` to buy from exchange
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

    /// @dev Will price `tokens[tokenIndex]` to keep `supplies[0] * supplies[1]` the same after sending `amount` of `tokens[tokenIndex]` to `msg.sender` and receiving the calculated price of `tokens[1-tokenIndex]` from `msg.sender`
    /// @param exchangeIdentifier The ID of the exchange
    /// @param tokenIndex Index of the token to be bought from the exchange
    /// @param amount Amount of `tokens[tokenIndex]` to buy from exchange
    /// @return Price of `amount` of `tokens[tokenIndex]` in `tokens[1-tokenIndex]`
    function calcCosts(bytes32 exchangeIdentifier, uint8 tokenIndex, uint amount)
        public
        returns (uint)
    {
        Exchange ex = exchanges[exchangeIdentifier];
        if (ex.supplies[tokenIndex] <= amount)
            throw;
        uint invariant = ex.supplies[0] * ex.supplies[1];
        uint minuend = invariant / (ex.supplies[tokenIndex] - amount);
        uint8 paymentTokenIndex = 1 - tokenIndex;
        uint subtrahend = ex.supplies[paymentTokenIndex];
        if (subtrahend >= minuend)
            throw;
        return minuend - subtrahend;
    }

    /// @param Token pair to get exchange ID for
    /// @return The exchange ID
    function calcExchangeIdentifier(address[2] tokens)
        public
        constant
        returns (bytes32)
    {
        return bytes32(tokens[0]) ^ bytes32(tokens[1]);
    }
}
