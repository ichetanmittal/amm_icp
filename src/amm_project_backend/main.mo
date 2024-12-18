import Debug "mo:base/Debug";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Float "mo:base/Float";

actor AMM {
    // Types
    public type TokenType = {
        #TokenA;
        #TokenB;
    };

    // State variables
    private stable var tokenAReserve : Nat = 0;
    private stable var tokenBReserve : Nat = 0;
    private stable var totalLPTokens : Nat = 0;

    // Constants
    private let MINIMUM_LIQUIDITY : Nat = 1000; // Minimum liquidity to prevent division by zero
    private let FEE_PERCENT : Nat = 3; // 0.3% fee
    private let FEE_DENOMINATOR : Nat = 1000;

    // Helper functions
    private func calculateLPTokens(amountA : Nat, amountB : Nat) : Nat {
        if (totalLPTokens == 0) {
            // Initial liquidity provision
            // For simplicity, use geometric mean approximation
            Nat.max((amountA * amountB) / 1_000_000, MINIMUM_LIQUIDITY);
        } else {
            // Subsequent liquidity provisions
            let lpTokensA = (amountA * totalLPTokens) / tokenAReserve;
            let lpTokensB = (amountB * totalLPTokens) / tokenBReserve;
            Nat.min(lpTokensA, lpTokensB);
        };
    };

    // Main functions
    public func addLiquidity(tokenA : Nat, tokenB : Nat) : async Bool {
        // Input validation
        if (tokenA == 0 or tokenB == 0) {
            Debug.print("Error: Cannot add zero liquidity");
            return false;
        };

        // For first liquidity provision
        if (tokenAReserve == 0 and tokenBReserve == 0) {
            tokenAReserve := tokenA;
            tokenBReserve := tokenB;
            totalLPTokens := calculateLPTokens(tokenA, tokenB);
            return true;
        };

        // Check if deposit maintains the price ratio
        let expectedTokenB = (tokenA * tokenBReserve) / tokenAReserve;
        if (tokenB != expectedTokenB) {
            Debug.print("Error: Unbalanced liquidity provision");
            return false;
        };

        // Update reserves and mint LP tokens
        let lpTokensToMint = calculateLPTokens(tokenA, tokenB);
        tokenAReserve += tokenA;
        tokenBReserve += tokenB;
        totalLPTokens += lpTokensToMint;

        true;
    };

    public func removeLiquidity(lpTokens : Nat) : async ?(Nat, Nat) {
        // Input validation
        if (lpTokens == 0 or lpTokens > totalLPTokens) {
            Debug.print("Error: Invalid LP tokens amount");
            return null;
        };

        // Calculate token amounts to return
        let tokenAAmount = (lpTokens * tokenAReserve) / totalLPTokens;
        let tokenBAmount = (lpTokens * tokenBReserve) / totalLPTokens;

        // Update state
        tokenAReserve -= tokenAAmount;
        tokenBReserve -= tokenBAmount;
        totalLPTokens -= lpTokens;

        ?(tokenAAmount, tokenBAmount);
    };

    public func swap(tokenIn : TokenType, amountIn : Nat) : async ?Nat {
        // Input validation
        if (amountIn == 0) {
            Debug.print("Error: Cannot swap zero amount");
            return null;
        };

        // Calculate amounts based on constant product formula (x * y = k)
        let (reserveIn, reserveOut) = switch(tokenIn) {
            case (#TokenA) { (tokenAReserve, tokenBReserve) };
            case (#TokenB) { (tokenBReserve, tokenAReserve) };
        };

        // Calculate amount out with fee
        let amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_PERCENT);
        let numerator = amountInWithFee * reserveOut;
        let denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;
        let amountOut = numerator / denominator;

        // Update reserves
        switch(tokenIn) {
            case (#TokenA) {
                tokenAReserve += amountIn;
                tokenBReserve -= amountOut;
            };
            case (#TokenB) {
                tokenBReserve += amountIn;
                tokenAReserve -= amountOut;
            };
        };

        ?amountOut;
    };

    public query func getPoolState() : async (Nat, Nat, Nat) {
        (tokenAReserve, tokenBReserve, totalLPTokens);
    };
}
