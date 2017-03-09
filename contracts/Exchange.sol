pragma solidity ^0.4.8;

import "tokens/Token.sol"; // Use audited ERC20 interface
import "./Arithmetic.sol";

/// @title Currency exchange backed by holdings
contract Exchange {
    // Duration of price ramp
    uint constant priceRampDuration = 24 * 60 * 60;
    // Duration of price lock (See: http://ethereum.stackexchange.com/a/6796)
    uint constant priceLockDuration = 15 * 60;

    // A mapping from exchange identifiers to their corresponding Exchange struct instances
    mapping (bytes32 => Exchange) exchanges;

    // Exchange structure
    struct Exchange {
        address[2] tokens; // token pair in exchange
        uint[2] supplies;  // amount held by exchange of each token type
        uint[2] lastPricePoint;
        uint lastUpdateTimestamp;
    }

    // Exchange creation event
    event LogAddExchange(
        bytes32 exchangeIdentifier,
        address[2] tokens,
        uint[2] supplies
    );

    // Exchange funding event
    event LogFundExchange(
        bytes32 exchangeIdentifier,
        uint8 tokenIndex,
        uint amount,
        address suppliedTokenAddress,
        uint newSupply
    );

    // Exchange transaction event
    event LogExchangeTransaction(
        bytes32 exchangeIdentifier,
        uint8 purchasedTokenIndex,
        uint amountPurchased,
        address purchasedTokenAddress,
        uint[2] newSupplies
    );

    /// @param exchangeIdentifier The ID of the exchange
    /// @return tokens The addresses of the tokens handled by the requested exchange
    /// @return supplies How much of each of the currencies the exchange holds for providing liquidity
    function getExchange(bytes32 exchangeIdentifier)
        constant
        returns (address[2] tokens, uint[2] supplies)
    {
        Exchange ex = exchanges[exchangeIdentifier];
        tokens = ex.tokens;
        supplies = ex.supplies;
    }

    /// @param exchangeIdentifier The ID of the exchange
    /// @return A pair that indicates price
    function getPricePoint(bytes32 exchangeIdentifier)
        constant
        returns (uint[2])
    {
        Exchange ex = exchanges[exchangeIdentifier];
        uint param = 0;
        if(now > ex.lastUpdateTimestamp + priceLockDuration)
            param = now - ex.lastUpdateTimestamp - priceLockDuration;
            if(param > priceRampDuration)
                param = priceRampDuration;

        return [
            Arithmetic.overflowResistantFraction((ex.supplies[0] - ex.lastPricePoint[0]), param, priceRampDuration) + ex.lastPricePoint[0],
            Arithmetic.overflowResistantFraction((ex.supplies[1] - ex.lastPricePoint[1]), param, priceRampDuration) + ex.lastPricePoint[1]
        ];
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
            supplies: supplies,
            lastPricePoint: supplies,
            lastUpdateTimestamp: now
        });
        LogAddExchange(exchangeIdentifier, tokens, supplies);
    }

    /// @notice Send `amount` of token `tokens[tokenIndex]` to this contract to fund exchange
    /// @param exchangeIdentifier The ID of the exchange
    /// @param tokenIndex `0` or `1` to refer to either first or second entry in the token pair associated with exchange as determined by `getExchange`
    /// @param amount Amount of currency to send to this contract
    function addFunding(bytes32 exchangeIdentifier, uint8 tokenIndex, uint amount)
        public
    {
        Exchange ex = exchanges[exchangeIdentifier];
        address suppliedTokenAddress = ex.tokens[tokenIndex];
        if (!Token(suppliedTokenAddress).transferFrom(msg.sender, this, amount))
            throw;
        ex.lastPricePoint = getPricePoint(exchangeIdentifier);
        ex.lastUpdateTimestamp = now;
        ex.supplies[tokenIndex] += amount;
        LogFundExchange(exchangeIdentifier, tokenIndex, amount, suppliedTokenAddress, ex.supplies[tokenIndex]);
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

        ex.lastPricePoint = getPricePoint(exchangeIdentifier);
        ex.lastUpdateTimestamp = now;
        ex.supplies[paymentTokenIndex] += costs;
        ex.supplies[tokenIndex] -= amount;
        LogExchangeTransaction(exchangeIdentifier, tokenIndex, amount, ex.tokens[tokenIndex], ex.supplies);
    }

    /// @dev Will price `tokens[tokenIndex]` to keep `supplies[0] * supplies[1]` the same after sending `amount` of `tokens[tokenIndex]` to `msg.sender` and receiving the calculated price of `tokens[1-tokenIndex]` from `msg.sender`
    /// @param exchangeIdentifier The ID of the exchange
    /// @param tokenIndex Index of the token to be bought from the exchange
    /// @param amount Amount of `tokens[tokenIndex]` to buy from exchange
    /// @return Price of `amount` of `tokens[tokenIndex]` in `tokens[1-tokenIndex]`
    function calcCosts(bytes32 exchangeIdentifier, uint8 tokenIndex, uint amount)
        public constant
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

    /// @param tokens Token pair to get exchange ID for
    /// @return The exchange ID
    function calcExchangeIdentifier(address[2] tokens)
        public constant
        returns (bytes32)
    {
        return keccak256(tokens[0]) ^ keccak256(tokens[1]);
    }
}
