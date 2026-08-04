using Test
using GameTheory

@testset "Mixed Strategies - Example 5.14 Zero-Sum LP" begin
    # I am testing the zero-sum LP solver on Example 5.14 from Ch 5
    
    strategies = Dict(1 => ["T", "B"], 2 => ["L", "R"])
    
    game = StrategicFormGame(2, strategies)
    
    # Player 1's payoffs
    game.payoffs_to_p1 .= [
        5.0  0.0;
        3.0  4.0
    ]
    
    # Player 2's payoffs (Zero-sum: exactly opposite to Player 1)
    game.payoffs_to_p2 .= [
       -5.0   0.0;
       -3.0  -4.0
    ]
    
    @testset "LP Solver Mixed Strategy Outputs" begin
        # Execute the LP solver on the game
        equilibrium_profile = solve_zero_sum_lp(game)
        
        # Test 1: Did it compute the correct mixed strategy for Player 1?
        # x = 1/6 for T, 5/6 for B
        @test isapprox(equilibrium_profile.σ₁["T"], 1/6, atol=1e-4)
        @test isapprox(equilibrium_profile.σ₁["B"], 5/6, atol=1e-4)
        
        # Test 2: Did it compute the correct mixed strategy for Player 2?
        # y = 2/3 for L, 1/3 for R
        @test isapprox(equilibrium_profile.σ₂["L"], 2/3, atol=1e-4)
        @test isapprox(equilibrium_profile.σ₂["R"], 1/3, atol=1e-4)
        
        # Test 3: Verify the exact expected payoff values (Value of the Game)
        # The expected payoff Z_P should be exactly 10/3 (or 3.3333...)
        u1, u2 = compute_expected_payoffs(game, equilibrium_profile)
        
        @test isapprox(u1, 10/3, atol=1e-4)
        @test isapprox(u2, -10/3, atol=1e-4)
    end
end
