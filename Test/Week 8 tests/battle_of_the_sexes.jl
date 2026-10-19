using Test
using GameTheory


@testset "Correlated Equilibrium — Battle of the Sexes (Example 8.1)" begin
    # 1. Define the strategy space
    strategies = Dict(
        1 => ["F", "C"],
        2 => ["F", "C"]
    )

    # 2. Instantiate the game
    game = StrategicFormGame(2, strategies)

    # 3. Populate the payoff matrices (Figure 8.1)
    #          F     C
    #   F   (2,1)  (0,0)
    #   C   (0,0)  (1,2)
    game.payoffs_to_p1 .= [
        2.0  0.0;
        0.0  1.0
    ]

    game.payoffs_to_p2 .= [
        1.0  0.0;
        0.0  2.0
    ]

    @testset "Fair Coin-Toss Mechanism — ½(F,F) + ½(C,C) is a CE" begin
        println("\n--- Battle of the Sexes: Verifying the fair coin-toss mechanism ---")
        
        # The public lottery: play (F,F) with prob 1/2 and (C,C) with prob 1/2
        p = [0.5  0.0;
             0.0  0.5]

        # Test 1: This distribution must pass all obedience constraints
        @test is_correlated_equilibrium(game, p)

        # Test 2: The expected payoff must be (1.5, 1.5)
        payoffs = expected_correlated_payoff(game, p)
        @test isapprox(payoffs[1], 1.5, atol=1e-4)
        @test isapprox(payoffs[2], 1.5, atol=1e-4)
    end

    @testset "Nash Equilibria → Correlated Equilibria (Theorem 8.7)" begin
        println("\n--- Battle of the Sexes: Verifying Nash → Correlated ---")
        
        # Pure NE 1: (F, F) with payoff (2, 1)
        σ_ne1 = MixedStrategyProfile(
            Dict("F" => 1.0, "C" => 0.0),
            Dict("F" => 1.0, "C" => 0.0)
        )
        p_ne1 = nash_to_correlated(game, σ_ne1)
        @test is_correlated_equilibrium(game, p_ne1)
        payoffs_ne1 = expected_correlated_payoff(game, p_ne1)
        @test isapprox(payoffs_ne1[1], 2.0, atol=1e-4)
        @test isapprox(payoffs_ne1[2], 1.0, atol=1e-4)

        # Pure NE 2: (C, C) with payoff (1, 2)
        σ_ne2 = MixedStrategyProfile(
            Dict("F" => 0.0, "C" => 1.0),
            Dict("F" => 0.0, "C" => 1.0)
        )
        p_ne2 = nash_to_correlated(game, σ_ne2)
        @test is_correlated_equilibrium(game, p_ne2)
        payoffs_ne2 = expected_correlated_payoff(game, p_ne2)
        @test isapprox(payoffs_ne2[1], 1.0, atol=1e-4)
        @test isapprox(payoffs_ne2[2], 2.0, atol=1e-4)

        # Mixed NE: ([2/3 F, 1/3 C], [1/3 F, 2/3 C]) with payoff (2/3, 2/3)
        σ_ne3 = MixedStrategyProfile(
            Dict("F" => 2/3, "C" => 1/3),
            Dict("F" => 1/3, "C" => 2/3)
        )
        p_ne3 = nash_to_correlated(game, σ_ne3)
        @test is_correlated_equilibrium(game, p_ne3)
        payoffs_ne3 = expected_correlated_payoff(game, p_ne3)
        @test isapprox(payoffs_ne3[1], 2/3, atol=1e-4)
        @test isapprox(payoffs_ne3[2], 2/3, atol=1e-4)
    end

    @testset "Non-CE Detection — Anti-coordination is NOT a CE" begin
        println("\n--- Battle of the Sexes: Verifying that a bad distribution is rejected ---")
        
        # An anti-coordination distribution: ½(F,C) + ½(C,F) — both miscoordinate
        p_bad = [0.0  0.5;
                 0.5  0.0]

        # Test: This distribution should FAIL the obedience constraints
        # If Player 1 is recommended F, they know Player 2 plays C → payoff 0.
        # Deviating to C gives payoff 1, a profitable deviation.
        @test !is_correlated_equilibrium(game, p_bad)
    end
end
