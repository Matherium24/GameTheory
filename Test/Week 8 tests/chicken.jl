using Test
using GameTheory


@testset "Correlated Equilibrium — Game of Chicken (Example 8.3)" begin
    # 1. Define the strategy space
    # T/B for Player 1 (swerve / stay), L/R for Player 2 (swerve / stay)
    strategies = Dict(
        1 => ["T", "B"],
        2 => ["L", "R"]
    )

    # 2. Instantiate the game
    game = StrategicFormGame(2, strategies)

    # 3. Populate the payoff matrices (Figure 8.3)
    #          L     R
    #   T   (6,6)  (2,7)
    #   B   (7,2)  (0,0)
    game.payoffs_to_p1 .= [
        6.0  2.0;
        7.0  0.0
    ]

    game.payoffs_to_p2 .= [
        6.0  7.0;
        2.0  0.0
    ]

    @testset "Observer Mechanism — p(TL)=p(TR)=p(BL)=1/3 is a CE" begin
        println("\n--- Chicken: Verifying the observer's distribution from Example 8.3 ---")
        
        # The observer selects among (T,L), (T,R), (B,L) with equal probability 1/3
        p = [1/3  1/3;
             1/3  0.0]

        # Test 1: This distribution must pass all obedience constraints
        @test is_correlated_equilibrium(game, p)

        # Test 2: The expected payoff must be (5, 5), strictly outside the convex hull of NE payoffs
        payoffs = expected_correlated_payoff(game, p)
        @test isapprox(payoffs[1], 5.0, atol=1e-4)
        @test isapprox(payoffs[2], 5.0, atol=1e-4)

        # Test 3: Total welfare = 10, strictly beats the Nash maximum of 9⅓
        @test payoffs[1] + payoffs[2] > 9.34
    end

    @testset "LP Solver — Social Welfare Maximisation beats Nash" begin
        println("\n--- Chicken: Running LP solver with social welfare objective ---")
        
        p_opt, payoffs_opt = compute_correlated_equilibrium(game; objective=:social_welfare)

        # Test 4: The LP's welfare must be at least as good as the textbook's (5, 5) = 10
        @test payoffs_opt[1] + payoffs_opt[2] >= 10.0 - 1e-4

        # Test 5: The welfare strictly beats the Nash maximum of 9⅓
        @test payoffs_opt[1] + payoffs_opt[2] > 9.34

        # Test 6: The optimal distribution must assign zero probability to (B, R)
        @test isapprox(p_opt[2, 2], 0.0, atol=1e-6)

        # Test 7: The resulting distribution itself must be a valid CE
        @test is_correlated_equilibrium(game, p_opt)
    end

    @testset "Nash Equilibria are Correlated Equilibria (Theorem 8.7)" begin
        println("\n--- Chicken: Verifying Nash → Correlated (Theorem 8.7) ---")
        
        # Pure NE 1: (T, R) with payoff (2, 7)
        σ_ne1 = MixedStrategyProfile(
            Dict("T" => 1.0, "B" => 0.0),
            Dict("L" => 0.0, "R" => 1.0)
        )
        p_ne1 = nash_to_correlated(game, σ_ne1)
        @test is_correlated_equilibrium(game, p_ne1)

        # Pure NE 2: (B, L) with payoff (7, 2)
        σ_ne2 = MixedStrategyProfile(
            Dict("T" => 0.0, "B" => 1.0),
            Dict("L" => 1.0, "R" => 0.0)
        )
        p_ne2 = nash_to_correlated(game, σ_ne2)
        @test is_correlated_equilibrium(game, p_ne2)

        # Mixed NE: ([2/3 T, 1/3 B], [2/3 L, 1/3 R]) with payoff (4⅔, 4⅔)
        σ_ne3 = MixedStrategyProfile(
            Dict("T" => 2/3, "B" => 1/3),
            Dict("L" => 2/3, "R" => 1/3)
        )
        p_ne3 = nash_to_correlated(game, σ_ne3)
        @test is_correlated_equilibrium(game, p_ne3)

        # Verify the mixed NE payoff
        payoffs_ne3 = expected_correlated_payoff(game, p_ne3)
        @test isapprox(payoffs_ne3[1], 14/3, atol=1e-4)
        @test isapprox(payoffs_ne3[2], 14/3, atol=1e-4)
    end
end
