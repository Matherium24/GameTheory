using Test
using GameTheory


@testset "Correlated Equilibrium — Asymmetric Coordination (Example 8.11)" begin
    # 1. Define the strategy space
    strategies = Dict(
        1 => ["T", "B"],
        2 => ["L", "R"]
    )

    # 2. Instantiate the game
    game = StrategicFormGame(2, strategies)

    # 3. Populate the payoff matrices (Figure 8.12)
    #          L     R
    #   T   (1,2)  (0,0)
    #   B   (0,0)  (2,3)
    game.payoffs_to_p1 .= [
        1.0  0.0;
        0.0  2.0
    ]

    game.payoffs_to_p2 .= [
        2.0  0.0;
        0.0  3.0
    ]

    @testset "All Five Extreme Points of the CE Polytope (Eqs. 8.30–8.34)" begin
        println("\n--- Asymmetric Coordination: Verifying all 5 extreme points ---")
        
        # Extreme Point 1: (α, β, γ, δ) = (0, 0, 0, 1) → pure NE (B, R)
        p1 = [0.0  0.0;
              0.0  1.0]
        @test is_correlated_equilibrium(game, p1)
        payoffs_1 = expected_correlated_payoff(game, p1)
        @test isapprox(payoffs_1[1], 2.0, atol=1e-4)
        @test isapprox(payoffs_1[2], 3.0, atol=1e-4)

        # Extreme Point 2: (α, β, γ, δ) = (1, 0, 0, 0) → pure NE (T, L)
        p2 = [1.0  0.0;
              0.0  0.0]
        @test is_correlated_equilibrium(game, p2)
        payoffs_2 = expected_correlated_payoff(game, p2)
        @test isapprox(payoffs_2[1], 1.0, atol=1e-4)
        @test isapprox(payoffs_2[2], 2.0, atol=1e-4)

        # Extreme Point 3: (α, β, γ, δ) = (6/11, 3/11, 0, 2/11)
        # This is a non-Nash extreme point of the CE polytope
        p3 = [6/11  3/11;
              0.0   2/11]
        @test is_correlated_equilibrium(game, p3)

        # Extreme Point 4: (α, β, γ, δ) = (1/2, 0, 1/3, 1/6)
        # Another non-Nash extreme point
        p4 = [1/2  0.0;
              1/3  1/6]
        @test is_correlated_equilibrium(game, p4)

        # Extreme Point 5: (α, β, γ, δ) = (2/5, 1/5, 4/15, 2/15)
        # This corresponds to the mixed Nash equilibrium ([3/5 T, 2/5 B], [2/3 L, 1/3 R])
        p5 = [2/5   1/5;
              4/15  2/15]
        @test is_correlated_equilibrium(game, p5)
        payoffs_5 = expected_correlated_payoff(game, p5)
        # U₁ = (2/5)(1) + (1/5)(0) + (4/15)(0) + (2/15)(2) = 2/3
        @test isapprox(payoffs_5[1], 2/3, atol=1e-4)
    end

    @testset "Non-Nash Extreme Points Cannot Factor into Independent Strategies" begin
        println("\n--- Asymmetric Coordination: Checking non-factorability ---")
        
        # Extreme Point 3: p = (6/11, 3/11, 0, 2/11)
        # If this were a product distribution, we'd need p(T,L)*p(B,R) = p(T,R)*p(B,L)
        # i.e., (6/11)(2/11) = (3/11)(0) → 12/121 ≠ 0
        α₃, β₃, γ₃, δ₃ = 6/11, 3/11, 0.0, 2/11
        @test !isapprox(α₃ * δ₃, β₃ * γ₃, atol=1e-8)

        # Extreme Point 4: p = (1/2, 0, 1/3, 1/6)
        # (1/2)(1/6) = (0)(1/3) → 1/12 ≠ 0
        α₄, β₄, γ₄, δ₄ = 1/2, 0.0, 1/3, 1/6
        @test !isapprox(α₄ * δ₄, β₄ * γ₄, atol=1e-8)
    end

    @testset "Mixed Nash Equilibrium via nash_to_correlated (Theorem 8.7)" begin
        println("\n--- Asymmetric Coordination: Mixed NE → CE ---")
        
        # The mixed NE: ([3/5 T, 2/5 B], [2/3 L, 1/3 R])
        σ_mixed = MixedStrategyProfile(
            Dict("T" => 3/5, "B" => 2/5),
            Dict("L" => 2/3, "R" => 1/3)
        )
        p_mixed = nash_to_correlated(game, σ_mixed)
        @test is_correlated_equilibrium(game, p_mixed)

        # Verify the induced product distribution matches Extreme Point 5
        @test isapprox(p_mixed[1, 1], 2/5, atol=1e-6)   # α = (3/5)(2/3) = 2/5
        @test isapprox(p_mixed[1, 2], 1/5, atol=1e-6)   # β = (3/5)(1/3) = 1/5
        @test isapprox(p_mixed[2, 1], 4/15, atol=1e-6)   # γ = (2/5)(2/3) = 4/15
        @test isapprox(p_mixed[2, 2], 2/15, atol=1e-6)   # δ = (2/5)(1/3) = 2/15
    end

    @testset "LP Solver — Various Objectives" begin
        println("\n--- Asymmetric Coordination: Running LP solver ---")
        
        # Social welfare maximisation should find (B, R) → payoff (2, 3), welfare = 5
        p_sw, payoffs_sw = compute_correlated_equilibrium(game; objective=:social_welfare)
        @test is_correlated_equilibrium(game, p_sw)
        @test isapprox(payoffs_sw[1] + payoffs_sw[2], 5.0, atol=1e-4)

        # Egalitarian objective
        p_eg, payoffs_eg = compute_correlated_equilibrium(game; objective=:egalitarian)
        @test is_correlated_equilibrium(game, p_eg)
    end
end
